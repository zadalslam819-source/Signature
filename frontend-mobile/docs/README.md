# OpenVine Mobile App

Flutter-based mobile application for capturing and sharing vine-like videos on the Nostr protocol with Cloudflare Stream integration.

## Features
- Camera integration for capturing short video sequences
- Cloudflare Stream video hosting and CDN delivery
- Nostr protocol integration for decentralized sharing
- Cross-platform support (iOS, Android, Web, macOS)
- Direct video upload bypassing legacy backend

## Getting Started

### Prerequisites
- Flutter SDK (latest stable version)
- Dart SDK
- Android Studio / Xcode for platform-specific development

### Development Setup

**IMPORTANT**: For video uploads to work, you must include the CF_STREAM_TOKEN in development:

#### Option 1: Use the development script (recommended)
```bash
cd mobile
flutter pub get
./run_dev.sh                    # Run on Chrome in debug mode
./run_dev.sh chrome release     # Run on Chrome in release mode
./run_dev.sh ios debug          # Run on iOS simulator
```

#### Option 2: Manual flutter run with token
```bash
cd mobile
flutter pub get
flutter run -d chrome --release --dart-define=CF_STREAM_TOKEN="uJDzTLyLMd8dgUfmH65jkOwD-jeFYNog3MvVQsNW"
```

### Production Builds

All production build scripts automatically include the CF_STREAM_TOKEN:

```bash
./build_native.sh ios release   # iOS App Store build
./build_testflight.sh           # TestFlight build
./build_web_optimized.sh        # Web deployment build
./build_macos.sh release        # macOS App Store build
```

## Architecture
- **lib/screens/**: UI screens and pages
- **lib/services/**: Business logic and API services
- **lib/models/**: Data models and structures
- **lib/utils/**: Utility functions and helpers
- **lib/widgets/**: Reusable UI components
- **lib/config/**: App configuration including CF_STREAM_TOKEN

## Video Upload Architecture

OpenVine uses **Cloudflare Stream** for video hosting:

```
Flutter App → CloudflareStreamService → CF Stream API → CDN → Nostr Event
```

**Key Components:**
- `CloudflareStreamService`: Handles direct uploads to CF Stream
- `UploadManager`: Manages upload lifecycle and error handling
- `VideoEventPublisher`: Creates NIP-32222 compliant Nostr events
- `AppConfig`: Centralizes CF_STREAM_TOKEN configuration

**Legacy systems (deprecated):**
- `DirectUploadService`: Old api.openvine.co backend (deprecated)
- `BlossomUploadService`: Blossom server uploads (deprecated)

## Environment Configuration

The app requires `CF_STREAM_TOKEN` for video uploads. This token is:
- Configured in `lib/config/app_config.dart`
- Automatically included in all production builds
- Must be manually provided for development via `./run_dev.sh` or `--dart-define`

## Testing

```bash
flutter test                    # Run unit tests
flutter analyze                 # Static analysis
```

For upload testing, ensure CF_STREAM_TOKEN is configured as described above.