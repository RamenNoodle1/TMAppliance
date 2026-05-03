# Modular Ubuntu Autoinstall for Syncro

This folder replaces the all-in-one `user-data.txt` pattern with a small, maintainable source layout:

- `templates/user-data.tpl.yaml` holds the Ubuntu autoinstall structure.
- `files/` holds the first-boot scripts and systemd unit as normal files.
- `config/appliance.vars.example.json` is the safe example for machine-specific values.
- `render-user-data.ps1` assembles the source files into a final `user-data.yaml`.

## Design goals

- Keep the Ubuntu installer responsible only for OS deployment and first-boot bootstrap.
- Install the Syncro Linux agent as the only management payload during bootstrap.
- Move post-install software, monitoring, patching, and remediation into Syncro policies and scripts.
- Keep secrets and short-lived installer URLs out of versioned source files.
- Make it easy to review changes in small scripts instead of editing YAML heredocs.

## Files

- `templates/user-data.tpl.yaml`
  The base cloud-init/autoinstall template with placeholder tokens.
- `files/common.sh`
  Shared logging, retries, and environment loading helpers.
- `files/install-syncro.sh`
  Downloads the correct Syncro installer and runs it.
- `files/bootstrap.sh`
  First-boot bootstrap workflow: wait for network, update packages, install Syncro, mark complete.
- `files/techmarvel-bootstrap.service`
  One-shot systemd service so bootstrap is easy to inspect and rerun intentionally.
- `config/appliance.vars.example.json`
  Example values for hostname, SSH keys, Syncro installer URL, and other settings.
- `render-user-data.ps1`
  Renders the final autoinstall artifact into `dist/user-data.yaml`.

## Usage

1. Copy `config/appliance.vars.example.json` to `config/appliance.vars.json`.
2. Replace the placeholder values.
3. Run:

```powershell
powershell -ExecutionPolicy Bypass -File .\autoinstall\render-user-data.ps1
```

4. Use the generated `autoinstall/dist/user-data.yaml` as your Ubuntu autoinstall `user-data`.

## Security notes

- Keep `config/appliance.vars.json` out of source control.
- Prefer SSH keys and set `sshAllowPassword` to `false`.
- Supply a fresh Syncro Linux installer URL when building media, or mirror the installer internally if you need a stable deployment source.
- If you provide `syncroInstallerSha256`, the bootstrap script will verify the installer before execution.
- Rotate any password hash, SSH key, or installer URL that was exposed in older files.

## Operational notes

- The bootstrap service writes to `/var/log/techmarvel-bootstrap.log`.
- Completion is tracked with `/var/lib/techmarvel/bootstrap-complete`.
- To rerun bootstrap intentionally on a machine, remove the completion file and start the service again:

```bash
sudo rm /var/lib/techmarvel/bootstrap-complete
sudo systemctl start techmarvel-bootstrap.service
```

## Suggested Syncro split of responsibilities

- Autoinstall:
  Ubuntu install, baseline packages, SSH access, first-boot bootstrap, Syncro enrollment.
- Syncro:
  Application installs, Docker workloads, dashboards, monitoring checks, scripts, updates, and remediation.

## Related container scripts

The old Docker-based appliance services have been broken out into Syncro-manageable scripts under `syncro/README.md`.
