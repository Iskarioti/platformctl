from __future__ import annotations

import json
import os
import shutil
import socket
import ssl
import subprocess
import sys
import time
from datetime import datetime, timezone
from pathlib import Path

import psutil
import typer
from rich.console import Console
from rich.table import Table

app = typer.Typer(no_args_is_help=True)
net = typer.Typer(no_args_is_help=True)
tls = typer.Typer(no_args_is_help=True)
docker = typer.Typer(no_args_is_help=True)
incident = typer.Typer(no_args_is_help=True)

app.add_typer(net, name="net")
app.add_typer(tls, name="tls")
app.add_typer(docker, name="docker")
app.add_typer(incident, name="incident")

console = Console()


def run(command: list[str], timeout: int = 30) -> tuple[int, str]:
    try:
        result = subprocess.run(
            command,
            capture_output=True,
            text=True,
            timeout=timeout,
            check=False,
        )
        output = (result.stdout + result.stderr).strip()
        return result.returncode, output
    except FileNotFoundError as exc:
        return 127, str(exc)
    except subprocess.TimeoutExpired:
        return 124, f"Timed out after {timeout} seconds"


@app.command()
def doctor() -> None:
    """Validate the engineering workstation."""
    checks: list[tuple[str, str, str]] = []

    commands = [
        ("Git", ["git", "--version"], 10),
        ("Docker", ["docker", "--version"], 10),
        ("Docker Compose", ["docker", "compose", "version"], 15),
        ("SSH", ["ssh", "-V"], 10),
        ("Azure CLI", ["az", "version", "--query", '"azure-cli"', "-o", "tsv"], 60),
        ("OpenSSL", ["openssl", "version"], 10),
    ]

    for name, cmd, timeout in commands:
        rc, out = run(cmd, timeout=timeout)
        if rc == 0:
            state = "PASS"
        elif rc == 124:
            state = "TIMEOUT"
        else:
            state = "FAIL"
        checks.append((name, state, out.splitlines()[0] if out else ""))

    # Authentication is a separate concern from CLI installation. A logged-out
    # workstation is a warning, not a broken Azure CLI installation.
    if shutil.which("az"):
        rc, out = run(
            ["az", "account", "show", "--query", "user.name", "-o", "tsv"],
            timeout=30,
        )
        if rc == 0:
            checks.append(("Azure Login", "PASS", out.splitlines()[0] if out else "authenticated"))
        elif rc == 124:
            checks.append(("Azure Login", "TIMEOUT", out))
        else:
            checks.append(("Azure Login", "WARN", "Not authenticated or account context unavailable"))

    memory = psutil.virtual_memory()
    disk = psutil.disk_usage(str(Path.home()))

    table = Table(title="Platform Workstation Doctor")
    table.add_column("Check")
    table.add_column("State")
    table.add_column("Detail")

    for name, state, detail in checks:
        table.add_row(name, state, detail[:100])

    table.add_row("Memory available", "INFO", f"{memory.available / (1024**3):.1f} GiB")
    table.add_row("Home disk free", "INFO", f"{disk.free / (1024**3):.1f} GiB")

    console.print(table)


@net.command("dns")
def dns(host: str) -> None:
    """Resolve a DNS name."""
    try:
        results = socket.getaddrinfo(host, None)
        addresses = sorted({r[4][0] for r in results})
        for address in addresses:
            console.print(address)
    except socket.gaierror as exc:
        console.print(f"[red]DNS failed:[/red] {exc}")
        raise typer.Exit(1)


@net.command("tcp")
def tcp(host: str, port: int, timeout: float = 5.0) -> None:
    """Test a TCP connection."""
    started = time.perf_counter()
    try:
        with socket.create_connection((host, port), timeout=timeout):
            latency = (time.perf_counter() - started) * 1000
            console.print(f"[green]PASS[/green] {host}:{port} {latency:.1f} ms")
    except OSError as exc:
        console.print(f"[red]FAIL[/red] {host}:{port}: {exc}")
        raise typer.Exit(1)


@net.command("route")
def route(target: str) -> None:
    """Show the Linux route selected for a target."""
    rc, out = run(["ip", "route", "get", target])
    console.print(out)
    raise typer.Exit(rc)


@net.command("mtu")
def mtu(host: str, minimum: int = 1200, maximum: int = 1500) -> None:
    """
    Approximate IPv4 path MTU using ICMP DF probes.
    Payload = MTU - 28 for IPv4 ICMP.
    """
    low, high = minimum, maximum
    best = None

    while low <= high:
        candidate = (low + high) // 2
        payload = candidate - 28
        rc, _ = run(["ping", "-c", "1", "-W", "2", "-M", "do", "-s", str(payload), host], timeout=5)
        if rc == 0:
            best = candidate
            low = candidate + 1
        else:
            high = candidate - 1

    if best:
        console.print(f"Estimated IPv4 path MTU: [bold]{best}[/bold]")
    else:
        console.print("[red]No successful DF probe in requested range.[/red]")
        raise typer.Exit(1)


@net.command("diagnose")
def diagnose(host: str, port: int = 443) -> None:
    """Run DNS, route, TCP and TLS checks."""
    console.rule(f"{host}:{port}")

    try:
        addresses = sorted({r[4][0] for r in socket.getaddrinfo(host, None)})
        console.print(f"DNS: [green]PASS[/green] {', '.join(addresses)}")
        route_target = addresses[0]
    except socket.gaierror as exc:
        console.print(f"DNS: [red]FAIL[/red] {exc}")
        route_target = host

    rc, out = run(["ip", "route", "get", route_target])
    console.print(f"Route: {'[green]PASS[/green]' if rc == 0 else '[red]FAIL[/red]'}")
    if out:
        console.print(out)

    started = time.perf_counter()
    try:
        with socket.create_connection((host, port), timeout=5):
            latency = (time.perf_counter() - started) * 1000
        console.print(f"TCP: [green]PASS[/green] {latency:.1f} ms")
    except OSError as exc:
        console.print(f"TCP: [red]FAIL[/red] {exc}")
        return

    if port in (443, 465, 636, 6514, 8443):
        try:
            context = ssl.create_default_context()
            with socket.create_connection((host, port), timeout=5) as sock:
                with context.wrap_socket(sock, server_hostname=host) as ssock:
                    cert = ssock.getpeercert()
            console.print(f"TLS: [green]PASS[/green] {cert.get('subject', '')}")
        except Exception as exc:
            console.print(f"TLS: [red]FAIL[/red] {exc}")


@tls.command("inspect")
def tls_inspect(host: str, port: int = 443) -> None:
    """Inspect a TLS certificate using the system trust store."""
    context = ssl.create_default_context()
    with socket.create_connection((host, port), timeout=5) as sock:
        with context.wrap_socket(sock, server_hostname=host) as ssock:
            cert = ssock.getpeercert()
            cipher = ssock.cipher()

    console.print_json(json.dumps({
        "host": host,
        "port": port,
        "subject": cert.get("subject"),
        "issuer": cert.get("issuer"),
        "notBefore": cert.get("notBefore"),
        "notAfter": cert.get("notAfter"),
        "cipher": cipher,
    }, default=str))


@docker.command("report")
def docker_report() -> None:
    """Report Docker resource usage without deleting anything."""
    for cmd in (
        ["docker", "system", "df"],
        ["docker", "ps", "--format", "table {{.Names}}\t{{.Status}}\t{{.Ports}}"],
    ):
        rc, out = run(cmd)
        console.print(out)
        if rc != 0:
            raise typer.Exit(rc)


@incident.command("collect")
def incident_collect(
    host: str = typer.Option("", help="Optional target host"),
    port: int = typer.Option(443, help="Optional target port"),
) -> None:
    """Collect a local diagnostic evidence bundle."""
    timestamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    outdir = Path.cwd() / f"incident-{timestamp}"
    outdir.mkdir(parents=True, exist_ok=False)

    commands: dict[str, list[str]] = {
        "date.txt": ["date", "-Is"],
        "uname.txt": ["uname", "-a"],
        "ip-address.txt": ["ip", "address"],
        "ip-route.txt": ["ip", "route", "show", "table", "all"],
        "ip-rule.txt": ["ip", "rule", "show"],
        "resolv.conf.txt": ["cat", "/etc/resolv.conf"],
        "docker-ps.txt": ["docker", "ps", "-a"],
        "docker-df.txt": ["docker", "system", "df"],
        "df.txt": ["df", "-h"],
        "free.txt": ["free", "-h"],
    }

    if host:
        commands["target-route.txt"] = ["ip", "route", "get", host]
        commands["target-ping.txt"] = ["ping", "-c", "4", host]
        commands["target-trace.txt"] = ["traceroute", host]
        commands["target-tcp.txt"] = ["nc", "-vz", "-w", "5", host, str(port)]

    for filename, command in commands.items():
        rc, output = run(command, timeout=60)
        (outdir / filename).write_text(
            f"$ {' '.join(command)}\nexit={rc}\n\n{output}\n",
            encoding="utf-8",
        )

    summary = {
        "created_utc": timestamp,
        "hostname": socket.gethostname(),
        "target": host or None,
        "port": port if host else None,
        "warning": "Review this bundle for secrets or sensitive information before sharing."
    }
    (outdir / "summary.json").write_text(json.dumps(summary, indent=2), encoding="utf-8")
    console.print(f"Evidence written to [bold]{outdir}[/bold]")


@app.command()
def serve(
    port: int = typer.Option(8765, help="TCP port to bind on 127.0.0.1."),
) -> None:
    """Run the platformctl web control plane (localhost only, username/password + TOTP)."""
    import uvicorn

    from .web.app import create_app

    console.print(f"[bold]platformctl control plane[/bold] on http://127.0.0.1:{port}")
    console.print("[dim]Bound to 127.0.0.1 only — this is intentional, see docs/control-plane.md.[/dim]")
    uvicorn.run(create_app(), host="127.0.0.1", port=port, log_level="info")


if __name__ == "__main__":
    app()
