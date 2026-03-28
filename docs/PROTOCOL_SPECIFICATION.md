# RCForb Client Protocol Specification

*Reverse-engineered from RCForb Client v10 .NET assemblies (Dec 2023 build)*

---

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Authentication Flow](#authentication-flow)
3. [V10 Protocol (UDP - Opus)](#v10-protocol-udp---opus)
4. [V7 Protocol (TCP - Speex)](#v7-protocol-tcp---speex)
5. [Command String Protocol](#command-string-protocol)
6. [Radio Control Commands](#radio-control-commands)
7. [Peripheral Device Commands](#peripheral-device-commands)
8. [Chat & Admin Commands](#chat--admin-commands)
9. [Audio/VoIP Subsystem](#audiovoip-subsystem)
10. [RemoteHams.com Web API](#remotehamscom-web-api)
11. [Connection Sequence Diagram](#connection-sequence-diagram)

---

## 1. Architecture Overview

The RCForb system has three layers:

```
RemoteHams.com Web API (HTTPS)    - Authentication, lobby/directory, publishing
     |
IpEx NAT Traversal Server         - ipex.remotehams.com:7005 (TCP, text-based)
     |
RCForb Server (Remote Station)    - Direct UDP/TCP connection to radio server
```

### Two Protocol Versions

| Version | Transport | Audio Codec | Default Port | Command Port |
|---------|-----------|-------------|-------------|-------------|
| V10 (current) | UDP | Opus (48kHz/24kbps) | 4525 | Same socket (multiplexed) |
| V7 (legacy) | TCP | Speex (narrowband) | 4525 (cmd) + 4524 (audio) | Separate sockets |

### Key Constants (Protocol.cs)

```
MAX_BUFFER_SIZE    = 8192
HEARTBEAT_TIMEOUT  = 15.0 seconds
HEARTBEAT_SENDOUT  = 4.0 seconds
SYNCMARKER         = [0x01, 0x02, 0x00, 0x03]
```

### Control Byte Dictionary

| Byte | Constant | Meaning |
|------|----------|---------|
| 0x00 | HEARTBEAT | Keep-alive ping |
| 0x03 | PTT | Push-to-talk ON (enables mic TX) |
| 0x05 | PINGPONG | Round-trip latency measurement |
| 0x06 | PTT_OFF | Push-to-talk OFF (disables mic TX) |
| 0xFB | KEY_OFF | CW key released |
| 0xFC | KEY_ON | CW key pressed |
| 0xFD | USERIN | Client connect/announce |
| 0xFE | USEROUT | Client disconnect |
| 0xFF | UTF8STRING | Command string follows (text payload) |

---

## 2. Authentication Flow

### Step 1: Web API Login Verification

Before connecting to any remote station, the client validates credentials against RemoteHams.com:

```
POST https://api.remotehams.com/v2/login.php
Content-Type: application/x-www-form-urlencoded

Parameters:
  user   = <username, URL-encoded>
  pass   = MD5(MD5(<password>))     # double MD5 hash
  valid  = MD5(URLEncode(username) + MD5(MD5(password)))   # validation token
  getkey = true                      # optional, to retrieve API key

Response: "Valid" on success, error message on failure
```

**Password hashing**: The password is MD5-hashed, then the MD5 hash itself is MD5-hashed again before sending. The `valid` field is a HMAC-like integrity check: `MD5(URLEncode(user) + pass_double_hashed)`.

### Step 2: Server Connection Login

After establishing a UDP/TCP connection, send login via command string:

```
login <username> <md5_password>
```

This is sent as a command string (0xFF prefix for UDP, newline-terminated for V7 TCP).

### Step 3: Protocol Selection

Immediately after login, the client requests the RCS protocol:

```
set protocol rcs
```

This switches the server to "Remote Control System" mode which enables the full radio control command set.

---

## 3. V10 Protocol (UDP - Opus)

### Connection Sequence

1. Create UDP socket, connect to `host:4525`
2. Send `USERIN` (0xFD) three times with 10ms delays
3. Wait for data flow (up to 5 seconds)
4. If direct fails, attempt IpEx NAT hole-punch via `ipex.remotehams.com:7005`
5. If hole-punch fails, attempt relay/proxy
6. On success, send login command string

### Packet Format (UDP)

Each UDP datagram is self-contained. The first byte determines the packet type:

```
[0xFF] [UTF-8 payload bytes...]     -> Command string
[0xFD]                               -> USERIN (connect)
[0xFE]                               -> USEROUT (disconnect)
[0x00]                               -> Heartbeat
[0x05]                               -> Ping/Pong
[0x03]                               -> PTT ON
[0x06]                               -> PTT OFF
[0xFC]                               -> CW Key ON
[0xFB]                               -> CW Key OFF
[any other byte, length > 1]         -> Audio data (Opus encoded)
```

**Dispatch logic**: If `byte[0] != 0xFF` AND `length > CONTROL_CMD_SIZE(1)`, it's audio data. Otherwise it's a control command dispatched by `byte[0]`.

### Sending Command Strings (UDP)

```swift
// Pseudocode
func sendCommandString(_ text: String) {
    let payload = text.utf8
    var packet = [UInt8](repeating: 0, count: payload.count + 1)
    packet[0] = 0xFF
    payload.copyBytes(to: &packet[1...])
    udpSocket.send(packet)
}
```

### Heartbeat / Keep-alive (UDP)

- Every **4 seconds**: Send `HEARTBEAT` (0x00)
- Every **1 second**: Send `PINGPONG` (0x05) for latency measurement
- If no data received for **15 seconds**: Connection is dead, disconnect

---

## 4. V7 Protocol (TCP - Speex)

Uses **two separate TCP connections**:

### Command Channel (port 4525)

- Newline-terminated text strings
- Login: `login <user> <md5pass>\n`
- Commands: `<command string>\n`
- First command after connect: `get id`
- Heartbeat every 4s: `post::heartbeat::<DateTime.Ticks>\n`
- Also sends: `post::check::cantune\n` with each heartbeat

### Audio Channel (port 4524)

Binary framing with 10-byte header:

```
Bytes 0-3: int32 LE  = payload length
Byte  4:   uint8     = packet type (0=null, 1=control, 2=audio/data, 54=sessionID)
Bytes 5-9: padding   = 0x00
Bytes 10+: payload data
```

#### Audio Packet Types

| Length Value | Type | Description |
|-------------|------|-------------|
| 54 | SessionID | Authentication: `"username,md5password"` (max 54 chars) |
| 1-18 | ControlData | PTT state changes (byte[4]==2 means PTT on) |
| 19-2047 | AudioData | Speex-encoded audio frames |
| 0 | NullData | Empty/keepalive |

#### Session ID Packet (V7 Audio Auth)

```
Bytes 0-3:  int32 LE = 54 (magic marker for session ID)
Bytes 4-7:  int32 LE = actual string length
Bytes 8-61: ASCII string "username,md5password" (padded to 54 bytes)
```

#### Keep-alive (V7 Audio)

Send every 2 seconds: `SendDataPacket("IMA")` formatted as:
```
Bytes 0-3: int32 LE = 3 (length of "IMA")
Byte  4:   2 (data type)
Bytes 5-9: 0x00
Bytes 10-12: "IMA"
```

---

## 5. Command String Protocol

All radio/device/chat commands use `::` as a delimiter. The general format is:

```
<namespace>::<action>::<key>::<value>
```

### Namespaces

| Prefix | Purpose |
|--------|---------|
| `radio::` | Radio control (frequency, buttons, dropdowns, sliders) |
| `rotator::` | Antenna rotator control |
| `amp::` | Amplifier control |
| `switch::` / `relay::` | Antenna switch/relay control |
| `tuner::` | Antenna tuner control |
| `meter::` | External meter control |
| `post::` | Server messages, chat, admin, heartbeat |
| `chat::` | Incoming chat messages |
| `login ` | Authentication (space-separated, not `::`) |
| `get ` | Query commands (space-separated) |
| `set ` | Configuration commands |
| `cw::` | CW element data |
| `keyon::` / `keyoff::` | CW key timing |
| `str::` | Raw string to radio |
| `k3term::` | Elecraft K3 terminal commands |
| `mem::` | Memory data |
| `log::` | Log entries |

---

## 6. Radio Control Commands

### Client -> Server (Sending)

| Command | Example | Description |
|---------|---------|-------------|
| Set frequency A | `radio::frequency::14250000` | Set VFO A frequency in Hz |
| Set frequency B | `radio::frequencyb::14250000` | Set VFO B frequency in Hz |
| Set band | `radio::band::20m` | Change band |
| Set button | `radio::button::MOX::1` | Toggle a button (1=on, 0=off) |
| Set dropdown | `radio::dropdown::Mode::USB` | Set a dropdown selection |
| Set slider | `radio::slider::AF Gain::50` | Set a slider value |
| Set message | `radio::message::CW1::CQ CQ DE W6XXX` | Set a message field |
| Set memory | `radio::memory::<freq>::<freqb>::<mode>::<filter>::<ten>::<tsql>::<den>::<dcs>::<shift>::<offset>` | Recall memory |
| Raw CAT command | `str::<raw_data>` | Send raw string to radio |
| Request state | `radio::request-state` | Request full radio state dump |

### Server -> Client (Receiving)

| Response | Example | Description |
|----------|---------|-------------|
| Radio name | `radio::radio::IC-7300` | Radio model name |
| Driver info | `radio::driver::IC-7300 (2.1)` | Driver name and version |
| Frequency A | `radio::frequency::14250000` | Current VFO A frequency |
| Frequency B | `radio::frequencyB::14250000` | Current VFO B frequency |
| S-Meter | `radio::smeter::5` | S-meter reading |
| Button state | `radio::button::MOX::1` | Button name and state |
| Dropdown state | `radio::dropdown::Mode::USB` | Dropdown name and value |
| Dropdown list | `radio::list::Mode::AM,CW,CWR,FM,LSB,USB` | Available options for dropdown |
| Slider state | `radio::slider::AF Gain::50` | Slider name and value |
| Slider range | `radio::range::AF Gain::0,100,1` | Slider min,max,step |
| Message | `radio::message::CW1::CQ CQ` | Message field value |
| Meter | `radio::meter::power::25,100,W` | Meter value,max,unit |
| Status | `radio::status::TX::0` | Status indicator |
| Info | `radio::info::Welcome message` | Informational text |
| State ready | `radio::state-posted` | Full state has been sent |
| Virtual data | `radio::vt::<data>` | Virtual terminal data |
| Raw data | `radio::raw::<data>` | Raw CAT response |

---

## 7. Peripheral Device Commands

### Rotator

**Client -> Server:**
```
rotator::bearing::180         # Set target bearing
rotator::elevation::45        # Set target elevation
rotator::start                # Start rotation
rotator::stop                 # Stop rotation
rotator::button::<name>       # Press a rotator button
```

**Server -> Client:**
```
rotator::enabled              # Rotator is available
rotator::name::Yaesu G-800   # Rotator model
rotator::bearing::180         # Current bearing
rotator::elevation::45        # Current elevation
rotator::started              # Rotation in progress
rotator::stopped              # Rotation complete
rotator::button::<name>::<val># Button state update
```

### Amplifier

**Client -> Server:**
```
amp::button::<name>::<value>
amp::dropdown::<name>::<value>
amp::slider::<name>::<value>
```

**Server -> Client:**
```
amp::enabled                           # Amp is available
amp::name::Expert 1.3K-FA             # Amp model
amp::buttons::<comma-separated list>   # Available buttons
amp::dropdowns::<comma-separated list> # Available dropdowns
amp::meters::<comma-separated list>    # Available meters
amp::sliders::<comma-separated list>   # Available sliders
amp::messages::<comma-separated list>  # Available message fields
amp::statuses::<comma-separated list>  # Available status fields
amp::button::<name>::<value>           # Button state
amp::dropdown::<name>::<value>         # Dropdown state
amp::list::<name>::<csv_options>       # Dropdown options
amp::meter::<name>::<value>            # Meter reading
amp::range::<name>::<min,max,step>     # Slider range
amp::slider::<name>::<value>           # Slider state
amp::message::<name>::<text>           # Message text
amp::status::<name>::<value>           # Status value
amp::frequency::<freq>                 # Amp frequency tracking
```

### Antenna Switch / Relay

**Client -> Server:**
```
switch::button::<name>::<value>
```

**Server -> Client:**
```
switch::enabled
switch::name::<name>
switch::buttons::<comma-separated list>
switch::button::<name>::<value>
```

### Tuner

**Client -> Server:**
```
tuner::button::<name>::<value>
tuner::dropdown::<name>::<value>
```

---

## 8. Chat & Admin Commands

### Chat

```
post::chat::Hello everyone!           # Send chat message
post::chat::/pm <user> <message>       # Private message
post::chat::/a <message>               # Message to admins only
post::chat::/m <message>               # Message to members only
post::chat::/c <message>               # Message to club members
```

### Server Messages (Received)

```
post::info::<message>                  # Info popup
post::auth::<message>                  # Auth failure message
post::error::<message>                 # Error popup
post::warning::<message>               # Warning popup
server::auth::<message>                # Server auth message
post::id::<server_id>                  # Server identification
post::version::<version>               # Server software version
post::heartbeat::<uptime>              # Server heartbeat/uptime
post::time::<server_time>              # Server clock
post::tot::<timeout_info>              # Time-on-transmit info
post::alpha::<text>                    # Alphanumeric display text
post::lasttuner::<callsign>            # Last user who tuned
post::radio-open::<info>               # Radio is available
post::radio-in-use::<info>             # Radio is in use
post::radio-closed::<info>             # Radio is offline
post::transition::<data>               # State transition marker
```

### Admin Commands

```
post::chat::/tune                      # Request tune control
post::chat::/free                      # Release tune control
post::chat::/savemem <data>            # Save memory
post::chat::/clearmem                  # Clear memories
post::chat::/clear                     # Clear chat
post::chat::/disable                   # Disable radio
post::chat::/enable                    # Enable radio
post::chat::/approvetx <user>          # Approve TX for user
post::chat::/denytx <user>             # Deny TX for user
post::chat::/approveclub <user>        # Approve club membership
post::chat::/denyclub <user>           # Deny club membership
post::chat::/banuser <user>            # Ban user
post::chat::/unbanuser <user>          # Unban user
post::chat::/dcuser <user>             # Disconnect user
post::chat::/restart                   # Restart server
post::chat::/poke <user>               # Poke/notify user
post::chat::/open                      # Open remote
```

### Permission Requests

```
post::request-tx                       # Request TX permission
post::request-club                     # Request club access
post::request-amp                      # Request amp control
post::request-rotator                  # Request rotator control
post::request-switch                   # Request switch control
post::request-tuner                    # Request tuner control
```

### Query Commands

```
get id                                 # Get server ID
get version                            # Get server version
get help                               # Get help text
get memories 0 200                     # Get memories (offset, count)
get logs                               # Get activity logs
get dxspots                            # Get DX cluster spots
ping                                   # Ping server
post::activate::slot<N>                # Activate reservation slot
post::get::slots                       # Get available slots
post::check::cantune                   # Check if can tune
post::verify::cantune                  # Verify tune permission
```

---

## 9. Audio/VoIP Subsystem

### V10 (Opus)

| Parameter | Value |
|-----------|-------|
| Codec | Opus |
| Sample Rate | 48000 Hz |
| Channels | 1 (mono) |
| Bit Depth | 16-bit PCM (before encoding) |
| Bitrate | 24000 bps |
| Frame Size | Determined by `OpusEncoder.FrameByteCount()` |

**Encoding**: PCM 16-bit samples -> Opus encoder -> raw Opus frames sent as UDP datagrams.

**IMPORTANT**: Encoded Opus frames have `byte[0]` in range 0x08-0xFA. The protocol uses this to distinguish audio from control bytes (control bytes are 0x00-0x07 and 0xFB-0xFF).

**Decoding**: Received UDP datagrams (where `byte[0] != 0xFF` and `length > 1`) -> Opus decoder -> PCM 16-bit samples -> playback buffer.

**Playback buffer management**:
- Buffer duration: 10 seconds max
- Discard on overflow: true
- Max desired latency: 300ms (configurable)
- Playback pauses when buffer empties, resumes when > MaxDesiredVoipLatency
- Buffer thinning: when buffer exceeds max latency, drop every ~12th packet

### V7 (Speex)

| Parameter | Value |
|-----------|-------|
| Codec | Speex (Narrowband) |
| Transport | TCP with binary framing (10-byte header) |
| Port | 4524 (separate from command port 4525) |

### Microphone / TX Audio

- Mic data is only encoded and sent when `RaiseMicrophoneDataEvents` is true (set by PTT byte 0x03)
- VOX detection: configurable gain threshold (0.15 default), 0.8s release delay
- Mic boost: software gain up to 2x for levels > 100%
- Low-latency mode: 40ms buffer, 2 buffers; Normal: 100ms, 3 buffers

### CW Sidetone

- Sine wave oscillator with configurable pitch (default 540 Hz)
- WPM: configurable (default 24, minimum 8)
- Iambic paddle modes A and B supported
- Volume muting during CW to prevent feedback

---

## 10. RemoteHams.com Web API

### Login / Validate

```
POST https://api.remotehams.com/v2/login.php

user=<username>&pass=<MD5(MD5(password))>&valid=<MD5(URLEncode(user)+MD5(MD5(pass)))>
```

### Track User Online

```
POST https://api.remotehams.com/v2/login.php

user=<username>&pass=<MD5(MD5(password))>&varMe=valYou&logonline=true&valid=<MD5(URLEncode(user+MD5(MD5(pass))))>&orbid=<station_id>
```

### Publish Station

```
POST https://api.remotehams.com/v2/publish.php

name, city, state, country, description, gridsquare, radioport, radio, version,
audiotype, audiodomain, audioport, audioalias, audioskype, audiourl, audiourltitle,
publish, requirelogin, apikey, valid=MD5(name+radioport+apikey),
noguests, slots, domain, rcfurl, shorturl, useproxy, proxyhost, proxyport,
voip, voipport, txenabled, clubmode, orbid
```

---

## 11. Connection Sequence Diagram

```
Client                          RemoteHams.com API            RCForb Server
  |                                    |                           |
  |--- POST /v2/login.php ----------->|                           |
  |<-- "Valid" -----------------------|                           |
  |                                    |                           |
  |--- UDP connect to host:4525 ------------------------------>|
  |--- [0xFD] USERIN (x3) ----------------------------------->|
  |<-- [any data] (data flow starts) --------------------------|
  |                                    |                           |
  |--- [0xFF] "login user md5pass" --------------------------->|
  |--- [0xFF] "set protocol rcs" ----------------------------->|
  |--- [0xFF] "radio::request-state" ------------------------->|
  |                                    |                           |
  |<-- [0xFF] "post::id::StationName" -------------------------|
  |<-- [0xFF] "post::version::10.0" ---------------------------|
  |<-- [0xFF] "radio::radio::IC-7300" -------------------------|
  |<-- [0xFF] "radio::frequency::14250000" --------------------|
  |<-- [0xFF] "radio::button::MOX::0" -------------------------|
  |<-- [0xFF] "radio::dropdown::Mode::USB" --------------------|
  |<-- [0xFF] "radio::list::Mode::AM,CW,..." ------------------|
  |<-- [0xFF] "radio::slider::AF Gain::50" --------------------|
  |<-- [0xFF] "radio::range::AF Gain::0,100,1" ----------------|
  |<-- [0xFF] "radio::smeter::3" ------------------------------|
  |<-- [0xFF] "radio::state-posted" ---------------------------|
  |<-- [0xFF] "rotator::enabled" ------------------------------|
  |<-- [0xFF] "amp::enabled" ----------------------------------|
  |                                    |                           |
  |--- [0x00] Heartbeat (every 4s) --------------------------->|
  |--- [0x05] Ping (every 1s) -------------------------------->|
  |<-- [0x05] Pong --------------------------------------------|
  |                                    |                           |
  |<-- [Opus audio frames] ------------------------------------|  (RX audio)
  |--- [Opus audio frames] ----------------------------------->|  (TX audio, when PTT)
  |                                    |                           |
  |--- [0xFF] "radio::frequency::7125000" -------------------->|  (tune radio)
  |<-- [0xFF] "radio::frequency::7125000" ---------------------|  (confirmation)
  |                                    |                           |
  |--- [0xFE] USEROUT ---------------------------------------->|  (disconnect)
```

---

## IpEx NAT Traversal (ipex.remotehams.com:7005)

Text-based TCP protocol, newline-terminated:

**Server Registration:**
```
ServerRegisterRequest,<port>\n
```

**Client Hole Punch Request:**
```
ClientConnectRequest,<server_endpoint>,<client_port>\n
```

**Responses:**
```
ClientConnectRequest,GO,<endpoint>\n     -> Hole punch target
ClientConnectRequest,OK\n                -> Success
ClientConnectRequest,FAIL\n              -> Failure
ClientProxyRequest,<server_endpoint>\n   -> Relay request
ClientProxyRequest,OK\n                  -> Relay ready
ServerNotFound\n                         -> Server not in directory
```

**Heartbeat:** Send `<DateTime.Ticks>\n` every 4 seconds.

---

## Notes for Swift/macOS Implementation

1. **Audio**: Use CoreAudio/AVAudioEngine instead of NAudio. Opus via `libopus` (available via Homebrew/SPM).
2. **Networking**: Use NWConnection (Network.framework) for both UDP and TCP.
3. **The 0xFF boundary**: Critical - byte 0x08-0xFA = audio data. 0x00-0x07 and 0xFB-0xFF = control. This is how the protocol multiplexes audio and commands on a single UDP socket.
4. **Password**: Always MD5 hash, then MD5 the hash again for the web API. For server login, single MD5 is sent.
5. **V7 compatibility**: The V7 TCP protocol translates `radio::` prefixes to `post::` and `radio::raw::` to `k3term::` on send. Your client can focus on V10/UDP first.
6. **State management**: The server sends a full state dump after `set protocol rcs` / `radio::request-state`. Parse all `radio::*`, `rotator::*`, `amp::*`, `switch::*` messages to build the UI state.
7. **Thread model**: Original uses 2-3 threads (receive, command string dispatch, UI). In Swift, use async/await with actors.
