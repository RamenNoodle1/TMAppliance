# Tech Marvel Appliance

Automated deployment system for Tech Marvel network appliances. Installs Ubuntu Server unattended, enrolls the machine in Syncro, then deploys Tailscale and a suite of Docker-based monitoring and dashboard services.

## What Gets Installed

| Service           | Port(s)    | Purpose                        |
|-------------------|------------|--------------------------------|
| Homepage          | 3005       | Unified dashboard (start here) |
| Uptime Kuma       | 3001       | Uptime monitoring              |
| Speedtest Tracker | 8982, 8443 | WAN speed tracking             |
| OpenSpeedTest     | 3002, 3003 | LAN speed testing              |
| Domotz            | —          | Network monitoring (host mode) |
| Tailscale         | —          | Secure remote access           |

---

## Repository Structure

```
autoinstall/                        # Phase 1 — Ubuntu OS installation
  config/
    appliance.vars.example.json     # Config template — copy and fill in per deployment
  files/                            # Scripts embedded into the installer
  templates/user-data.tpl.yaml      # Cloud-init autoinstall template
  render-user-data.ps1              # Builds the autoinstall user-data.yaml
  make-cidata-iso.ps1               # Builds the CIDATA VHD for Hyper-V testing
  make-autoinstall-iso.ps1          # Patches Ubuntu ISO to boot unattended

syncro/                             # Phase 2 — Post-enrollment service installation
  syncro-bootstrap.sh               # Lives in Syncro Script Library (not GitHub)
  install-all.sh                    # Runs all installers in order
  docker/install-docker.sh          # Installs Docker Engine
  tailscale/install.sh              # Installs and authenticates Tailscale
  containers/<service>/
    install.sh                      # Installs the container
    uninstall.sh                    # Removes the container
    compose.yaml                    # Docker Compose definition
```

---

## Initial Setup (One Time)

### 1. Prepare the Ubuntu ISO

Download Ubuntu Server and patch it to boot unattended (only needed once per Ubuntu version):

```powershell
.\autoinstall\make-autoinstall-iso.ps1 -SourceIso "C:\path\to\ubuntu-server.iso"
```

Output: `C:\HyperV\ubuntu-autoinstall.iso`

### 2. Set Up Syncro

In the Syncro Script Library, create a new Linux Bash script (run as root) with the contents of `syncro/syncro-bootstrap.sh`.

Add these script variables in the Syncro UI:

| Variable            | Description                                  |
|---------------------|----------------------------------------------|
| `VERSION`           | GitHub release tag, e.g. `v1.0.1`           |
| `GITHUB_TOKEN`      | GitHub PAT with `repo` read scope            |
| `TAILSCALE_AUTH_KEY`| Reusable Tailscale auth key                  |

Create a Syncro policy that runs this script once on agent enrollment.

---

## New Computer Cheatsheet

Everything below assumes one-time setup is already done (ISO patched, Syncro configured).

```
1. Edit appliance.vars.json         → set hostname, password, SSH key
2. .\autoinstall\render-user-data.ps1
3. .\autoinstall\make-cidata-iso.ps1
4. Hyper-V: attach ubuntu-autoinstall.iso + cidata.vhd → boot
5. Wait for Ubuntu to install and reboot (~5-10 min)
6. In Syncro: find the new device → run syncro-bootstrap script
7. Watch install: ssh techmarvel@<ip> then tail -f /var/log/techmarvel-install.log
8. Done — open Homepage at http://<ip>:3005
```

---

## Per-Deployment Steps

### 1. Fill in the config

Copy the example config and fill in values for this customer/device:

```powershell
Copy-Item autoinstall\config\"appliance.vars.example copy.json" autoinstall\config\appliance.vars.json
```

Edit `appliance.vars.json`:

| Field                | Description                                         |
|----------------------|-----------------------------------------------------|
| `hostname`           | Machine hostname                                    |
| `username`           | Local admin username                                |
| `passwordHash`       | Run `wsl -- openssl passwd -6` to generate          |
| `sshAuthorizedKeys`  | Your public key — see note below                    |
| `syncroInstallerUrl` | From Syncro → Admin → Agent Installers → Linux      |
| `syncroToken`        | Syncro agent token                                  |

**SSH Key Note:** Generate a dedicated key for appliance access (do this once per technician):

```powershell
ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519_pc_tm_appliance -C "techmarvel-appliance"
```

Get the public key to paste into `sshAuthorizedKeys`:
```powershell
cat ~/.ssh/id_ed25519_pc_tm_appliance.pub
```

The output starts with `ssh-ed25519 AAAA...` — paste that entire line into the `sshAuthorizedKeys` field. Do not duplicate the `ssh-ed25519` prefix.

Add to `~/.ssh/config` so SSH uses the right key automatically:
```
Host <appliance-ip>
    User techmarvel
    IdentityFile ~/.ssh/id_ed25519_pc_tm_appliance
```

### 2. Generate the autoinstall config

```powershell
.\autoinstall\render-user-data.ps1
```

### 3. Build the CIDATA VHD (Hyper-V testing)

```powershell
.\autoinstall\make-cidata-iso.ps1
```

Output: `C:\temp\cidata\cidata.vhd`

### 4. Boot the VM

In Hyper-V:
1. DVD Drive → `C:\HyperV\ubuntu-autoinstall.iso`
2. SCSI Controller → Hard Drive → `C:\temp\cidata\cidata.vhd`
3. Boot — Ubuntu installs unattended, Syncro enrolls, services deploy automatically

---

## Releasing a New Version

```powershell
git tag v1.x.x
git push origin v1.x.x
```

Then update `VERSION` in the Syncro script variable.

---

## Adding a New Docker Service

1. Create `syncro/containers/<name>/compose.yaml`
2. Create `syncro/containers/<name>/install.sh`
3. Create `syncro/containers/<name>/uninstall.sh`
4. Add the installer to the `standard` case in `syncro/install-all.sh`
5. Tag a new release

## Manually Starting All Containers

If containers need to be restarted on the appliance:

```bash
for dir in /opt/techmarvel/apps/*/; do
  [ -f "${dir}compose.yaml" ] && docker compose -f "${dir}compose.yaml" up -d
done
```

---

## Changing the IP Address or Hostname

### 1. Set a Static IP

Edit the netplan config on the appliance:

```bash
sudo nano /etc/netplan/00-installer-config.yaml
```

Replace the DHCP config with:

```yaml
network:
  version: 2
  ethernets:
    lan:
      match:
        name: "en*"
      addresses: [192.168.x.x/24]
      routes:
        - to: default
          via: 192.168.x.1
      nameservers:
        addresses: [8.8.8.8, 8.8.4.4]
```

Apply the change:

```bash
sudo netplan apply
```

### 2. Change the Hostname

```bash
sudo hostnamectl set-hostname new-hostname
sudo nano /etc/hosts    # update the 127.0.1.1 line to match
```

### 3. Update Homepage

Homepage has the appliance IP baked in at install time. After an IP change, re-run its installer to regenerate the config with the new IP:

```bash
sudo /opt/techmarvel/setup/syncro/containers/homepage/install.sh
```

### 4. For Future Deployments

To use a static IP from the start, update `networkYaml` in `appliance.vars.json` before rendering:

```json
"networkYaml": "version: 2\nethernets:\n  lan:\n    match:\n      name: \"en*\"\n    addresses: [192.168.x.x/24]\n    routes:\n      - to: default\n        via: 192.168.x.1\n    nameservers:\n      addresses: [8.8.8.8]"
```

Then re-run `render-user-data.ps1` and `make-cidata-iso.ps1`.
