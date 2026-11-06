# Adelvo Audio Drivers — Virtual Audio Devices for macOS

[![Support my work on Ko-fi](https://img.shields.io/badge/%E2%99%A5_Support_my_work-Ko--fi-FF5E5B?style=for-the-badge&logo=ko-fi&logoColor=white)](https://ko-fi.com/adelvo)

![Free](https://img.shields.io/badge/Free-3b82f6?style=flat) ![macOS](https://img.shields.io/badge/macOS-ff7e00?style=flat) ![Signed & notarized](https://img.shields.io/badge/signed_%26_notarized-10b981?style=flat)

Free macOS installer that creates up to **8 independent virtual stereo audio devices plus an optional 16-channel device**, based on [BlackHole](https://github.com/ExistentialAudio/BlackHole). Built for [MixDesk X](https://adelvo.io/mix-desk-x), but works with any audio application. Signed with our Developer ID and notarized by Apple.

**[⬇ Download the latest installer](../../releases/latest)** · also on [adelvo.io/mix-desk-x](https://adelvo.io/mix-desk-x/#patchbay)

![Adelvo Audio Driver Installer](docs/installer.jpg)

## What it does

Each virtual device acts as a stereo audio cable: audio sent to the **output** appears at the **input** of the same device. This is what makes advanced audio routing possible — MixDesk X (or any app) sends a submix to a virtual output, and your target app picks it up as a regular input.

## Included devices

| Device | Purpose |
|---|---|
| **MixDesk X System** | macOS system audio → MixDesk X input |
| **MixDesk X WebRTC** | MixDesk X mix → Browser / video conferencing |
| **MixDesk X Mix 3–8** | Additional outputs for OBS, recording, DAWs, etc. |
| **MixDesk X 16ch** *(optional, new in 2.0)* | One device with 16 channels = 8 stereo pairs. In MixDesk X, pairs 3+4 and up are part of MixDesk X Pro. |

The installer lets you choose which devices to install via checkboxes. System and WebRTC are pre-selected — **2 devices are sufficient for most setups.**

## Upgrading from 1.x (MixDeskEQ devices)

Version 2.0 renames the devices from "MixDeskEQ …" to "MixDesk X …" and removes the old ones during installation. Tick the same devices you had before under **Customize**.

- **MixDesk X 1.42.044 or newer** switches your presets to the new devices automatically (press Save to keep it), and *System audio via driver* finds both names.
- **Other apps** (Zoom, Discord, OBS, browser …) need the new device selected once.

## Install

1. Download the latest `.pkg` from [Releases](../../releases)
2. Double-click, authenticate, done
3. Click **Customize** to choose which devices to install

After installation, devices appear as regular audio inputs and outputs everywhere — System Settings, OBS, Zoom, DAWs, any CoreAudio app.

## Uninstall

An uninstaller `.pkg` is included in the release. It removes all MixDesk X audio devices (and old MixDeskEQ devices) and cleans up.

## Build from source

Requirements: Xcode Command Line Tools, Git

```bash
chmod +x build_installer.sh
./build_installer.sh
```

The script clones [BlackHole](https://github.com/ExistentialAudio/BlackHole), compiles the instances with custom names and channel counts, and packages them as a standard macOS `.pkg` installer with a matching uninstaller.

## Why multiple devices?

Because each output bus in MixDesk X can feed a different virtual device:

- **Bus 1** → speakers (physical)
- **Bus 2** → virtual device → OBS picks it up as mic input
- **Bus 3** → another virtual device → Zoom
- **Bus 4** → yet another → recording app

Each path is independent, each carries a different submix.

## License

GPL-3.0 — see [LICENSE](LICENSE)

Based on [BlackHole](https://github.com/ExistentialAudio/BlackHole) by [Existential Audio Inc.](https://existential.audio/)

## Links

- [MixDesk X](https://adelvo.io/mix-desk-x) — free multi-device audio mixer & router for macOS, Windows and Linux ([GitHub](https://github.com/adelvo-software/MixDeskX))
- [Adelvo Software](https://adelvo.io) — Professional tools for live production and media workflows
