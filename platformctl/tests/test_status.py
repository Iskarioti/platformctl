from __future__ import annotations

import json

from platformctl.web import status


def test_json_lines_parses_valid_and_skips_garbage():
    text = '{"a": 1}\n\n{"b": 2}\nnot json\n'
    assert status._json_lines(text) == [{"a": 1}, {"b": 2}]


def test_dev_services_status_parses_docker_output(monkeypatch):
    fake_output = json.dumps(
        {"Name": "dev-redis", "Service": "redis", "Image": "redis:7", "State": "running", "Status": "Up 2 minutes"}
    )

    def fake_run(cmd, timeout=30):
        assert cmd[:3] == ["docker", "compose", "-p"]
        return 0, fake_output

    monkeypatch.setattr(status, "run", fake_run)
    result = status.dev_services_status()
    assert result == [
        {
            "name": "dev-redis",
            "service": "redis",
            "image": "redis:7",
            "state": "running",
            "status": "Up 2 minutes",
            "health": "",
            "ports": [],
        }
    ]


def test_dev_services_status_empty_when_docker_fails(monkeypatch):
    monkeypatch.setattr(status, "run", lambda cmd, timeout=30: (1, "docker not available"))
    assert status.dev_services_status() == []


def test_ai_runtime_status(monkeypatch):
    fake_output = json.dumps({"Names": "ollama-local", "Image": "ollama/ollama", "Status": "Up 1 hour"})
    monkeypatch.setattr(status, "run", lambda cmd, timeout=30: (0, fake_output))
    result = status.ai_runtime_status()
    assert result == [{"name": "ollama-local", "image": "ollama/ollama", "status": "Up 1 hour"}]


def test_governed_projects_status_finds_project_and_matches_container(tmp_path, monkeypatch):
    project_root = tmp_path / "src" / "company"
    project_dir = project_root / "my-api"
    (project_dir / ".platformctl").mkdir(parents=True)
    (project_dir / ".platformctl" / "project.json").write_text(
        json.dumps({"name": "my-api", "template": "fastapi-service", "area": "company"})
    )

    policy_dir = tmp_path / "policy"
    policy_dir.mkdir()
    (policy_dir / "development.json").write_text(
        json.dumps({"projectRoots": [str(project_root)]})
    )

    monkeypatch.setattr(status, "REPO_ROOT", tmp_path)

    container_output = json.dumps(
        {
            "Names": "vsc-my-api-abc123",
            "Status": "Up 5 minutes",
            "Labels": f"devcontainer.local_folder={project_dir},other=1",
        }
    )
    monkeypatch.setattr(status, "run", lambda cmd, timeout=30: (0, container_output))

    result = status.governed_projects_status()
    assert len(result) == 1
    assert result[0]["name"] == "my-api"
    assert result[0]["template"] == "fastapi-service"
    assert result[0]["dev_container_running"] is True
    assert result[0]["dev_container_status"] == "Up 5 minutes"
    assert result[0]["tracked"] is True


def test_governed_projects_status_no_running_container(tmp_path, monkeypatch):
    project_root = tmp_path / "src" / "company"
    project_dir = project_root / "my-api"
    (project_dir / ".platformctl").mkdir(parents=True)
    (project_dir / ".platformctl" / "project.json").write_text(json.dumps({"name": "my-api"}))

    policy_dir = tmp_path / "policy"
    policy_dir.mkdir()
    (policy_dir / "development.json").write_text(json.dumps({"projectRoots": [str(project_root)]}))

    monkeypatch.setattr(status, "REPO_ROOT", tmp_path)
    monkeypatch.setattr(status, "run", lambda cmd, timeout=30: (0, ""))

    result = status.governed_projects_status()
    assert result[0]["dev_container_running"] is False
    assert result[0]["dev_container_status"] is None
    assert result[0]["tracked"] is True


def test_governed_projects_status_surfaces_untracked_cloned_repo(tmp_path, monkeypatch):
    project_root = tmp_path / "src" / "company"
    # A plain git clone: has a .git dir, no .platformctl/project.json at all.
    cloned_dir = project_root / "wiocchub-api"
    (cloned_dir / ".git").mkdir(parents=True)

    policy_dir = tmp_path / "policy"
    policy_dir.mkdir()
    (policy_dir / "development.json").write_text(json.dumps({"projectRoots": [str(project_root)]}))

    monkeypatch.setattr(status, "REPO_ROOT", tmp_path)
    monkeypatch.setattr(status, "run", lambda cmd, timeout=30: (0, ""))

    result = status.governed_projects_status()
    assert len(result) == 1
    assert result[0]["name"] == "wiocchub-api"
    assert result[0]["tracked"] is False
    assert result[0]["template"] is None
    assert result[0]["area"] is None


def test_governed_projects_status_ignores_non_git_non_metadata_dirs(tmp_path, monkeypatch):
    project_root = tmp_path / "src" / "company"
    # A plain directory that's neither a governed project nor a git repo -
    # e.g. some unrelated scratch folder. Must not show up at all.
    (project_root / "not-a-project").mkdir(parents=True)

    policy_dir = tmp_path / "policy"
    policy_dir.mkdir()
    (policy_dir / "development.json").write_text(json.dumps({"projectRoots": [str(project_root)]}))

    monkeypatch.setattr(status, "REPO_ROOT", tmp_path)
    monkeypatch.setattr(status, "run", lambda cmd, timeout=30: (0, ""))

    assert status.governed_projects_status() == []


def test_parse_ms_date_handles_dotnet_and_passthrough():
    assert status._parse_ms_date(None) is None
    assert status._parse_ms_date("/Date(1700000000000)/") == "2023-11-14T22:13:20+00:00"
    assert status._parse_ms_date("not a date") == "not a date"


def test_background_jobs_windows_healthy_and_unhealthy(monkeypatch):
    monkeypatch.setattr(status, "is_wsl", lambda: True)

    responses = iter(
        [
            (0, json.dumps({"TaskName": "WorkstationSetupAutoSync", "LastRunTime": None, "LastTaskResult": 0, "NextRunTime": None})),
            (0, ""),  # WorkstationAutoUpgrade not installed
        ]
    )
    monkeypatch.setattr(status, "run", lambda cmd, timeout=30: next(responses))

    jobs = status.background_jobs_status()
    assert jobs[0]["name"] == "WorkstationSetupAutoSync"
    assert jobs[0]["installed"] is True
    assert jobs[0]["healthy"] is True
    assert jobs[1]["name"] == "WorkstationAutoUpgrade"
    assert jobs[1]["installed"] is False
    assert jobs[1]["healthy"] is False


def test_background_jobs_linux(monkeypatch):
    monkeypatch.setattr(status, "is_wsl", lambda: False)
    monkeypatch.setattr(status.sys, "platform", "linux")

    def fake_run(cmd, timeout=30):
        if cmd[:2] == ["systemctl", "--user"] and "is-active" in cmd:
            return 0, "active"
        return 0, "success"

    monkeypatch.setattr(status, "run", fake_run)
    jobs = status.background_jobs_status()
    assert all(j["healthy"] for j in jobs)


def test_resource_utilization_shape(monkeypatch):
    monkeypatch.setattr(status, "is_wsl", lambda: False)
    monkeypatch.setattr(status, "run", lambda cmd, timeout=30: (1, ""))
    data = status.resource_utilization()
    assert "cpu_percent" in data["host"]
    assert "memory_percent" in data["host"]
    assert data["containers"] == []
