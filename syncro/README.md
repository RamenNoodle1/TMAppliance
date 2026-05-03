# Syncro Container Scripts

This folder contains Syncro-friendly Bash scripts for the container workloads that were previously embedded in `user-data.txt`.

## Layout

- `docker/install-docker.sh`
  Installs Docker Engine and the Docker Compose plugin.
- `common/docker-common.sh`
  Shared helper functions used by the service scripts.
- `containers/<service>/`
  One folder per service, with its compose file, config, install script, and uninstall script.
- `install-all.sh`
  Installs Docker and deploys every service in a sensible order.

## Suggested Syncro usage

- Create one Syncro script for `docker/install-docker.sh`.
- Create one Syncro script per service `install.sh`.
- Optionally create matching Syncro remediation or uninstall scripts from each `uninstall.sh`.
- If you want the full appliance stack from Syncro, run `install-all.sh`.

## Script behavior

- Scripts are idempotent and safe to rerun.
- Service data is stored under `/opt/techmarvel/apps/<service>`.
- Uninstall scripts remove containers by default but keep persistent data unless `PURGE_DATA=true` is set.
- Docker install is separated from app deployment so you can manage Docker with its own Syncro policy if you prefer.
- Dashy was not included because the old `user-data.txt` contained a Dashy config snippet, but no Dashy container definition in the actual Docker Compose stack.

## Runtime overrides

Some services support environment variable overrides when Syncro runs the script:

- `APPLIANCE_HOST`
  Overrides the detected host IP used in generated URLs.
- `HOMEPAGE_ALLOWED_HOSTS`
  Overrides the Homepage allowed-hosts list.
- `BRAND_LOGO_URL`
  Overrides the Homepage logo URL.
- `SPEEDTEST_TRACKER_APP_URL`
  Overrides Speedtest Tracker's public URL.
- `SPEEDTEST_TRACKER_APP_KEY`
  Overrides the generated Speedtest Tracker app key.
- `PUID`, `PGID`, `APP_TIMEZONE`, `DISPLAY_TIMEZONE`, `SPEEDTEST_SCHEDULE`
  Override Speedtest Tracker defaults.
