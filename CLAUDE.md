# Tech Marvel Appliance Automation

## Project Goal

Automate deploying a network appliance on bare Ubuntu Server that:
1. Installs Ubuntu unattended via cloud-init autoinstall
2. Enrolls the machine in Syncro (RMM)
3. Syncro runs modular scripts to install Tailscale + Docker containers

## Repository Layout

```
autoinstall/                  # Ubuntu autoinstall artifacts
  config/appliance.vars.example.json   # Config template (copy, never commit the real one)
  dist/user-data.example.yaml          # Example rendered output
  files/                               # Scripts embedded into cloud-init
    bootstrap.sh                       # First-boot: waits for network, calls install-syncro.sh
    common.sh                          # Shared bash utilities (log, retry, wait_for_network)
    install-syncro.sh                  # Downloads and runs the Syncro installer
    techmarvel-bootstrap.service       # Systemd one-shot unit
  templates/user-data.tpl.yaml         # Cloud-init template with __TOKEN__ placeholders
  render-user-data.ps1                 # PowerShell: reads vars + files → dist/user-data.yaml
  .gitignore                           # Excludes config/appliance.vars.json and dist/

syncro/                       # Scripts Syncro delivers and runs post-enrollment
  install-all.sh              # Master orchestrator — runs everything in order
  common/docker-common.sh     # Shared Docker helpers (log, retry, compose_up, render_template…)
  docker/install-docker.sh    # Installs Docker Engine + Compose plugin
  containers/<service>/       # One directory per container service
    compose.yaml              # Docker Compose definition
    install.sh                # Idempotent installer
    uninstall.sh              # Stops containers, optionally purges data (PURGE_DATA=1)
    config/                   # Config/template files copied into place

user-data.txt                 # Legacy all-in-one file — superseded by autoinstall/, kept for reference
```

## Containers (services installed by Syncro)

| Service           | Port(s)       | Image                                      |
|-------------------|---------------|--------------------------------------------|
| Uptime Kuma       | 3001          | louislam/uptime-kuma:1                     |
| Homepage          | 3005          | ghcr.io/gethomepage/homepage:latest        |
| OpenSpeedTest     | 3002, 3003    | openspeedtest/latest:latest                |
| Speedtest Tracker | 8982, 8443    | lscr.io/linuxserver/speedtest-tracker:latest |
| Domotz            | (host network)| domotz/domotz-collector:latest             |

Tailscale is also installed by Syncro (not a Docker container).

## Key Conventions

- All scripts source `common/docker-common.sh` for shared helpers.
- Scripts are **idempotent** — safe to re-run (checks before installing).
- Service data lives under `/opt/techmarvel/apps/<service>/`.
- Adding a new Docker service = create `containers/<name>/{compose.yaml,install.sh,uninstall.sh}` and add it to `install-all.sh`.
- Environment variable overrides: `APPLIANCE_HOST`, `PUID`, `PGID`, `APP_TIMEZONE`, `PURGE_DATA`.
- `config/appliance.vars.json` is gitignored — use `appliance.vars.example.json` as the template.

## How to Build the autoinstall USB/ISO

1. Copy `config/appliance.vars.example.json` → `config/appliance.vars.json` and fill in values.
2. Run `render-user-data.ps1` — outputs `dist/user-data.yaml`.
3. Place `user-data.yaml` and an empty `meta-data` file on the autoinstall source (USB or HTTP server).

## Current Status (as of 2026-05-03)

**Done:**
- Full autoinstall pipeline (OS install → Syncro enrollment)
- Docker installation module
- Containers: Uptime Kuma, Homepage, OpenSpeedTest, Speedtest Tracker, Domotz
- Homepage branding/config templates
- Master `install-all.sh` orchestrator

**Complete as of 2026-05-03.**
