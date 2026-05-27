# tierhive-scripts

[Tierhive](https://tierhive.com/) offers VPS instances starting at 128MB RAM and 1GB disk. This repo is for setting up and maintaining their Alpine Linux image with a small footprint and predictable configuration.

The original shell scripts still work and are useful for one-off setup. I am moving the repeatable server configuration over to Ansible playbooks, starting with WireGuard, so the same repo can handle both a fresh VPS and later updates without redoing everything by hand.

## usage

For the shell scripts, run `setup.sh` first on a fresh VPS. It runs core setup in order, prompts for values where needed, and offers any remaining scripts at the end. Individual scripts can also be run standalone. `run-scripts.sh` walks through everything in the directory interactively.

For Ansible, start in `ansible/`. The current playbook provisions WireGuard on Alpine Linux with nftables-based peer access controls. See `ansible/README.md` for the inventory layout and WireGuard variables.

## scripts

| script | what it does |
|---|---|
| `setup.sh` | main setup — run this first on a fresh VPS |
| `alpine-minimal.sh` | strips the system down: removes cloud-init, python, unused kernel modules, replaces chrony with busybox ntpd, tunes sysctl for low RAM |
| `alpine-minimal-dropbear.sh` | same as above but swaps OpenSSH for Dropbear |
| `setup-swap.sh` | creates a swapfile, prompts for size |
| `setup-zram.sh` | sets up compressed swap in RAM, prompts for size and algorithm |
| `profile-alias.sh` | configures `/etc/profile.d/` with aliases, an ash-compatible prompt, and a fastfetch welcome on login |
| `non-doas-setup.sh` | creates a non-root user, adds them to wheel, configures doas, optionally copies SSH keys |
| `unattended-upgrades-setup-alpine.sh` | daily auto-upgrade via crond, writes a reboot alert to motd when kernel/musl/openssl updates |
| `speedtest-go-setup.sh` | installs speedtest-go |
| `ipv6_and_net_optimization.sh` | network sysctl tuning scaled to available RAM, optional static IPv6 setup |
| `set-hostname.sh` | renames the system hostname cleanly |
| `run-scripts.sh` | walks through every script in the directory and asks if you want to run it |

## ansible

The Ansible work is the direction this repo is moving. The goal is to keep server configuration idempotent, modular, and safe to rerun. For now, the Ansible scope is intentionally narrow: WireGuard server setup on Alpine Linux, including package setup, forwarding, nftables rules, and peer access controls.

The base scripts still exist because they are convenient and because not everything has been moved yet. If you plan to manage a host with Ansible, do not remove Python from that host (at present the minimal scripts remove python).

## notes

- everything here is Alpine Linux only. don't run these on anything else.
- these reflect my personal setup preferences. read them before you run them.
- shell scripts must be run as root.
- real inventories, keys, and host-specific values should stay out of git.

---

&nbsp;

**466f724a616e6574**
