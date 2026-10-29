#!/usr/bin/env bash
# Set up the internal webcam (Intel IPU6 + OmniVision OV02C10) on Arch Linux.
set -euo pipefail

cd "$(dirname "$0")"

ELECTRON_FLAGS="${ELECTRON_FLAGS:-electron43-flags.conf}"

echo ":: Installing packages"
sudo pacman -S --needed linux-firmware-intel libcamera libcamera-ipa pipewire-libcamera snapshot

if grep -rqs "blacklist intel_ipu6" /etc/modprobe.d /usr/lib/modprobe.d; then
    echo "!! intel_ipu6 is blacklisted somewhere in modprobe.d; remove that blacklist:"
    grep -rs "blacklist intel_ipu6" /etc/modprobe.d /usr/lib/modprobe.d
fi

echo ":: Installing system config"
sudo install -Dm644 files/etc/environment.d/90-libcamera-softisp.conf \
    /etc/environment.d/90-libcamera-softisp.conf
sudo install -Dm644 files/etc/libcamera/ipa/simple/ov02c10.yaml \
    /etc/libcamera/ipa/simple/ov02c10.yaml

echo ":: Installing Electron flags (~/.config/${ELECTRON_FLAGS})"
config="${XDG_CONFIG_HOME:-$HOME/.config}"
if [[ -f "$config/$ELECTRON_FLAGS" ]] && ! grep -q WebRtcPipeWireCamera "$config/$ELECTRON_FLAGS"; then
    cat files/home/.config/electron43-flags.conf >> "$config/$ELECTRON_FLAGS"
else
    install -Dm644 files/home/.config/electron43-flags.conf "$config/$ELECTRON_FLAGS"
fi

echo ":: Loading driver"
sudo modprobe intel_ipu6 || true

echo
echo "Done. Log out and back in (or reboot), then verify with: cam -l"
