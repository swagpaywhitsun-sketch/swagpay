# SwagPay 📱💳

> **Enterprise Mobile Money Collection App & Admin POS Terminal Suite**

SwagPay is a cross-platform financial collection application built with **Flutter** (for Android, iOS, and Web) paired with a **Node.js** gateway service. It connects tellers and cashiers directly to **WhitsunPay MoMo Gateway** (`https://developer.whitsun.dev`) for real-time customer USSD push debit prompts and records all ledger operations in **Supabase PostgreSQL**.

---

## 🌟 Key Features

### 1. Teller Mobile App (Android & iOS)
- **Streamlined MoMo Collections:** Enter phone number and amount.
- **Auto-Network Detection:** Automatically identifies **MTN MoMo**, **Telecel Cash**, and **AT Money**.
- **Real-time Account Lookup:** Verifies the subscriber account holder name before sending payment prompts.
- **USSD Push Authorization:** Prompts the customer's phone to enter their MoMo PIN with live status polling.
- **Digital & Thermal Receipts:** Realistic thermal receipt preview with Bluetooth POS printing and copy-to-clipboard support.
- **Collection History:** Search by reference, customer phone, and filter by status.
- **Shift & Register Reconciliation:** Shift tracking, expected vs. actual variance, and end-of-shift reporting.

### 2. Admin POS Terminal Mode (Web & Desktop)
- **Executive Dashboard:** Live KPI cards (Total Collections in GH₵, Success Rate, Active Tellers/POS), 7-day collections velocity chart, and operational alerts.
- **Teller Management:** Real-time user management, counter assignments, and transaction limits.
- **POS Hardware Management:** Terminal whitelisting, serial verification, and remote lock.
- **Transaction Ledger:** Multi-parameter search, network/status filters, and CSV export.
- **Refund & Reversal Approvals:** 1-click admin approval or rejection workflow.
- **Settlement & Audit Trail:** Daily settlement batch verification and immutable audit logs.

---

## 🛠️ Tech Stack

- **Frontend:** Flutter 3.44+ (Dart 3.12+)
- **State Management:** Riverpod 3.x (`NotifierProvider`)
- **Navigation:** `go_router`
- **Charts:** `fl_chart`
- **Backend API:** Node.js, Express, `pg` (PostgreSQL)
- **Database:** Supabase PostgreSQL
- **Gateway:** WhitsunPay MoMo API (`https://developer.whitsun.dev`)
- **Currency:** Ghana Cedis (`GH₵` / `GHS`)

---

## 🚀 Getting Started

### 1. Environment Setup
Copy `.env.example` to `.env` and fill in your credentials:
```bash
cp .env.example .env
```

### 2. Start the Backend Service
```bash
npm install
npm start
```
*API service runs on `http://localhost:5050`.*

### 3. Run the Flutter App
* **Web (Chrome):**
  ```bash
  flutter run -d chrome
  ```
* **macOS Desktop:**
  ```bash
  flutter run -d macos
  ```
* **Android Device:**
  ```bash
  flutter run -d android
  ```
* **iOS Device:**
  ```bash
  flutter run -d ios
  ```

---

## 📦 Building Releases

### Android APK
```bash
flutter build apk --release
```
Output: `build/app/outputs/flutter-apk/app-release.apk` (and `swagpay-pos-release.apk`)

### iOS App
```bash
flutter build ios --release --no-codesign
```
Output: `build/ios/iphoneos/Runner.app` (and `swagpay-pos-ios.ipa`)

### Web Production Bundle
```bash
flutter build web
```
Output: `build/web/`

---

## 🔐 Credentials (Default)

- **Teller Access:** `teller@swagpay.com` / `0550402859` | PIN: **`1234`**
- **Admin POS Access:** `admin@swagpay.com` | Password: **`admin123`**
