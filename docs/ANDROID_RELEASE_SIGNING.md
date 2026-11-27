# Android release signing

Release APK/AAB builds require an owner-controlled signing configuration. They no longer fall back to Android's development/debug key. Debug/emulator builds still work without release credentials. This configuration does not activate payments or publish an app.

## Owner key and store identity

For Google Play, enable Play App Signing and use the owner's upload key according to Play Console's instructions. Keep durable, access-controlled backups and a recovery process. Do not generate the only permanent key in a disposable development/CI workspace. Never commit a key/password, send it in chat or attach it to a PR.

Keep the application's registered Firebase/Google Play identity and existing installation/update history aligned. This change deliberately does not rename `applicationId` or replace a registered signing identity. Final store identity and owner credentials must be verified before publication.

## Configure one of these sources

Create the already Git-ignored `android/key.properties` locally:

```properties
storeFile=/absolute/path/to/your-upload-key.jks
storePassword=YOUR_STORE_PASSWORD
keyAlias=YOUR_KEY_ALIAS
keyPassword=YOUR_KEY_PASSWORD
```

Alternatively use the deployment/CI secret system:

```text
ZULLO_ANDROID_KEYSTORE_PATH=/absolute/path/to/your-upload-key.jks
ZULLO_ANDROID_STORE_PASSWORD=<secret>
ZULLO_ANDROID_KEY_ALIAS=<owner key alias>
ZULLO_ANDROID_KEY_PASSWORD=<secret>
```

Environment variables override matching properties. A relative `storeFile` is resolved against the `android/` directory. Prefer an absolute path. On Windows use forward slashes, for example `storeFile=C:/Users/your-name/keys/upload-key.jks`; backslashes in a Java properties file are escape characters. Do not copy real credentials into this document. `android/key.properties`, `*.jks` and `*.keystore` are already ignored by Android's `.gitignore`.

## Build and verify

Normal development remains `flutter run -d <device-id>` with the project's normal API/configuration arguments. A release build such as `flutter build appbundle --release` now fails clearly if credentials or the keystore file are missing. Supply all normal Firebase/API/store build arguments as documented separately; signing configuration alone does not configure those services.

Gradle's `:app:validateZulloReleaseSigning` checks required configuration/file presence; Android's `:app:validateSigningRelease` validates the supplied signing configuration. APK/AAB assembly depends on the owner-credential check. Invalid passwords/aliases fail through Android's signing/build tooling; no exception silently substitutes the development key.

Before publishing, verify the completed artifact's signature with Android's official tooling and check its certificate against Play Console's upload certificate. Confirm installation/upgrades with the intended store/testing channel. A valid signature alone does not certify payment products, privacy disclosures, app review, native delivery or device behavior.

## Automated checks

The Android CI job first builds the ordinary debug APK and runs native GPS tests, then exercises actual Gradle signing validation:

- No credentials: the dedicated check fails with a named configuration message.
- APK and AAB dry-run task graphs contain the signing guard before artifact assembly.
- A disposable one-day CI key passes Android's signing validation using both environment variables and a local properties file with a relative path.
- A configured missing file fails with a named missing-keystore message.

The temporary key is generated only on a disposable CI runner, deleted afterward, never uploaded and never used as an owner production key. These checks do not publish or create a production release artifact.
