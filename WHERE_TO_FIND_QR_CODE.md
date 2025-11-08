# How to View Your QR Code in the App

## ✅ QR Code Location

After creating a new account, you can view your QR code in the **Settings** screen.

### Steps to Access Your QR Code:

1. **Sign Up / Login** to your account
2. Navigate to **Settings** (usually in the navigation menu)
3. Scroll down to find the **"My QR Code"** section
4. Your QR code will be displayed automatically!

---

## 📱 What You'll See in Settings

### QR Code Card Features:

- **QR Code Visual** - A scannable QR code (currently shows placeholder, use `qr_flutter` package for actual QR)
- **Unique Code** - Your unique QR code string (e.g., `QR-1699488000000-ABC12345`)
- **Copy Button** - Tap to copy the code to clipboard
- **Scan Count** - Total number of times your QR has been scanned
- **Created Date** - When your QR code was generated
- **View Statistics** - Button to see detailed analytics

---

## 🎯 QR Code Integration

The QR code is automatically displayed in your Settings screen under:

```
Settings Screen
  ├─ Profile Section
  ├─ My QR Code Section ← YOUR QR CODE IS HERE!
  ├─ General Settings
  └─ App Settings
```

### Code Location in Settings Screen:

File: `lib/screens/settings/settings_screen.dart`

The QR code appears between your profile and the general settings sections.

---

## 📊 View Detailed Statistics

Click the **"View Statistics"** button to see:

- ✅ Total scans
- ✅ Today's scans
- ✅ This week's scans
- ✅ This month's scans
- ✅ Recent scan history with:
  - Timestamp
  - Location (if available)
  - Device information

---

## 🔄 How It Works

### Automatic QR Code Generation:

When you create a new account:
1. Account is created in the database
2. QR code is **automatically generated** 
3. Unique code is assigned
4. Ready to share immediately!

### First Time Opening Settings:

When you open Settings for the first time:
1. The app checks if your account has a QR code
2. If not found, it generates one automatically
3. The QR code is then displayed
4. Scan count starts at 0

---

## 💡 What to Do Next

### Share Your QR Code:

1. **Screenshot** the QR code from the app
2. **Print** it and display at your business
3. **Share** on social media
4. **Add** to marketing materials

### Track Performance:

- Check your scan statistics regularly
- See when customers scan your code
- Understand customer behavior
- Track marketing effectiveness

---

## 🛠️ Optional: Display Actual QR Code

Currently, the QR code shows a placeholder. To display the actual scannable QR code:

### Install QR Flutter Package:

```bash
flutter pub add qr_flutter
```

### Update the QR Code Display:

In `lib/widgets/qr_code_widget.dart`, replace the placeholder container with:

```dart
import 'package:qr_flutter/qr_flutter.dart';

// Replace the placeholder Container with:
QrImageView(
  data: qrCode.code,
  version: QrVersions.auto,
  size: 200.0,
  backgroundColor: Colors.white,
)
```

---

## 📍 Navigation Path

To access Settings in your app:

1. **From Home Screen**: 
   - Look for Settings icon/button in navbar or menu
   
2. **From Category Dashboard** (Meals, Gym, etc.):
   - Tap Settings in the navigation

3. **Direct Access**:
   - Settings screen is available after authentication

---

## 🎨 Customization Options

You can customize the QR code section in Settings:

- Change colors to match your category (Meals = orange, Gym = red)
- Adjust size and layout
- Add download/share buttons
- Add business info below QR code

---

## 🔐 Security Notes

- ✅ Only **you** can see your own QR code
- ✅ Customers can **scan** the QR code publicly
- ✅ Scan statistics are **private** to your account
- ✅ QR codes are **unique** and cannot be duplicated

---

## ❓ Troubleshooting

### QR Code Not Showing?

1. **Check Database**: Ensure the SQL setup was run in Supabase
2. **Check Account**: Verify you're logged in
3. **Check Connection**: Ensure internet connection is active
4. **Refresh**: Pull down to refresh the Settings screen

### QR Code Error?

- Check Supabase console for errors
- Verify RLS policies are enabled
- Ensure `qr_codes` table exists

### Need Help?

- Review `QR_SYSTEM_SETUP.md` for database setup
- Check `QR_IMPLEMENTATION_GUIDE.md` for full documentation
- Run the SQL from `qr_system_setup.sql` in Supabase

---

## 🚀 Quick Test

1. **Create a new account** (or login to existing)
2. **Navigate to Settings**
3. **Scroll to "My QR Code"**
4. **See your unique QR code!**
5. **Tap "View Statistics"** to see analytics

---

**That's it!** Your QR code is automatically available in Settings after account creation. 🎉
