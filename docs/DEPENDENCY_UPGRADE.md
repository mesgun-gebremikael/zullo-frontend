# Native dependency upgrade and verification

## Supported dependencies

The lockfile selects versions supported by Flutter 3.38.4 / Dart 3.10. Upgrading everything to its numerically highest release would require a coordinated Flutter SDK upgrade. In particular, cached_network_image 4 and the newest image_picker require newer SDKs. Keep dependency resolution reproducible with `flutter pub get --enforce-lockfile` in CI.

Firebase Messaging stays on the latest compatible **16.7.1** family with Firebase Core **4.15.1**. Messaging 17 changes direct-send registration from an FCM registration token to a Firebase Installation ID. ZULLO's backend currently uses Firebase Admin's registration-token send API. Updating only the client to Messaging 17 would silently break this contract. A future major upgrade must migrate and verify both ends together.

The native app targets iOS 15 or newer (required by the updated Firebase family). Android follows the pinned Flutter SDK: minimum API 24, compile/target API 36, Java/Kotlin target 17, desugaring 2.1.4. Apple signing, APNs provisioning and production Android signing remain release prerequisites; a successful simulator/debug build does not validate these.

RevenueCat `purchases_flutter` remains on the supported **10.19.0** family. Version 11 requires `PurchasesHybridCommon 20.0.0`, which the iOS CocoaPods source did not provide during verification. The compatible family resolves the available native SDK without activating payments or bypassing native dependency checks. Revisit that major upgrade only after both platforms can resolve and compile its published native dependencies.

## Secure storage migration

flutter_secure_storage **10.3.4** is an intentional migration bridge from v9. Both authentication and onboarding draft storage use `resetOnError: false` and `migrateWithBackup: true`; v10's automatic cipher migration remains enabled. Failures must not silently clear an account's stored data. Android backup stays disabled because ciphertext restored without its device Keystore key cannot be read.

Do not jump directly from v9 to v11: v11 removes legacy cipher migration. Before moving to v11, verify the v10 migration on a device with an actual existing v9 installation, valid login and unfinished onboarding draft. Test successful migration, restart, offline startup, sign out, sign in and draft restoration. Dart fake-storage tests validate application behavior but cannot validate Android Keystore migration.

## Java warnings on developer machines

Use JDK **17**, matching CI and this Gradle toolchain. Check `flutter doctor -v` for the JDK Flutter actually uses. If necessary, run `flutter config --jdk-dir="<absolute path to JDK 17>"`. Restart the build after changing the JDK.

The latest geolocator_android 5.2.1 still compiles its own module with Java 8 compatibility and calls a deprecated Android Bundle accessor. On newer JDKs this also produces obsolete source/target warnings. Updating the package does not eliminate every upstream warning. We do not hide compiler warnings, edit the pub cache, or maintain an entire fork just to remove an informational message. Track the upstream deprecation and adopt its reviewed fix when released; this message alone does not indicate GPS failure.

## Checks

CI compiles the real Android debug app and iOS simulator app and checks the committed CocoaPods lockfile. Portable `.ci/check_android_setup.py` and `.ci/check_ios_setup.py` validate native prerequisites, separately from compilation. Physical-device GPS, push delivery, secure-storage upgrades and store signing must be verified before release.
