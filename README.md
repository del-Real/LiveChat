# LiveChat: Real-Time Typing Messenger 

LiveChat is a real-time communication application designed to showcase immediate, character-by-character message visibility. 
Unlike traditional chat applications where messages only appear after hitting 'Send,' LiveChat displays the **live draft** of the message as it is being typed by any participant in the room.

This core feature provides a highly fluid and collaborative feel, similar to seeing live edits in tools like Google Docs or Word Online.

---

## Project Setup and Run

This repository contains two main parts:

* **client_side/** – Flutter mobile application
* **server-side/** – Node.js + Express + MongoDB backend

Below are the steps required to install dependencies and run the project locally.

### Prerequisites

Make sure the following are installed on your system:

* Flutter SDK
* Node.js
* Android Studio (for Android development)
* Xcode (for iOS development)

Verify installations:

```bash
flutter --version
node --version
npm --version
```

---

## Running the Flutter App (Android)

These steps describe how to run the Flutter app targeting an **Android Emulator** or a physical Android device.

### 1. Install Android Studio

Download and install [Android Studio](https://developer.android.com/studio)

During installation, ensure the following components are installed:

* Android SDK
* Android SDK Platform-Tools
* Android SDK Command-line Tools
* Android Emulator

### 2. Install Android SDK and Emulator

1. Open **Android Studio**
2. Go to **Settings / Preferences → Android SDK**
3. Under **SDK Platforms**, install at least one recent Android version (API 33+ recommended)
4. Under **SDK Tools**, ensure the following are checked:

   * Android SDK Command-line Tools (latest)
   * Android SDK Platform-Tools
   * Android SDK Build-Tools

Apply and close settings.

### 3. Accept Android SDK Licenses

Run:

```bash
flutter doctor --android-licenses
```

Accept all licenses when prompted.

### 4. Verify Flutter Android Setup

```bash
flutter doctor
```

Ensure **Android toolchain** shows no critical errors.

### 5. Start an Android Emulator

From Android Studio:

1. Open **Device Manager**
2. Create a new virtual device (Pixel recommended)
3. Start the emulator

Alternatively, start an existing emulator:

```bash
flutter emulators
flutter emulators --launch <emulator_id>
```

### 6. Install Flutter Dependencies

From the Flutter project root:

```bash
cd client_side
flutter pub get
```

### 7. Verify Android Device Availability

```bash
flutter devices
```

Ensure an **Android Emulator** or physical Android device is listed.

### 8. Run the Flutter App

```bash
flutter run
```

Flutter will build and launch the app on the Android emulator or connected device.

---

## Running the Flutter App (iOS)

These steps describe how to run the Flutter app targeting **iOS Simulator**.

### 1. Install Flutter

Install Flutter without targeting any specific platform initially. Ensure Flutter works on your machine:

```bash
flutter doctor
```

Fix any critical issues reported before continuing.

### 2. Install CocoaPods

CocoaPods is required for iOS Flutter plugins:

```bash
sudo gem install cocoapods
pod setup
```

Verify installation:

```bash
pod --version
```

### 3. Install iOS SDK via Xcode

1. Open **Xcode**
2. If prompted, install required iOS SDK components
3. Accept the Xcode license if asked

```bash
sudo xcodebuild -license accept
```

### 4. Open the iOS Simulator

```bash
open -a Simulator
```

### 5. Install Flutter Dependencies

From the Flutter project root:

```bash
cd client_side
flutter pub get
```

### 6. Verify iOS Device Availability

```bash
flutter devices
```

Ensure an **iOS Simulator** is listed.

### 7. Run the Flutter App

```bash
flutter run
```

Flutter will automatically build and launch the app on the simulator.

---

## Running the Backend Server

The backend is a **Node.js + Express** server connected to **MongoDB**.

### 1. Navigate to the server directory

```bash
cd server-side
```

### 2. Install server dependencies

```bash
npm install
```

### 3. Create a `.env` file

In the `server-side` directory, create a `.env` file:

```bash
touch .env
```

Add the MongoDB connection string:

```env
MONGO_URI=mongodb+srv://<username>:<password>@<cluster>.mongodb.net/<dbname>
```

### 4. Start the server

Run the server **from the `server-side` directory**:

```bash
npm run dev
```

If configured correctly, the server will connect to MongoDB and start listening for requests.
