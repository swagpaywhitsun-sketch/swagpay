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

Release builds are signed with the `swagpay-release` keystore. `android/key.properties`
and `android/swagpay-release.jks` are gitignored — **back both of them up offline**. The
keystore password is not recoverable, and Android refuses updates signed by a different
key, so losing it means every installed app must be uninstalled and reinstalled.

`android/app/build.gradle.kts` fails the build when `key.properties` is missing; release
no longer falls back to debug signing.

### Android APK
```bash
flutter build apk --release --obfuscate --split-debug-info=build/symbols-android
```
Output: `build/app/outputs/flutter-apk/app-release.apk`.
Keep `build/symbols-android` — it turns an obfuscated crash log back into a stack trace.

### iOS App
Open `ios/Runner.xcworkspace` once, set the Team and a provisioning profile, then:
```bash
flutter build ipa --release --obfuscate --split-debug-info=build/symbols-ios
```
`flutter build ios --no-codesign` yields an unsigned `Runner.app` that cannot be
installed on a device or uploaded to TestFlight.

### Web Production Bundle
```bash
flutter build web --release
```
Output: `build/web/` — tracked in git and served by the Fly.io deployment.

---

## 🔐 Accounts & sign-in

There are no default, demo, or shared credentials in this project. Every account
secret is hashed with scrypt at rest and verified by the server, which then issues
a signed access token (12 h) bound to the device that signed in.

- **First administrator:** comes from the deployment environment —
  `ADMIN_BOOTSTRAP_EMAIL` and `ADMIN_BOOTSTRAP_PASSWORD`. The server refuses to
  boot if either is missing or if the password is a known placeholder.
- **Tellers and further admins:** created in *Admin → Tellers*. Creating a new
  account returns a generated sign-in secret **once**, in the response; it is not
  stored in plaintext and cannot be recovered afterwards.
- **Device binding:** the first successful sign-in pins an account to that
  terminal. Signing in elsewhere returns a clear error until an administrator
  calls `POST /api/users/:id/unbind-device`.
- **Self-service:** `POST /api/auth/change-password` (requires the current
  secret, revokes every existing session).

Required environment variables are listed in `.env.example`. In production set
them as secrets, e.g. `flyctl secrets set AUTH_SECRET ADMIN_BOOTSTRAP_EMAIL
ADMIN_BOOTSTRAP_PASSWORD WHITSUNPAY_CLIENT_ID WHITSUNPAY_API_KEY DATABASE_URL`.
Generate the token-signing key with `openssl rand -hex 32`.

Apply `database/auth-migration.sql` once against an existing database — it adds
`users."pinHash"`, `users."deviceId"` and the `sessions` table, and neutralises
any leftover weak PIN so those accounts must be re-enrolled.
