# Secure Messenger

A secure, cross-platform chat application built with **Flutter** and powered by **Firebase**. The application features real-time messaging and modern biometric authentication (Face ID & Touch ID) to ensure maximum privacy and security for user conversations.

---

## Features

* **Cross-Platform Architecture:** Fully configured backend infrastructure to support **Android**, **iOS**, and **Web** clients simultaneously.
* **Real-time Messaging:** Fast and secure chat data exchange synced seamlessly via Cloud Firestore streams.
* **Biometric Security Lock:** Instant app protection utilizing native biometric authentication (Face ID / Touch ID / Fingerprint) handled via Apple's Local Authentication and Android's biometric API.
* **Secure Authentication Gate:** Dual-layer security structure requiring email/password login first, followed by mandatory biometric confirmation.

---

## Tech Stack & Architecture

* **Frontend Framework:** Flutter (Dart)
* **Backend & Database:** Firebase Authentication & Cloud Firestore
* **Security Frameworks:** * **iOS:** Local Authentication Framework (configured via `Info.plist`)
    * **Android:** Biometric Prompt API

### System Workflow



1. **Auth Gate:** The app listens to the Firebase Auth Stream. If unauthenticated, it routes to `LoginScreen`.
2. **Biometric Wrapper:** Once logged in via Firebase, the app enters `BiometricCheckWrapper` and immediately triggers the native biometric dialog.
3. **App Access:** Successful verification opens `HomeScreen`. If canceled or failed, the app remains securely locked with a fallback option to retry.

---

## Configuration & Credentials

### Backend Setup (Firebase)
The project is linked to a centralized Firebase console with pre-registered platform profiles for future-proof cross-platform expansion:
* Android App Bundle Configuration
* iOS App Bundle & Bundle Identifier Configuration
* Web App Configuration

### iOS Privacy Configuration (`Info.plist`)
The application explicitly requests Face ID and Touch ID permissions using Apple's recommended Local Authentication guidelines:
```xml
<key>NSFaceIDUsageDescription</key>
<string>This app uses biometric authentication (Face ID / Touch ID) to protect your messages and ensure only you can access them.</string>
```

## Getting Started

### Prerequisites
 - Flutter SDK (Latest stable version)

 - Dart SDK

 - Cocoapods (for iOS deployment)

 - Firebase CLI & FlutterFire configured

## Installation & Run

### Clone the repository:
``` git clone https://01.gritlab.ax/git/mkaru/secure-messenger ```

### Get dependencies:
``` flutter pub get ```

### Run the app:
``` flutter run ```

## Testing Biometrics on Simulators

### iOS Simulator (Face ID)
1. Launch the app on an iOS Simulator.
2. Navigate to the top Mac menu bar: **Features ➔ Face ID** and toggle **Enrolled** on.
3. Trigger the biometric lock in the app, then simulate success via **Features ➔ Face ID ➔ Matching Face**.

### Android Emulator (Fingerprint)
1. Open **Settings ➔ Security ➔ Fingerprint** inside the Android Emulator and set up a backup PIN.
2. Open the emulator's **Extended Controls (...) ➔ Fingerprint** section.
3. Click **Touch Sensor** to register a virtual fingerprint ("Finger 1").
4. Launch the app, wait for the biometric bottom sheet to appear, and click **Touch Sensor** again to unlock.