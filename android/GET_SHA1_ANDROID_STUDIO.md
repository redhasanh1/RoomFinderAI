# 🔑 Get SHA-1 Fingerprint in Android Studio

Since you don't have a debug keystore yet, here are the easiest ways to get your SHA-1 fingerprint:

## Method 1: Android Studio (Easiest)

1. **Open your project in Android Studio**
2. **Click on "Gradle" tab** (usually on the right side)
3. **Navigate to:** `android` → `app` → `Tasks` → `android` → `signingReport`
4. **Double-click `signingReport`**
5. **Look in the Build output** for something like:
   ```
   Variant: debug
   Config: debug
   Store: ~/.android/debug.keystore
   Alias: AndroidDebugKey
   SHA1: AA:BB:CC:DD:EE:FF:11:22:33:44:55:66:77:88:99:AA:BB:CC:DD:EE
   ```
6. **Copy the SHA1 value**

## Method 2: Terminal in Android Studio

1. **Open Terminal** in Android Studio (bottom tab)
2. **Run:**
   ```bash
   ./gradlew signingReport
   ```
3. **Copy the SHA1 fingerprint** from the output

## Method 3: Build the app first

1. **In Android Studio:** Build → Make Project
2. **Or run the app once** (this creates the debug keystore)
3. **Then use Method 1 or 2**

## Method 4: Create debug keystore manually

If nothing else works, run this in your terminal:
```bash
keytool -genkey -v -keystore ~/.android/debug.keystore -storepass android -alias androiddebugkey -keypass android -keyalg RSA -keysize 2048 -validity 10000 -dname "CN=Android Debug,O=Android,C=US"
```

Then get the fingerprint:
```bash
keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android
```

## Next Steps

Once you have the SHA-1 fingerprint:

1. **Go to [Google Cloud Console](https://console.cloud.google.com/)**
2. **Select your project** 
3. **Go to APIs & Services → Credentials**
4. **Edit your OAuth 2.0 client ID**
5. **Add the SHA-1 fingerprint**
6. **Save changes**

Your Google Sign-In should work immediately after this!