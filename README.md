# ESP32 Phone Server

A Flutter mobile application that acts as a **local HTTP server** and receives
text messages from an ESP32 device over the same WiFi network.

---

## How to Run the Project

### Prerequisites
- Flutter SDK ≥ 3.5.0 installed and on your PATH
- An Android or iOS device (or emulator) on the same WiFi as your ESP32
- USB debugging enabled (Android) or a provisioned simulator (iOS)

### Steps

```bash
# 1. Navigate into the project folder
cd esp32_phone_server

# 2. Fetch dependencies
flutter pub get

# 3. Run on a connected device
flutter run
```

> **Tip:** Use a real device rather than an emulator when testing with actual
> ESP32 hardware. Emulators run behind a virtual NAT and may not be reachable
> from the LAN.

---

## Project Architecture

```
lib/
├── main.dart                     # App entry point, navigation shell
├── screens/
│   ├── dashboard_screen.dart     # Main screen — server controls + message log
│   └── wifi_config_screen.dart   # WiFi credential reference screen
├── services/
│   ├── http_server_service.dart  # dart:io HttpServer wrapper
│   └── network_service.dart      # Local IP address fetcher
├── models/
│   └── message_model.dart        # Data class for a received message
└── widgets/
    └── status_card.dart          # Reusable server-status indicator card
```

### Layer responsibilities

| Layer | What it does |
|---|---|
| `models/` | Pure Dart data classes, no Flutter dependencies |
| `services/` | I/O operations (networking, server) isolated from UI |
| `screens/` | Stateful widgets that own UI state via `setState` |
| `widgets/` | Stateless, reusable UI building blocks |

---

## API Endpoint

| Detail | Value |
|---|---|
| Method | `POST` |
| Path | `/send-text` |
| Port | `3000` |
| Content-Type | `text/plain` |
| Success response | `200 OK` with body `OK` |
| Empty body | `400 Bad Request` |
| Unknown path | `404 Not Found` |

### Example cURL command (for testing from a laptop on the same WiFi)

```bash
curl -X POST http://<PHONE_IP>:3000/send-text \
     -H "Content-Type: text/plain" \
     -d "Hello from cURL!"
```

Replace `<PHONE_IP>` with the IP shown on the Dashboard screen.

### Arduino / ESP32 sketch snippet

```cpp
#include <HTTPClient.h>

HTTPClient http;
http.begin("http://192.168.1.X:3000/send-text"); // use your phone's IP
http.addHeader("Content-Type", "text/plain");
int httpCode = http.POST("Sensor value: 42");
http.end();
```

---

## Testing Instructions

### Without ESP32 Hardware

1. Launch the app and go to the **Dashboard** tab.
2. Tap **Start Server** — the status indicator turns green.
3. Tap **Simulate ESP32 Message** — a dummy message appears immediately
   in both "Last Received Message" and the log.

### With a Laptop / PC (same WiFi)

1. Note the Phone IP shown in Network Info.
2. Run the cURL command above from your terminal.
3. The message should appear in the app within milliseconds.

### With Real ESP32

1. Flash your ESP32 with a sketch that uses `HTTPClient` (Arduino framework).
2. Set `ssid`, `password`, and the phone IP in the sketch.
3. Power the ESP32 — it will POST to the app automatically.

---

## Known Limitations

- The server stops when the app is moved to the background on some Android
  versions (battery optimisation). Keep the screen on during testing.
- iOS requires the app to be in the foreground for the server to accept
  connections.
- Port 3000 must not be blocked by a firewall on the phone. If it is, change
  the `port` constant in `http_server_service.dart`.
