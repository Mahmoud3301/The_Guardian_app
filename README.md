# 🛡️ The Guardian — AI-Powered Home Security System

<p align="center">
  <img src="assets/images/robot.png" alt="The Guardian Logo" width="150"/>
</p>

**The Guardian** is an intelligent home security application that uses **AI and computer vision** to protect your home. It detects people, recognizes faces, and classifies risks — all in real-time.

---

## 🧠 How It Works

The system uses **4 AI models simultaneously** on every camera frame:

| Model | Purpose |
|-------|---------|
| **YOLOv8n** | General object detection (person, car, etc.) |
| **risk.pt** | Weapon/danger detection (gun, knife, etc.) |
| **home_object.pt** | Home object detection (cutter, scissors, etc.) |
| **face_recognition** | Face detection + recognition (known vs unknown) |

### 🔐 Smart Risk Classification

The system uses **owner-based risk assessment**:

- ✅ **SAFE** — If a **known owner** (e.g. Mahmoud) is holding a knife in the kitchen → it's safe, they're cooking
- ⚠️ **RISK** — If an **unknown person** is holding a knife → it's a risk, trigger alert
- 🔴 **DANGER** — Unknown person with a weapon → immediate alert

### 📡 Auto Network Discovery

The app **automatically finds the backend** on the same WiFi network using subnet scanning — no manual IP configuration needed. Just connect both devices to the same network and it works!

---

## 📱 Features

- 🎥 **Live Video** — Real-time camera feed with AI annotations
- 👤 **Face Recognition** — Knows owners vs strangers
- 🔔 **Smart Notifications** — Alerts only when there's a real threat
- 👥 **Owners & Visitors** — Manage known people with real photos
- 🔐 **Authentication** — Email/Password + Google + Apple sign-in
- 📶 **Auto Discovery** — Finds backend on any WiFi automatically
- 🖥️ **Server/Camera Controls** — ON/OFF toggles on home screen

---

## 🏗️ Architecture

```
┌──────────────────────┐        ┌──────────────────────────┐
│    Flutter App        │  WiFi  │    Docker Backend         │
│    (Android/iOS)      │◄──────►│    (Python + FastAPI)     │
│                       │  Auto  │                          │
│  • Live Video Page    │  Scan  │  • YOLOv8n (objects)     │
│  • Notifications      │        │  • risk.pt (weapons)     │
│  • Owners/Visitors    │        │  • home_object.pt (home) │
│  • Google/Apple Auth  │        │  • face_recognition      │
│                       │        │  • mDNS auto-discovery   │
└──────────────────────┘        └──────────────────────────┘
         │                                │
         └──────────┬─────────────────────┘
                    │
            ┌───────▼───────┐
            │   Supabase    │
            │  (Cloud DB)   │
            │  • Face photos│
            │  • Auth       │
            └───────────────┘
```

---

## 🚀 Getting Started

### Prerequisites

- [Flutter SDK](https://flutter.dev/docs/get-started/install) (3.x+)
- [Docker](https://docs.docker.com/get-docker/) & Docker Compose
- Android Studio / Xcode (for mobile builds)

### 1️⃣ Clone the Repository

```bash
git clone https://github.com/Mahmoud3301/The_Guardian_app.git
cd The_Guardian_app/flutter_application_1
```

### 2️⃣ Install Dependencies

```bash
flutter pub get
```

---

## 🖥️ Running the Backend (Required)

The backend server runs the AI models. **Run this on your laptop/PC before opening the app:**

```bash
cd The_Guardian_app/flutter_application_1
docker-compose up --build
```

> **Note:** The app automatically discovers the backend on the same WiFi network. No IP configuration needed!

### Backend Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/ws` | WebSocket | Live video stream processing |
| `/upload` | POST | Single image analysis |
| `/add_face` | POST | Register a new person |
| `/faces` | GET | List known people |
| `/owners` | GET | List registered owners |
| `/health` | GET | Server status check |

---

## 📱 Build for Android (APK)

```bash
# 1. Install dependencies
flutter pub get

# 2. Build release APK
flutter build apk --release

# 3. Find your APK at:
#    build/app/outputs/flutter-apk/app-release.apk
```

### Install on Phone

Transfer the APK to your Android phone and install it, or use:

```bash
# Connect phone via USB and run directly
flutter run --release
```

---

## 🍎 Build for iOS (Requires Mac)

```bash
# 1. Install dependencies
flutter pub get

# 2. Install iOS pods
cd ios && pod install && cd ..

# 3. Open in Xcode (for signing)
open ios/Runner.xcworkspace

# 4. In Xcode:
#    - Select your Team in Signing & Capabilities
#    - Change Bundle Identifier if needed
#    - Select your device

# 5. Build release IPA
flutter build ios --release

# Or run directly on connected iPhone
flutter run --release
```

> **Note:** iOS builds require a Mac with Xcode installed and an Apple Developer account for device deployment.

---

## 🔧 Configuration

### Supabase (Cloud Database)

The app uses Supabase for cloud face storage and authentication. Configuration is in:
- `lib/core/supabase_config.dart`
- `docker-compose.yml` (environment variables)

### Google Sign-In Setup

1. Go to [Google Cloud Console](https://console.cloud.google.com)
2. Create OAuth 2.0 credentials (Web Application)
3. Add redirect URI: `https://ldtqguseonfhkjfxuocl.supabase.co/auth/v1/callback`
4. Enable Google provider in [Supabase Dashboard](https://supabase.com/dashboard) → Authentication → Providers

### Apple Sign-In Setup

1. Requires [Apple Developer Account](https://developer.apple.com) ($99/year)
2. Create Service ID + Key in Apple Developer Portal
3. Enable Apple provider in Supabase Dashboard → Authentication → Providers

---

## 📂 Project Structure

```
flutter_application_1/
├── lib/
│   ├── core/              # App colors, models, configs
│   ├── pages/             # UI pages (Home, Login, Live Video, etc.)
│   ├── services/          # Backend, Auth, Supabase services
│   ├── widgets/           # Shared UI components
│   └── main.dart          # App entry point
├── docker/
│   ├── server.py          # Python backend (FastAPI + AI models)
│   └── Dockerfile         # Docker image config
├── person_photos/         # Known people's face photos
│   ├── mahmoud/
│   ├── mina/
│   └── mohab/
├── models/                # YOLO model files (.pt)
├── assets/images/         # App assets (robot logo, photos)
├── docker-compose.yml     # Backend deployment config
└── pubspec.yaml           # Flutter dependencies
```

---

## 👥 Owners

The system recognizes these people as owners (safe):

| Name | Role |
|------|------|
| Mahmoud | Owner |
| Mina | Owner |
| Mohab | Owner |

New owners can be added by placing their photos in `person_photos/<name>/` directory.

---

## 🔄 How to Use

1. **Start the backend** on your laptop: `docker-compose up`
2. **Connect** your phone to the **same WiFi** as the laptop
3. **Open the app** on your phone
4. The app **auto-discovers** the backend — no setup needed!
5. Go to **Live Video** to start monitoring
6. Receive **smart alerts** when unknown people are detected with objects

---

## 🛠️ Tech Stack

| Component | Technology |
|-----------|-----------|
| Mobile App | Flutter (Dart) |
| Backend | Python, FastAPI, OpenCV |
| AI Models | YOLOv8, face_recognition |
| Cloud | Supabase (Storage + Auth) |
| Container | Docker, Docker Compose |
| Discovery | mDNS / Avahi / Subnet Scan |

---

## 📝 License

This project is developed for educational purposes.

---

<p align="center">
  Made with ❤️ by <strong>Mahmoud, Mina & Mohab</strong>
</p>
