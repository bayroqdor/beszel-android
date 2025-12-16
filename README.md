# Beszel Mobile

> **A beautiful, real-time mobile companion for your [Beszel](https://github.com/henrygd/beszel) server monitoring hub.**

![Flutter](https://img.shields.io/badge/Flutter-%2302569B.svg?style=for-the-badge&logo=Flutter&logoColor=white)
![Dart](https://img.shields.io/badge/dart-%230175C2.svg?style=for-the-badge&logo=dart&logoColor=white)
![PocketBase](https://img.shields.io/badge/PocketBase-%23B8DBE4.svg?style=for-the-badge&logo=PocketBase&logoColor=black)
![Android](https://img.shields.io/badge/Android-3DDC84?style=for-the-badge&logo=android&logoColor=white)

Beszel Mobile brings your server metrics to your pocket. Connect to your existing Beszel instance to monitor CPU, RAM, Disk, and Network usage in real-time, receive local alerts for downtime, and view historical data with beautiful, interactive charts.

---

## Features

- **Real-Time Dashboard**
  - Live updates of all your connected systems.
  - At-a-glance status indicators (UP/DOWN).
  - Current CPU, Memory, and Disk usage percentages.

- **Detailed Analytics**
  - Interactive historical charts for **CPU**, **Memory**, **Disk**, and **Network Traffic**.
  - Precise tooltip data on touch.
  - Dynamic X-axis (Time) and Y-axis (Usage/Bandwidth) scaling.

- **Smart Alerts System**
  - **Local Push Notifications**: Get notified instantly on your device if a server goes down or resource usage spikes (>90%).
  - **Alert History**: Persistent log of all past critical events.
  - **Background Monitoring**: (Active when app is running).

- **Localization & Theming**
  - **Multi-language Support**: Fully localized in **English** 🇺🇸 and **Russian** 🇷🇺.
  - **Dark/Light Mode**: Seamlessly switches based on your system preference or manual toggle.

---

## Installation

### Prerequisites
- [Flutter SDK](https://flutter.dev/docs/get-started/install) installed on your machine.
- A running instance of **[Beszel](https://github.com/henrygd/beszel)** (the backend).

### Steps
1.  **Clone the repository**:
    ```bash
    git clone https://github.com/yourusername/beszel-mobile.git
    cd beszel-mobile
    ```

2.  **Install dependencies**:
    ```bash
    flutter pub get
    ```

3.  **Run the app**:
    ```bash
    # For Android
    flutter run -d android
---

## Configuration

1.  **Open the App**: You will be greeted by the Setup Screen.
2.  **Enter Server URL**: Input the full URL of your Beszel instance (e.g., `https://beszel.yourdomain.com`).
3.  **Login**: Use your existing Beszel credentials (Email/Username & Password).
4.  **Enjoy**: Your dashboard will automatically populate with your systems.

---

## Tech Stack

- **Framework**: [Flutter](https://flutter.dev/)
- **Backend SDK**: `pocketbase` (Dart client)
- **Charting**: `fl_chart`
- **State Management**: `provider`
- **Localization**: `easy_localization`
- **Charts**: `fl_chart`
- **Notifications**: `flutter_local_notifications`

---

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1.  Fork the project
2.  Create your Feature Branch (`git checkout -b feature/AmazingFeature`)
3.  Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4.  Push to the Branch (`git push origin feature/AmazingFeature`)
5.  Open a Pull Request

