# Dell Precision 5680 internal webcam on Arch Linux

Get the internal webcam working on Arch Linux. It uses only the drivers in the standard kernel plus libcamera, so no DKMS modules, AUR packages or Intel's proprietary camera software are needed.

| | |
|---|---|
| Laptop | Dell Precision 5680 (Raptor Lake) |
| Camera chip | Intel IPU6 (`8086:a75d`), kernel driver `intel-ipu6` |
| Sensor | OmniVision OV02C10 (`OVTI02C1`), kernel driver `ov02c10` |
| Tested with | Kernel 7.2 (linux-zen), libcamera 0.7.2, PipeWire 1.6 |

Other Raptor Lake / Meteor Lake laptops with an IPU6 camera chip and an OV02C10 sensor will probably work the same way.

## Quick start

```bash
git clone <this repo>
cd precision-5680-webcam
./install.sh
```

Then log out and back in (or reboot) and check:

```bash
cam -l    # should list "Internal front camera"
```

Open **Snapshot** to see the picture. If it starts with an external webcam, switch to the built-in one.

## What it does

### 1. Packages

```bash
sudo pacman -S linux-firmware-intel libcamera libcamera-ipa pipewire-libcamera snapshot
```

- `linux-firmware-intel`: firmware for the IPU6 camera chip (`intel/ipu/ipu6ep_fw.bin.zst`)
- `libcamera`, `libcamera-ipa`: camera software, including CPU-based image processing
- `pipewire-libcamera`: lets apps reach the camera through PipeWire (browsers, Electron apps, Snapshot)
- `snapshot`: GNOME camera app

This assumes the usual `pipewire` + `wireplumber` + `xdg-desktop-portal` desktop setup.

### 2. Process the image on the CPU

[`files/etc/environment.d/90-libcamera-softisp.conf`](files/etc/environment.d/90-libcamera-softisp.conf)

```
LIBCAMERA_SOFTISP_MODE=cpu
```

On this laptop, libcamera's GPU image processing fails (`glFrameBufferTexture2D error 36054` / `debayerGPU failed`) and only one frame comes through. Processing on the CPU runs at 30 fps at 1080p, using about 3–6 ms of CPU time per frame.

You could try removing this file after a libcamera update to check whether GPU processing has been fixed.

### 3. Sensor tuning profile

[`files/etc/libcamera/ipa/simple/ov02c10.yaml`](files/etc/libcamera/ipa/simple/ov02c10.yaml) is installed to `/etc/libcamera/ipa/simple/`.

libcamera has no tuning for this sensor, so without a profile the picture is flat and grey with almost no colour. This profile sets:

- **BlackLevel**: the sensor's black level is 64 out of 1023 (measured from raw frames). It's set slightly higher (68, written as `4352` on a 16-bit scale) so that shadows come out properly dark.
- **Ccm**: a colour-correction matrix that restores colour and reduces the green/magenta tint.

The tuning was done by eye in indoor lighting and has not been calibrated.

### 4. Electron apps (Ferdium, etc.)

[`files/home/.config/electron43-flags.conf`](files/home/.config/electron43-flags.conf) is installed to `~/.config/`.

```
--enable-features=WebRtcPipeWireCamera
```

Electron apps (Chromium-based) don't use PipeWire cameras unless this flag is set. Arch's `electronNN` wrappers read `~/.config/electronNN-flags.conf`. If your app uses a different Electron version, set the matching file name:

```bash
ELECTRON_FLAGS=electron-flags.conf ./install.sh   # read by all Electron versions
```

For **Firefox**, check that `media.webrtc.camera.allow-pipewire` is `true` in `about:config`.

## Things to avoid

- **Don't blacklist `intel_ipu6`.** Older guides do this, and it stops the camera from appearing at all.
- **Don't install the out-of-tree drivers** (`ipu6-drivers`, `ivsc-driver`). The standard kernel already includes everything needed.
- **Don't use `icamerasrc` / `v4l2-relayd` / `ipu6-camera-hal`.** They aren't needed for this setup.
- **Don't use Cheese.** It's no longer maintained and freezes when you select a libcamera camera. Use Snapshot instead.
- **Don't use `--enable-webrtc-pipewire-camera`.** Chromium doesn't recognise it. The correct flag is `--enable-features=WebRtcPipeWireCamera`.

## Known limitations

- **Image quality in low light.** The OV02C10 is a small sensor. In a dim room, auto-exposure runs at its maximum (exposure 2320 lines, analogue gain 248) and the picture is grainy. Good light on your face helps most.
- **No 15 fps mode.** libcamera's basic pipeline doesn't offer frame-rate control. It also reads the sensor's exposure limit once at startup and resets the frame time, so lengthening the frame time at the driver level doesn't give a longer exposure.
- **Camera access only through libcamera/PipeWire.** No plain `/dev/video*` device appears for the internal camera. Old apps that only open `/dev/video*` won't see it.

## Troubleshooting

```bash
lsmod | grep -E 'intel_ipu6|ov02c10'           # both drivers loaded?
cam -l                                          # does libcamera see the camera?
systemctl --user show-environment | grep LIBC   # is the CPU setting active in this session?
journalctl --user -u wireplumber -b | grep -iE 'tuning|softisp|debayer'
```

After changing the tuning profile, restart PipeWire so it's picked up:

```bash
systemctl --user restart wireplumber pipewire
```

## Uninstall

```bash
sudo rm /etc/environment.d/90-libcamera-softisp.conf /etc/libcamera/ipa/simple/ov02c10.yaml
rm ~/.config/electron43-flags.conf
```
