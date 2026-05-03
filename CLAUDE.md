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

syncro/                       # Scripts delivered via versioned GitHub release
  syncro-bootstrap.sh         # Stored in Syncro Script Library (NOT pulled from GitHub)
  install-all.sh              # Role router → calls service installers in order
  common/docker-common.sh     # Shared Docker helpers (log, retry, compose_up, render_template…)
  docker/install-docker.sh    # Installs Docker Engine + Compose plugin
  tailscale/install.sh        # Installs and authenticates Tailscale
  tailscale/uninstall.sh      # Removes Tailscale
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

## Deployment Flow

```
USB boots → Ubuntu installs (user-data.yaml)
          → bootstrap.sh downloads & runs Syncro installer
          → Syncro agent enrolls, policy triggers syncro-bootstrap.sh
          → Downloads versioned zip from GitHub (VERSION tag)
          → Optionally verifies SHA256
          → Runs install-all.sh (DEVICE_ROLE=standard)
              → Docker installs
              → Tailscale installs & authenticates
              → Containers deploy
```

### What lives where

| Location | What |
|----------|------|
| Syncro Script Library | `syncro-bootstrap.sh` only |
| GitHub (versioned release) | Everything in `syncro/` except `syncro-bootstrap.sh` |
| Syncro script variables | All secrets and per-deployment config |

### Syncro script variables

| Variable | Required | Description |
|----------|----------|-------------|
| `VERSION` | Yes | GitHub release tag, e.g. `v1.0.0` |
| `GITHUB_TOKEN` | Yes | PAT with `repo` read scope (private repo) |
| `TAILSCALE_AUTH_KEY` | Yes | Reusable Tailscale auth key |
| `DEVICE_ROLE` | No | Build role (default: `standard`) |
| `EXPECTED_SHA256` | No | If set, zip is verified before execution |

### How to cut a release

1. Merge changes to `main`, tag: `git tag v1.x.x && git push origin v1.x.x`
2. GitHub creates the release zip automatically
3. If using SHA256 verification: download the zip, run `sha256sum appliance.zip`, update `EXPECTED_SHA256` in Syncro
4. Update `VERSION` in the Syncro script variable

### Adding a new device role

1. Add a new `case` block in `syncro/install-all.sh` listing the installers for that role
2. Set `DEVICE_ROLE` to the new role name in the Syncro script variable for that policy
