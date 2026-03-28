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

## Screenshots

### Login
Sign in with your RemoteHams.com credentials. Touch ID is supported on compatible Macs for quick access.

![Login screen](docs/images/login-screen.png)

### Station Lobby
Browse available remote stations worldwide. Each listing shows the radio model, location, grid square, protocol version, and connection type.

![Station lobby](docs/images/station-lobby.png)

### Radio Control Panel
Full radio control interface with VFO A/B tuning knobs, frequency display, S-meter, mode and filter selection, button controls, adjustment sliders, status readouts, and Push-to-Talk.

![Radio control panel](docs/images/radio-control-panel.png)

### Radio Control with Chat
The chat sidebar lets you communicate with other operators connected to the same station in real time.

![Radio control with chat sidebar](docs/images/radio-control-with-chat.png)

## Platform Support

| Platform | Status | Technology | Distribution |
|----------|--------|-----------|--------------|
| macOS (Apple Silicon) | Available | Swift / SwiftUI | ZIP archive in `dist/macos/` |
| iPadOS | Developed, awaiting device testing | Swift / SwiftUI | Build from source |
| Android | In development | Kotlin / Jetpack Compose | Build from source |

## Installation

### macOS (Apple Silicon)

Download the latest pre-built ZIP archive from `dist/macos/`:

- **[RCForb Client-1.0.5-arm64-20260328-131948.zip](dist/macos/RCForb%20Client-1.0.5-arm64-20260328-131948.zip)** (latest)
- `RCForb Client-1.0.4-arm64-20260328-092834.zip`
- `RCForb Client-1.0.3-arm64.zip`

> Note: The app is not code-signed or notarized. On first launch, right-click the app and select "Open" to bypass Gatekeeper, or go to System Settings > Privacy & Security to allow it.

### iPadOS

The iPadOS app has been developed but is awaiting testing on a physical device. To build from source:

```bash
cd ipadOS/RCForb
swift build
```

### Android

The Android app is currently in development. To build from source:

```bash
cd android
./gradlew assembleDebug
```

Requires Android Studio or the Android SDK with API level 26+ (Android 8.0). The app uses Jetpack Compose for the UI and Android's MediaCodec for Opus audio encoding/decoding.

## Project Structure

```
RCForb/
  macOS/             macOS desktop app (Swift/SwiftUI)
  ipadOS/            iPadOS app (Swift/SwiftUI)
  android/           Android app (Kotlin/Jetpack Compose)
  dist/              Pre-built archives
    macos/           macOS ZIP archive
  docs/              Protocol specification and documentation
```

## Building from Source

### macOS

```bash
cd macOS/RCForb
swift build        # Debug build
swift run          # Run in development
```

### iPadOS

```bash
cd ipadOS/RCForb
swift build
```

### Android

```bash
cd android
./gradlew assembleDebug
```

### Prerequisites

- Swift 5.9+ (macOS/iPadOS)
- macOS 14+ (Sonoma) or iPadOS 17+
- Android SDK API 26+ and Kotlin 1.9+ (Android)
- libopus and libspeex are bundled with the macOS app

## Protocol

RCForb uses a custom protocol over UDP (V10, Opus audio) or TCP (V7, Speex audio) to communicate with RCForb Server instances. The full protocol specification is documented in `docs/PROTOCOL_SPECIFICATION.md`.

## Changelog

### v1.0.5 (2026-03-28)

**Bug Fixes:**
- **Fixed Push-to-Talk not transmitting audio** — PTT was sending the control byte to the server but never captured or encoded microphone audio. Added Opus encoder and mic capture to the audio bridge so pressing PTT now records from the microphone, encodes to Opus, and streams to the remote station. Fix applied to macOS, iPadOS, and Android.
- Added `NSMicrophoneUsageDescription` to macOS Info.plist so the system prompts for mic permission on first PTT use.

**New Features:**
- Scrolling marquee display of the connected station name on the radio LCD (macOS and iPadOS).
- Initial Android app scaffold with full networking, protocol, and UI implementation in Kotlin/Jetpack Compose.

### v1.0.4 (2026-03-28)

- Fixed volume slider on macOS and iPadOS.

### v1.0.3

- Initial release with macOS and iPadOS support.

## Author

Ramon E. Tristani (raytristani@gmail.com)

## License

MIT
