# Smart Door Lock System

A smart door lock system using IoT technology powered by Flutter, Firebase, and an ESP32 microcontroller with RFID integration.

## Features

- 🔐 App-based unlocking (Flutter + Firebase)
- 🪪 RFID card access
- 📋 Realtime activity logs (unlock events, methods)
- ⚙️ Admin control (PIN updates, log clearance)
- 📡 Firebase Realtime Database sync
- 💡 Clean, secure mobile UI

## Getting Started

To run this project:

1. **Flutter setup:**
   - Install Flutter SDK
   - Run `flutter pub get`
   - Add your own `google-services.json` (not included in repo)

2. **ESP32 Firmware:**
   - Code is inside the `arduino/SmartDoorLock` folder
   - Replace credentials in `secret.h`

3. **Firebase Setup:**
   - Enable Email/Password authentication
   - Realtime Database with `/door`, `/logs`, `/users` paths

## Resources

- [Flutter Documentation](https://docs.flutter.dev/)
- [Firebase for Flutter](https://firebase.flutter.dev/)
- [ESP32 Firebase Client](https://github.com/mobizt/Firebase-ESP-Client)

---

## Notes

- 🚫 Sensitive files like `google-services.json` and `secret.h` are excluded from version control using `.gitignore`.
- 📁 This project is structured for both mobile UI and IoT firmware collaboration.

---

## Author

Christian Coles V. – BSIT - A Capstone 02  
Infotech College of Arts and Sciences – Sucat Branch
