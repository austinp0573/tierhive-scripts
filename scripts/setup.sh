#!/bin/sh

# main vps setup script
# runs all core setup in order, then optionally runs additional scripts

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# track scripts run during core setup so they can be skipped in the optional section
SCRIPTS_RUN="setup.sh run-scripts.sh"

_mark_run() { SCRIPTS_RUN="$SCRIPTS_RUN $1"; }
_was_run()  { echo "$SCRIPTS_RUN" | grep -qw "$1"; }

if [ "$(id -u)" -ne 0 ]; then
    echo "must be run as root"
    exit 1
fi

# swap first (no network needed), then apk update, then zram

echo ""
echo "swap"
sh "$SCRIPT_DIR/setup-swap.sh"
_mark_run "setup-swap.sh"

echo ""
echo "refreshing package index"
apk update

echo ""
echo "zram"
sh "$SCRIPT_DIR/setup-zram.sh"
_mark_run "setup-zram.sh"

echo ""
echo "tierhive vps setup"
echo "=================="
echo ""

# ssh server selection

echo "which ssh server do you want?"
echo "  openssh  - full featured, ~5MB more ram"
echo "  dropbear - minimal, lighter footprint"
echo ""
printf "choice [openssh/dropbear, default: openssh]: "
read -r SSH_CHOICE
SSH_CHOICE="${SSH_CHOICE:-openssh}"
echo ""

case "$SSH_CHOICE" in
    dropbear)
        echo "running alpine-minimal (dropbear)"
        sh "$SCRIPT_DIR/alpine-minimal-dropbear.sh"
        rc-service dropbear start 2>/dev/null || true
        _mark_run "alpine-minimal-dropbear.sh"
        _mark_run "alpine-minimal.sh"
        ;;
    *)
        echo "running alpine-minimal (openssh)"
        sh "$SCRIPT_DIR/alpine-minimal.sh"
        _mark_run "alpine-minimal.sh"
        _mark_run "alpine-minimal-dropbear.sh"
        ;;
esac

# base packages

echo ""
echo "installing base packages (fastfetch, doas, curl)"
apk add --no-cache fastfetch doas curl

# timezone
echo ""
echo "setting timezone to America/Chicago..."
apk add --no-cache tzdata
cp /usr/share/zoneinfo/America/Chicago /etc/localtime
echo "America/Chicago" > /etc/timezone
apk del tzdata

# core setup

echo ""
echo "unattended upgrades"
sh "$SCRIPT_DIR/unattended-upgrades-setup-alpine.sh"
_mark_run "unattended-upgrades-setup-alpine.sh"

echo ""
echo "speedtest"
sh "$SCRIPT_DIR/speedtest-go-setup.sh"
_mark_run "speedtest-go-setup.sh"

echo ""
echo "shell environment"
sh "$SCRIPT_DIR/profile-alias.sh"
_mark_run "profile-alias.sh"

echo ""
echo "non-root user"
sh "$SCRIPT_DIR/non-doas-setup.sh"
_mark_run "non-doas-setup.sh"

# ssh hardening

echo ""
echo "ssh hardening"

_harden_ssh() {
    if [ ! -s /root/.ssh/authorized_keys ]; then
        echo "no authorized_keys found in /root/.ssh/ - skipping ssh hardening to avoid lockout"
        return 0
    fi

    # detect which ssh server is active or configured to start
    if rc-update show default 2>/dev/null | grep -q dropbear || \
       rc-service dropbear status >/dev/null 2>&1; then
        # dropbear: add -s flag (disable password auth, key-only)
        DROPBEAR_CONF="/etc/conf.d/dropbear"
        if grep -q "^DROPBEAR_OPTS=" "$DROPBEAR_CONF" 2>/dev/null; then
            if ! grep "^DROPBEAR_OPTS=" "$DROPBEAR_CONF" | grep -q "\-s"; then
                sed -i 's|^DROPBEAR_OPTS="\(.*\)"|DROPBEAR_OPTS="-s \1"|' "$DROPBEAR_CONF"
            fi
        else
            echo 'DROPBEAR_OPTS="-s"' >> "$DROPBEAR_CONF"
        fi
        echo "dropbear: password auth disabled (key-only, takes effect after reboot)"
    else
        # openssh: key-only, no root password login
        SSHD_CONFIG="/etc/ssh/sshd_config"

        _set_sshd_opt() {
            key="$1"; val="$2"
            if grep -q "^#*${key}" "$SSHD_CONFIG"; then
                sed -i "s|^#*${key}.*|${key} ${val}|" "$SSHD_CONFIG"
            else
                echo "${key} ${val}" >> "$SSHD_CONFIG"
            fi
        }

        _set_sshd_opt "PasswordAuthentication" "no"
        _set_sshd_opt "PermitRootLogin" "prohibit-password"
        _set_sshd_opt "ChallengeResponseAuthentication" "no"

        rc-service sshd reload 2>/dev/null || true
        echo "openssh: password auth disabled, root key-only"
    fi
}

_harden_ssh

# done

echo ""
echo "core setup complete"
echo "-------------------"
echo ""

# optional scripts
# any .sh file in this directory that wasn't already run above will be offered here
# just drop a new script in the folder and it will automatically appear
printf "run any additional scripts? [y/n, default: n]: "
read -r RUN_OPTIONAL
RUN_OPTIONAL="${RUN_OPTIONAL:-n}"

if [ "$RUN_OPTIONAL" = "y" ]; then
    echo ""
    for script_path in "$SCRIPT_DIR"/*.sh; do
        name=$(basename "$script_path")
        _was_run "$name" && continue
        printf "run %s? [y/n, default: n]: " "$name"
        read -r run_it
        if [ "${run_it:-n}" = "y" ]; then
            echo ""
            sh "$script_path"
            echo ""
        fi
    done
fi

echo ""
echo "all done."
echo "a reboot is strongly recommended to apply all kernel and service changes."
echo ""
printf "reboot now? [y/n, default: n]: "
read -r DO_REBOOT
if [ "${DO_REBOOT:-n}" = "y" ]; then
    reboot
fi
