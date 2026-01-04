# Ansible

Ansible-based infrastructure management.

---

## Install Requirements (Control Node)

```bash
pacman -S ansible sops age
```

---

## Secrets (SOPS)

```bash
# Place the age private key at:
~/.config/sops/age/keys.txt

# Set permissions:
chmod 700 ~/.config/sops/age
chmod 600 ~/.config/sops/age/keys.txt

# Verify access (must succeed):
sops -d inventory/prod/host_vars/<host>/secrets.yml >/dev/null
```

---

## Bootstrap

Bootstrap a fresh system (root SSH required):

```bash
ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook playbooks/bootstrap.yml -i "<TARGET_IP>," --user root --ask-pass
```

---

## Deploy

Full deployment:

```bash
ansible-playbook playbooks/site.yml
```

Updates only:

```bash
ansible-playbook playbooks/update.yml
```
