from __future__ import annotations

import asyncio
import base64
import io
import json
import shlex
from contextlib import asynccontextmanager
from pathlib import Path

import qrcode
from fastapi import Depends, FastAPI, Form, HTTPException, Request
from fastapi.responses import HTMLResponse, RedirectResponse, StreamingResponse
from fastapi.staticfiles import StaticFiles
from fastapi.templating import Jinja2Templates

from . import audit, auth, notify, status
from .commands import COMMANDS, REPO_ROOT

SESSION_COOKIE = "platformctl_session"

_here = Path(__file__).parent
templates = Jinja2Templates(directory=str(_here / "templates"))


def _client_key(request: Request) -> str:
    return request.client.host if request.client else "unknown"


async def require_session(request: Request) -> auth.Session:
    token = request.cookies.get(SESSION_COOKIE)
    session = auth.verify_session_token(token)
    if session is None:
        raise HTTPException(status_code=303, headers={"Location": "/login"})
    return session


@asynccontextmanager
async def _lifespan(app: FastAPI):
    bus = notify.NotificationBus()
    app.state.notification_bus = bus
    task = asyncio.create_task(notify.poller_loop(bus))
    try:
        yield
    finally:
        task.cancel()


def create_app() -> FastAPI:
    app = FastAPI(title="platformctl control plane", docs_url=None, redoc_url=None, lifespan=_lifespan)
    app.mount("/static", StaticFiles(directory=str(_here / "static")), name="static")

    @app.get("/", response_class=HTMLResponse)
    async def index(request: Request, session: auth.Session = Depends(require_session)):
        return templates.TemplateResponse(
            request,
            "index.html",
            {"username": session.username, "commands": COMMANDS},
        )

    @app.get("/panels/services", response_class=HTMLResponse)
    async def panel_services(request: Request, _: auth.Session = Depends(require_session)):
        return templates.TemplateResponse(
            request, "_panel_services.html", {"items": status.dev_services_status()}
        )

    @app.get("/panels/ai-runtime", response_class=HTMLResponse)
    async def panel_ai_runtime(request: Request, _: auth.Session = Depends(require_session)):
        return templates.TemplateResponse(
            request, "_panel_ai_runtime.html", {"items": status.ai_runtime_status()}
        )

    @app.get("/panels/labs", response_class=HTMLResponse)
    async def panel_labs(request: Request, _: auth.Session = Depends(require_session)):
        return templates.TemplateResponse(
            request, "_panel_labs.html", {"items": status.labs_status()}
        )

    @app.get("/panels/projects", response_class=HTMLResponse)
    async def panel_projects(request: Request, _: auth.Session = Depends(require_session)):
        return templates.TemplateResponse(
            request, "_panel_projects.html", {"items": status.governed_projects_status()}
        )

    @app.get("/panels/jobs", response_class=HTMLResponse)
    async def panel_jobs(request: Request, _: auth.Session = Depends(require_session)):
        return templates.TemplateResponse(
            request, "_panel_jobs.html", {"items": status.background_jobs_status()}
        )

    @app.get("/panels/resources", response_class=HTMLResponse)
    async def panel_resources(request: Request, _: auth.Session = Depends(require_session)):
        return templates.TemplateResponse(
            request, "_panel_resources.html", {"data": status.resource_utilization()}
        )

    @app.get("/run-trigger/{command_id}", response_class=HTMLResponse)
    async def run_trigger(command_id: str, _: auth.Session = Depends(require_session)):
        if command_id not in COMMANDS:
            raise HTTPException(status_code=404, detail="Unknown command")
        return (
            f'<div hx-ext="sse" sse-connect="/run/{command_id}" sse-swap="message" '
            f'hx-target="#cmd-output" hx-swap="beforeend"'
            f'    hx-on::load="document.getElementById(\'cmd-output\').textContent = \'\'"></div>'
        )

    @app.get("/run/{command_id}")
    async def run_command(command_id: str, session: auth.Session = Depends(require_session)):
        entry = COMMANDS.get(command_id)

        async def stream():
            if entry is None:
                yield "data: unknown command\n\n"
                yield "event: done\ndata: 1\n\n"
                return

            argv, label = entry
            yield f"data: $ {shlex.join(argv)}\n\n"
            proc = await asyncio.create_subprocess_exec(
                *argv,
                cwd=str(REPO_ROOT),
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.STDOUT,
            )
            assert proc.stdout is not None
            while True:
                line = await proc.stdout.readline()
                if not line:
                    break
                text = line.decode("utf-8", errors="replace").rstrip("\n")
                for chunk in (text.split("\r") if "\r" in text else [text]):
                    if chunk:
                        yield f"data: {chunk}\n\n"
            await proc.wait()
            yield f"data: [exit {proc.returncode}]\n\n"
            yield "event: done\ndata: 1\n\n"
            audit.log_command(session.username, command_id, argv, proc.returncode)

        return StreamingResponse(stream(), media_type="text/event-stream")

    @app.get("/audit", response_class=HTMLResponse)
    async def audit_log(request: Request, _: auth.Session = Depends(require_session)):
        return templates.TemplateResponse(request, "audit.html", {"entries": audit.read_recent()})

    @app.get("/notifications/stream")
    async def notifications_stream(request: Request, _: auth.Session = Depends(require_session)):
        bus: notify.NotificationBus = request.app.state.notification_bus
        queue = bus.subscribe()

        async def stream():
            try:
                yield "data: {}\n\n"  # open the connection immediately
                while True:
                    event = await queue.get()
                    yield f"data: {json.dumps(event)}\n\n"
            finally:
                bus.unsubscribe(queue)

        return StreamingResponse(stream(), media_type="text/event-stream")

    @app.get("/settings/notifications", response_class=HTMLResponse)
    async def settings_form(request: Request, _: auth.Session = Depends(require_session)):
        return templates.TemplateResponse(
            request, "settings.html", {"config": notify.load_notify_config(), "saved": False}
        )

    @app.post("/settings/notifications", response_class=HTMLResponse)
    async def settings_submit(
        request: Request,
        _: auth.Session = Depends(require_session),
        enabled_channels: list[str] = Form(default=[]),
        poll_interval_seconds: int = Form(30),
        cpu_threshold: float = Form(90),
        memory_threshold: float = Form(90),
        smtp_host: str = Form(""),
        smtp_port: int = Form(587),
        smtp_username: str = Form(""),
        smtp_password: str = Form(""),
        smtp_use_tls: bool = Form(False),
        smtp_from_addr: str = Form(""),
        smtp_to_addr: str = Form(""),
    ):
        config = {
            "enabled_channels": enabled_channels,
            "poll_interval_seconds": poll_interval_seconds,
            "cpu_threshold": cpu_threshold,
            "memory_threshold": memory_threshold,
            "smtp": {
                "host": smtp_host,
                "port": smtp_port,
                "username": smtp_username,
                # Keep the existing password if the field was left blank (never
                # re-render it back into the form either, see settings.html).
                "password": smtp_password or notify.load_notify_config()["smtp"].get("password", ""),
                "use_tls": smtp_use_tls,
                "from_addr": smtp_from_addr,
                "to_addr": smtp_to_addr,
            },
        }
        notify.save_notify_config(config)
        return templates.TemplateResponse(
            request, "settings.html", {"config": config, "saved": True}
        )

    @app.get("/setup", response_class=HTMLResponse)
    async def setup_form(request: Request):
        if auth.is_enrolled():
            return RedirectResponse("/login", status_code=303)
        return templates.TemplateResponse(request, "setup.html", {"error": None})

    @app.post("/setup", response_class=HTMLResponse)
    async def setup_submit(
        request: Request,
        username: str = Form(...),
        password: str = Form(...),
        confirm_password: str = Form(...),
    ):
        if auth.is_enrolled():
            return RedirectResponse("/login", status_code=303)

        username = username.strip()
        error = None
        if len(username) < 2:
            error = "Username must be at least 2 characters."
        elif len(password) < 12:
            error = "Password must be at least 12 characters."
        elif password != confirm_password:
            error = "Passwords do not match."

        if error:
            return templates.TemplateResponse(request, "setup.html", {"error": error})

        totp_secret = auth.enroll(username, password)
        uri = auth.totp_provisioning_uri(username, totp_secret)

        qr = qrcode.make(uri)
        buf = io.BytesIO()
        qr.save(buf, format="PNG")
        qr_data_uri = "data:image/png;base64," + base64.b64encode(buf.getvalue()).decode("ascii")

        return templates.TemplateResponse(
            request,
            "setup_qr.html",
            {"qr_data_uri": qr_data_uri, "totp_secret": totp_secret, "username": username},
        )

    @app.get("/login", response_class=HTMLResponse)
    async def login_form(request: Request):
        if not auth.is_enrolled():
            return RedirectResponse("/setup", status_code=303)
        return templates.TemplateResponse(request, "login.html", {"error": None})

    @app.post("/login", response_class=HTMLResponse)
    async def login_submit(
        request: Request,
        username: str = Form(...),
        password: str = Form(...),
        totp_code: str = Form(...),
    ):
        if not auth.is_enrolled():
            return RedirectResponse("/setup", status_code=303)

        client_key = _client_key(request)
        remaining = auth.backoff_seconds_remaining(client_key)
        if remaining > 0:
            return templates.TemplateResponse(
                request,
                "login.html",
                {"error": f"Too many failed attempts. Try again in {int(remaining) + 1}s."},
                status_code=429,
            )

        creds = auth.load_credentials()
        ok = (
            creds is not None
            and username.strip() == creds.username
            and auth.verify_password(creds, password)
            and auth.verify_totp(creds, totp_code)
        )

        if not ok:
            auth.record_failed_attempt(client_key)
            return templates.TemplateResponse(
                request, "login.html", {"error": "Invalid username, password, or code."}
            )

        auth.clear_failed_attempts(client_key)
        token = auth.create_session_token(creds.username)
        response = RedirectResponse("/", status_code=303)
        response.set_cookie(
            SESSION_COOKIE,
            token,
            httponly=True,
            samesite="strict",
            max_age=auth.SESSION_TTL_SECONDS,
        )
        return response

    @app.get("/logout")
    async def logout(request: Request):
        session = auth.verify_session_token(request.cookies.get(SESSION_COOKIE))
        if session is not None:
            auth.revoke_session(session.session_id)
        response = RedirectResponse("/login", status_code=303)
        response.delete_cookie(SESSION_COOKIE)
        return response

    @app.post("/settings/revoke-all")
    async def revoke_all_sessions(_: auth.Session = Depends(require_session)):
        auth.revoke_all_sessions()
        response = RedirectResponse("/login", status_code=303)
        response.delete_cookie(SESSION_COOKIE)
        return response

    return app
