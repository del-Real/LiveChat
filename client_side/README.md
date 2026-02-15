# LiveChat Mobile Client

A modern, high-performance messaging client built with Flutter.

## 🚀 Features
- **Real-time Messaging**: Powered by Socket.IO for duplex communication.
- **Rich Media**: Integrated image sharing via secure upload channels.
- **Social Connectivity**: Contact request system and group management.
- **Experience Polish**: 
  - Last Seen indicators
  - Message Pinning
  - Live Typing indicators
  - Dark/Light Mode support

## 🛠 Tech Stack
- **Framework**: Flutter 3.x
- **State Management**: Provider (Reactivity model)
- **Navigation**: GoRouter (Declarative routing)
- **Real-time**: Socket.io Client
- **Storage**: Flutter Secure Storage

## 🏗 Architecture
The app follows a service-oriented architecture:
- `lib/models`: Immutable data structures.
- `lib/services`: Business logic and external API communication.
- `lib/screens`: Declarative UI layouts.
- `lib/helpers`: Shared widgets and utility components.

## 📦 Getting Started
1. Run `flutter pub get`
2. Update `ApiConfig` with your local server IP.
3. Run `flutter run`
