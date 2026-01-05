# Lab Environment

Quick reference for local development VM.

---

## VM Setup

### Prerequisites

```bash
# Arch/Manjaro
sudo pacman -S qemu-full
```

### Create Base Image

1. Download Fedora Server ISO: https://fedoraproject.org/server/download
2. Create base disk:

```bash
cd lab/vm/images
qemu-img create -f qcow2 fedora43_base.qcow2 50G
```

3. Install OS:

```bash
qemu-system-x86_64 \
  -enable-kvm \
  -m 4G \
  -smp 4 \
  -drive file=fedora43_base.qcow2,if=virtio \
  -cdrom ~/Downloads/Fedora-Server-*.iso \
  -boot d
```

4. During install: Set root password only (no user creation)
5. After install: Shutdown VM

### VM Management

**Basic commands:**

```bash
cd lab/vm

# Start VM (continues current work)
./run-fedora.sh

# Create snapshot of current state
./run-fedora.sh save <name>

# Revert to snapshot
./run-fedora.sh load <name>

# Revert to fresh OS install
./run-fedora.sh load base

# Delete working image (start fresh next run)
./run-fedora.sh reset

# List all snapshots
./run-fedora.sh list

# Show help
./run-fedora.sh help
```

**Common workflow:**

```bash
# 1. First run (creates working image + 'base' snapshot)
./run-fedora.sh

# 2. Bootstrap
ansible-playbook playbooks/bootstrap.yml ...
# (shut down VM: sudo poweroff)

# 3. Save bootstrapped state
./run-fedora.sh save bootstrap

# 4. Test configurations
./run-fedora.sh
ansible-playbook playbooks/site.yml ...

# 5. Save working states
./run-fedora.sh save postgres
./run-fedora.sh save n8n-deployed

# 6. Revert to any state
./run-fedora.sh load bootstrap
```

**Snapshot management:**

- Location: `lab/vm/images/`
- Base: `fedora43_base.qcow2` (read-only backup, never modified)
- Work: `fedora43.qcow2` (working image with all snapshots)
- Snapshots stored internally in working image
- List: `./run-fedora.sh list`
- Disaster recovery: `./run-fedora.sh reset` (deletes working image, next run creates fresh copy)

---

## Ansible Access

### Bootstrap

```bash
ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook playbooks/bootstrap.yml -i "localhost," --user root --ask-pass -e ansible_port=2222
```

### Deploy

```bash
# Full deployment
ansible-playbook -i inventory/lab playbooks/site.yml

# Updates only
ansible-playbook -i inventory/lab playbooks/update.yml

# Test prod config on VM
ansible-playbook -i inventory/prod playbooks/site.yml \
  --limit n150-01 \
  -e ansible_host=127.0.0.1 \
  -e ansible_port=2222
```

---

## Network

- Host: `localhost:2222` (SSH forwarded from VM port 22)
- VM internal: Standard network (NAT via QEMU user networking)
