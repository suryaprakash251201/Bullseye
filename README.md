# Bullseye

A comprehensive, professional Flutter mobile application for system administrators that provides essential network, server, and infrastructure monitoring tools — all in one app.

## Features

### Network Tools
- **Ping & Traceroute** — ICMP ping with statistics, charts, and visual route tracing
- **DNS Lookup** — Query A, AAAA, MX, CNAME, TXT, NS, SOA, PTR, SRV records
- **Port Scanner** — Scan common or custom port ranges with batch processing
- **Network Scanner** — Discover devices on local subnet via ping sweep
- **WiFi Analyzer** — Signal strength, channel distribution chart, and network details
- **Bandwidth Monitor** — Real-time upload/download speed tracking with live charts

### Server Tools
- **SSH Client** — Full terminal UI with command history and quick snippets
- **FTP Client** — FTP/FTPS/SFTP file manager with breadcrumb navigation
- **SSL Inspector** — Real certificate inspection using `SecureSocket` with expiry warnings
- **Whois Lookup** — Domain registration info via API with fallback data
- **Website Monitor** — HTTP/Ping/Port monitoring with uptime tracking and response time charts

### Management
- **Dashboard** — Quick stats overview, active monitors, recent connections, quick actions
- **Connection Manager** — Save and organize SSH/FTP/SFTP connections with credential encryption
- **Settings** — Dark/light theme, biometric auth, master password, export/import, auto-lock

## Architecture

```
lib/
├── config/              # App shell, navigation
├── core/
│   ├── constants/       # App-wide constants
│   ├── providers/       # Theme provider
│   ├── services/        # Network, storage, secure storage services
│   ├── themes/          # Material 3 light & dark themes
│   └── utils/           # Formatters
├── features/
│   ├── bandwidth_monitor/
│   ├── connections/     # Connection CRUD with Riverpod provider
│   ├── dashboard/
│   ├── dns_tools/
│   ├── ftp/
│   ├── network_scanner/
│   ├── ping_traceroute/
│   ├── port_checker/
│   ├── settings/
│   ├── ssh/
│   ├── ssl_inspector/
│   ├── website_monitor/ # Provider with timer-based checks
│   ├── whois_lookup/
│   └── wifi_analyzer/
├── shared/
│   ├── models/          # ConnectionProfile, WebsiteMonitor
│   └── widgets/         # StatusBadge, ToolCard, StatCard, etc.
└── main.dart            # Entry point, Hive init, routing
```

## Tech Stack

| Layer | Technology |
|---|---|
| Framework | Flutter 3.x / Dart 3.x |
| State Management | Riverpod 3.x (`Notifier` / `NotifierProvider`) |
| Local Storage | Hive Flutter |
| Secure Storage | Flutter Secure Storage (keychain / encrypted prefs) |
| HTTP Client | Dio |
| Charts | fl_chart |
| Typography | Google Fonts (Inter, Fira Code) |
| Design | Material Design 3, dark mode default |

## Getting Started

### Prerequisites
- Flutter SDK 3.x+
- Dart 3.x+
- Android Studio / Xcode for platform builds

### Setup

```bash
# Clone / navigate to project
cd "Project 4"

# Install dependencies
flutter pub get

# Run on connected device or emulator
flutter run

# Build release APK
flutter build apk --release

# Build release iOS
flutter build ios --release
```

### Permissions

The app requests the following permissions:
- **Internet** — Required for all network tools
- **WiFi State** — WiFi Analyzer feature
- **Location** (Android) — Required by Android for WiFi scanning
- **Biometrics** — Optional app lock

## Color Scheme

| Role | Color |
|---|---|
| Background | `#0A0E21` |
| Primary | `#1565C0` (Blue 800) |
| Secondary | Teal |
| Accent | Orange |
| Success | `#4CAF50` |
| Error | `#EF5350` |

## Routes

| Route | Screen |
|---|---|
| `/` | Main Shell (Dashboard) |
| `/ssh` | SSH Client |
| `/ftp` | FTP Client |
| `/wifi` | WiFi Analyzer |
| `/ping` | Ping & Traceroute |
| `/dns` | DNS Lookup |
| `/port-checker` | Port Scanner |
| `/network-scanner` | Network Scanner |
| `/ssl` | SSL Inspector |
| `/whois` | Whois Lookup |
| `/bandwidth` | Bandwidth Monitor |
| `/add-monitor` | Add Website Monitor |
| `/add-connection` | Add Connection |

## License

This project is proprietary software. All rights reserved.
