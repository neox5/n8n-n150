# Prerequisites

## Hardware Requirements

**N150 Mini Cube:**
- CPU: x86_64 architecture
- RAM: 12GB minimum
- Storage: 512GB M.2 SSD minimum
- Network: Internal network access + outbound internet

## Base Operating System

**Required: Fedora Server 41**

Installation type: Minimal server installation

## Required Packages

```bash
sudo dnf install -y \
  podman \
  podman-compose \
  restic \
  rsync \
  git
```

## System Configuration

### SELinux
Status: Enforcing (default)
No changes required - Podman rootful runs correctly with SELinux enforcing.

### Firewall
Internal-only deployment - no external exposure required.
Port 5678 accessible only from internal network.

```bash
# If firewall configuration needed:
sudo firewall-cmd --permanent --add-port=5678/tcp --zone=internal
sudo firewall-cmd --reload
```

### Storage
Minimum 100GB free space in `/root` for:
- Container images: ~2GB
- n8n data: variable
- PostgreSQL data: variable
- Restic repository: variable (depends on retention)

### Time Synchronization
```bash
sudo systemctl enable --now chronyd
```

## Pre-Deployment Checklist

- [ ] Fedora Server 41 installed
- [ ] All required packages installed
- [ ] Root partition has 100GB+ free space
- [ ] System time synchronized
- [ ] Internal network connectivity verified
- [ ] Outbound internet access verified
- [ ] Git repository cloned to `/root/n8n-n150/`
