# RCForb Client

A multi-platform remote radio control client for [RemoteHams.com](https://www.remotehams.com) stations. RCForb allows amateur radio operators to connect to and control remote HF/VHF/UHF radio stations over the internet from anywhere in the world.

## What It Does

RCForb Client connects to RCForb Server instances published on RemoteHams.com, giving you full remote control of the radio including:

- **Frequency tuning** via VFO A/B knobs with configurable step sizes (10 Hz to 10 kHz)
- **Mode selection** (LSB, USB, AM, CW, FM, RTTY, and more)
- **Real-time audio streaming** (receive and transmit via Push-to-Talk)
- **S-meter display** with live signal strength readings
- **Full radio controls** including buttons, dropdowns, sliders for filters, noise reduction, AGC, squelch, and more
- **Split mode operation** for DX pileups (RX on VFO A, TX on VFO B)
- **Chat** with other operators connected to the same station
- **Rotator, amplifier, and antenna switch control** (when available on the remote station)

## Platform Support

| Platform | Status | Technology | Installer |
|----------|--------|-----------|-----------|
| macOS (Apple Silicon) | Available | Electron | `dist/macos/RCForb Client-1.0.0-arm64.dmg` |
| macOS (Intel) | Planned | Electron | Build from source on Intel Mac |
| Windows | Planned | Electron | Must be built on Windows (see `dist/windows/BUILD_INSTRUCTIONS.md`) |
| iOS / iPadOS | Planned | Swift / SwiftUI | See `dist/ios/BUILD_INSTRUCTIONS.md` |
| Android | Planned | Kotlin | See `dist/android/BUILD_INSTRUCTIONS.md` |

## Installers

### macOS

Pre-built installers for Apple Silicon are in `dist/macos/`:

- **DMG** (recommended): `RCForb Client-1.0.0-arm64.dmg` - Mount and drag to Applications
- **ZIP**: `RCForb Client-darwin-arm64-1.0.0.zip` - Extract and run directly

> Note: The app is not code-signed or notarized. On first launch, right-click the app and select "Open" to bypass Gatekeeper, or go to System Settings > Privacy & Security to allow it.

### Windows

The Windows installer must be built on a Windows machine due to native dependencies. See `dist/windows/BUILD_INSTRUCTIONS.md` for instructions.

### iOS / iPadOS / Android

Mobile clients are planned but not yet implemented. The `ios/` and `android/` directories are scaffolding for future development.

## Project Structure

```
RCForb/
  desktop/          Electron app (macOS + Windows)
  android/          Android app (planned)
  ios/              iOS/iPadOS Universal app (planned)
  dist/             Pre-built installers
    macos/          macOS DMG and ZIP
    windows/        Windows installer (build instructions)
    ios/            iOS/iPadOS IPA (build instructions)
    android/        Android APK (build instructions)
  docs/             Protocol specification and documentation
```

## Building from Source

### Desktop (macOS)

```bash
cd desktop
npm install
npm start          # Development mode
npm run make       # Build macOS DMG + ZIP
```

### Prerequisites

- Node.js 18+
- libspeex (`brew install speex` on macOS)

## Protocol

RCForb uses a custom protocol over UDP (V10, Opus audio) or TCP (V7, Speex audio) to communicate with RCForb Server instances. The full protocol specification is documented in `docs/PROTOCOL_SPECIFICATION.md`.

## Author

Ramon E. Tristani (raytristani@gmail.com)

## License

MIT
