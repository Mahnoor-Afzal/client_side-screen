# Smart Legal Assistance - Legal-Ease Android

Smart Legal Assistance (Legal-Ease) is a comprehensive legal management application built with Flutter and Firebase. It provides a seamless platform for lawyers to manage cases, communicate with clients in real-time, and handle legal documentation efficiently.

## 📱 App Visuals (Screenshots)

<p align="center">
  <img src="screenshots/splash.png" width="200" title="Splash Screen">
  <img src="screenshots/login.png" width="200" title="Lawyer Login">
  <img src="screenshots/dashboard.png" width="200" title="Lawyer Dashboard">
</p>
<p align="center">
  <img src="screenshots/chat.png" width="200" title="Real-time Chat">
  <img src="screenshots/vakalatnama.png" width="200" title="Vakalatnama Management">
  <img src="screenshots/hearings.png" width="200" title="Hearing Schedules">
</p>

> **Note:** To see these visuals, create a `screenshots/` folder in your repository and upload your app images (splash.png, login.png, etc.).

## 🚀 Key Features

- **Lawyer Dashboard:** Real-time overview of active cases and pending requests with message previews.
- **Consultation Management:** Separate section for legal advice requests. Accept consultations to enable instant chat.
- **Unified Chat System:** Real-time messaging between lawyers and clients using a unified `chat` collection in Firestore.
- **Vakalatnama Automation:** Generate professional 8-point legal forms with digital handwritten signatures.
- **Hearing Synchronization:** Schedule hearings and automatically sync dates with the client's dashboard and send push notifications.
- **Document Vault:** Securely upload case-related files and download documents signed/uploaded by clients.

## 🛠️ Technologies Used

- **Framework:** [Flutter](https://flutter.dev/)
- **Backend:** [Firebase](https://firebase.google.com/) (Firestore, Authentication, Storage)
- **State Management:** Stream-based real-time updates
- **Packages:** `cloud_firestore`, `firebase_auth`, `firebase_storage`, `signature`, `pdf`, `intl`, `file_picker`.

## 📥 Getting Started

### Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) installed.
- [Firebase Project](https://firebase.google.com/) configured for Android.

### Installation

1. **Clone the repository:**
   ```bash
   git clone https://github.com/labizareen-collab/Legal-Ease-Android.git
   ```
2. **Install dependencies:**
   ```bash
   flutter pub get
   ```
3. **Configure Firebase:**
   Place your `google-services.json` in the `android/app/` directory.
4. **Run the app:**
   ```bash
   flutter run
   ```

## 📄 License

This project is licensed under the MIT License.
