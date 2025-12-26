# Ansible

Ansible-based infrastructure management.

## Prerequisites

Allow root SSH login for initial bootstrap.

**File:** `/etc/ssh/sshd_config`

```conf
PermitRootLogin yes
````

## Bootstrap

Bootstrap a fresh Fedora install by specifying the **target IP address** and disabling host key checking:

```bash
ANSIBLE_HOST_KEY_CHECKING=False \
ansible-playbook playbooks/bootstrap.yml \
  -i "<TARGET_IP>," \
  --user root \
  --ask-pass
```

Replace `<TARGET_IP>` with the IP address of the host being bootstrapped.

The trailing comma tells Ansible to treat the value as a single inventory host instead of a file path.

Example:

```bash
ANSIBLE_HOST_KEY_CHECKING=False \
ansible-playbook playbooks/bootstrap.yml \
  -i "192.168.33.11," \
  --user root \
  --ask-pass
```

After bootstrap, verify connectivity:

```bash
ansible -i inventory/prod all -m ping
```
