#!/usr/bin/env python3
import logging
import os
import re
import shlex
import subprocess

import typer

# Settings can be changed with environment variables, like in config.sh
PAAS_HOST = os.getenv("PAAS_HOST", "paas")
PLATFORM_DIR = os.getenv("PAAS_PLATFORM_DIR", "/vagrant/platform")
REPOS_DIR = os.getenv("PAAS_REPOS_DIR", "~")

APP_NAME_RE = re.compile(r"^[a-z0-9-]+$")

app = typer.Typer(help="mini-PaaS command line tool", no_args_is_help=True)
log = logging.getLogger("paas")


@app.callback()
def main(verbose: bool = typer.Option(False, "--verbose", "-v", help="Show debug logs")):
    logging.basicConfig(
        level=logging.DEBUG if verbose else logging.INFO,
        format="%(asctime)s [%(levelname)s] %(message)s",
        datefmt="%H:%M:%S",
    )


def run_remote(command: str, capture: bool = True, tty: bool = False) -> str:
    """Run a command on the platform server over SSH."""
    args = ["ssh"]
    if tty:
        args.append("-t")
    args += [PAAS_HOST, command]

    log.debug("running on %s: %s", PAAS_HOST, command)
    result = subprocess.run(args, capture_output=capture, text=True)

    if result.returncode != 0:
        if capture and result.stderr:
            log.error(result.stderr.strip())
        log.error("remote command failed with exit code %s", result.returncode)
        raise typer.Exit(result.returncode)

    return result.stdout if capture else ""


def validate_name(name: str) -> str:
    if not APP_NAME_RE.match(name):
        log.error("app name may contain only lowercase letters, digits and dashes")
        raise typer.Exit(1)
    return name


@app.command()
def create(name: str, port: int):
    validate_name(name)
    log.info("creating app %s on port %s", name, port)
    run_remote(f"{PLATFORM_DIR}/create-app.sh {shlex.quote(name)} {port}", capture=False)


@app.command("ls")
def list_apps():
    script = f"""
for repo in {REPOS_DIR}/*.git; do
  [ -d "$repo" ] || continue
  name=$(basename "$repo" .git)
  port=$(git -C "$repo" config --get paas.port || echo "-")
  state=$(systemctl is-active "$name" 2>/dev/null || true)
  echo "$name $port $state"
done
"""
    output = run_remote(script).strip()
    if not output:
        typer.echo("no apps yet, create one with: paas create <name> <port>")
        return

    typer.echo(f"{'APP':<20}{'PORT':<8}STATE")
    for line in output.splitlines():
        name, port, state = line.split()
        color = typer.colors.GREEN if state == "active" else typer.colors.RED
        typer.echo(f"{name:<20}{port:<8}" + typer.style(state, fg=color))


@app.command()
def logs(
    name: str,
    lines: int = typer.Option(50, "--lines", "-n", help="Number of lines to show"),
    follow: bool = typer.Option(False, "--follow", "-f", help="Follow new log lines"),
):
    validate_name(name)
    command = f"sudo journalctl -u {shlex.quote(name)} -n {lines} --no-pager"
    if follow:
        command += " -f"
    run_remote(command, capture=False, tty=follow)


@app.command()
def status(name: str):
    """Show app state, port, CPU and memory."""
    validate_name(name)
    q = shlex.quote(name)
    command = (
        f"systemctl show {q} --property=LoadState,ActiveState,SubState,MainPID,"
        f"MemoryCurrent,CPUUsageNSec,NRestarts,ActiveEnterTimestamp; "
        f"echo \"Port=$(git -C {REPOS_DIR}/{q}.git config --get paas.port || echo -)\""
    )
    output = run_remote(command)
    info = dict(line.split("=", 1) for line in output.splitlines() if "=" in line)

    if info.get("LoadState") == "not-found":
        log.error("app %s is not deployed yet", name)
        raise typer.Exit(1)

    state = f"{info.get('ActiveState')} ({info.get('SubState')})"
    color = typer.colors.GREEN if info.get("ActiveState") == "active" else typer.colors.RED

    typer.echo(f"App:       {name}")
    typer.echo("State:     " + typer.style(state, fg=color))
    typer.echo(f"Port:      {info.get('Port')}")
    typer.echo(f"PID:       {info.get('MainPID')}")
    typer.echo(f"Memory:    {format_bytes(info.get('MemoryCurrent'))}")
    typer.echo(f"CPU time:  {format_cpu(info.get('CPUUsageNSec'))}")
    typer.echo(f"Restarts:  {info.get('NRestarts', '-')}")
    typer.echo(f"Since:     {info.get('ActiveEnterTimestamp') or '-'}")


def format_bytes(value: str | None) -> str:
    if not value or not value.isdigit():
        return "-"
    return f"{int(value) / 1024 / 1024:.1f} MB"


def format_cpu(value: str | None) -> str:
    if not value or not value.isdigit():
        return "-"
    return f"{int(value) / 1_000_000_000:.2f} s"


if __name__ == "__main__":
    app()