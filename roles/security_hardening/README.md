# security_hardening

Baseline security hardening for Linux systems.

## Requirements

- Fedora 39+
- Ansible 2.15+
- OpenSSH 9.0+ (for post-quantum key exchange)

## What This Role Does

- **SSH Hardening:** PQ hybrid key exchange, public key auth only, no root login
- **Firewall:** firewalld with default deny policy
- **Automatic Updates:** dnf-automatic for security patches
- **Intrusion Prevention:** fail2ban for SSH brute-force protection
- **Logging:** Persistent journald with 30-day retention
- **Sudo:** Hardened configuration with passwordless access for automation users

## Variables

```yaml
# SSH
security_ssh_port: 22
security_ssh_allowed_users:
  - ansible

# Firewall
security_firewall_enabled: yes
security_firewall_default_policy: deny

# Automatic Updates
security_unattended_upgrades: yes
security_unattended_upgrades_security_only: yes
security_unattended_upgrades_auto_reboot: no

# Logging
security_journald_storage: persistent
security_journald_max_retention_sec: 2592000 # 30 days

# Fail2ban
security_fail2ban_enabled: yes
security_fail2ban_ssh_maxretry: 5
security_fail2ban_ssh_bantime: 3600
security_fail2ban_ssh_findtime: 600

# Sudo
security_sudo_passwordless_users:
  - ansible
```

## Cryptography

**Key Exchange:** Hybrid post-quantum (sntrup761x25519-sha512) with classical fallback
**Ciphers:** ChaCha20-Poly1305, AES-GCM
**MACs:** HMAC-SHA2 encrypt-then-MAC
**Auth Keys:** Ed25519 (PQ signatures not yet available in OpenSSH)

## Example

```yaml
- hosts: all
  become: yes
  roles:
    - security_hardening
```

## Recovery

If locked out (user not in `security_ssh_allowed_users`):

1. Access via console/IPMI
2. Edit `/etc/ssh/sshd_config` (remove `AllowUsers` line)
3. `systemctl restart sshd`
4. Update inventory and re-run playbook
