# Android compiler and location maintenance

The application pins the **Java17 compiler toolchain** for every JavaCompile task. A developer can launch Gradle through Android Studio JBR21 without compiling Java8 plugins with JDK21. Gradle's official toolchain service preserves each module's Java/Kotlin bytecode target, so plugin target8 code stays target8 and the application remains target17. Foojay resolver1.0.0 provisions JDK17 when it is absent; the first build may therefore download a JDK. CI still starts Gradle with its installed JDK17.

This addresses `source/target value8 is obsolete` by using the supported compiler rather than suppressing diagnostics or rewriting third-party bytecode targets. No `-Xlint:none` or cache modification is used.

The latest compatible geolocator_android5.2.1 still uses deprecated untyped `Bundle.get`. ZULLO includes a narrow MIT-licensed, versioned source patch in `packages/geolocator_android`, replacing this with AndroidX's typed Number accessor. Public API, location permissions and the package's platform behavior remain stable. The original archive checksum, exact upstream-file hashes, reviewed changes and removal procedure are recorded in `ZULLO_PATCH.md`. The provenance check rejects unrelated source changes, unexpected added files and any byte drift in the specifically reviewed modified source or native compatibility test. Scoped LF checkout attributes keep these hashes reproducible on Windows. This is a maintained dependency patch; it must be revisited when upstream ships the same fix.

Validation commands:

```sh
python3 .ci/check_android_setup.py
python3 .ci/check_geolocator_patch.py
flutter pub get --enforce-lockfile
cd android
./gradlew :geolocator_android:testDebugUnitTest
```

The native mapper tests include real Android BundleCompat behavior at API24 and API34 through Robolectric, covering numeric types, invalid types, absent values, nonfinite numbers and fallback-key rules. They need an Android SDK and repository network access. The Linux coding workspace currently has no Android SDK; a portable checker passing is **not** a claim that these native tests or the app build passed. CI must run the native tests and actual APK/iOS build before merge. Other upstream packages may still produce their own deprecated-API notes; they are neither hidden nor reported as eliminated by this patch.

# Native notification languages

`tool/generate_notification_resources.py` generates Android string resources and iOS Localizable.strings/PBX references for the same40 validated ARB languages. Match title/body, Superlike body and the privacy-safe generic message body are reused from genuine Flutter translations. Message notification resources contain no sender identity, avatar or chat preview; authorized in-app handlers resolve the profile after checking the recipient and current session. Run:

```sh
python3 tool/generate_notification_resources.py --check
```

On macOS, additionally validate `ios/Runner/*.lproj/Localizable.strings` and `ios/Runner.xcodeproj/project.pbxproj` with `plutil -lint`, then compile the simulator application. OS notifications select the phone/per-app native language. Flutter's own manual language preference alone does not override an OS notification's localization; that difference is intentional and must not be represented as server-side per-device language support. Names and chat messages remain user-authored content and are never put into the static translation resources.

Generation changes only its deterministic PBX entries and preserves unrelated project resources. Keep the generator check in CI so translations and native notification copy cannot drift. Physical-device APNs/FCM delivery and user permission flows remain a separate release test.

# iOS runner architecture and infrastructure failures

The simulator job uses the standard `macos-15-intel` image explicitly. GitHub's `macos-15` label now selects arm64; run45831841893 was cancelled before any step ran because GitHub could not allocate a hosted arm64 runner. This was a capacity failure, not evidence of an Xcode compilation error. Pinning the architecture keeps the CI environment explicit without selecting paid `-large`/`-xlarge` runners or changing the application's architectures.

Official label reference: https://github.com/actions/runner-images#available-images . The Intel simulator build verifies x86_64 simulator packaging. Device arm64, signing, APNs delivery and actual iPhone performance remain separate release checks; neither a portable check nor this runner selection proves them.

## Native runtime dependency download diagnostics

Run 45904069607 built the Android APK, then Robolectric class setup failed in MavenArtifactFetcher with an HTTP I/O exception before the API 24/34 compatibility assertions could run. The pinned 4.17 source artifact `plugins-maven-dependency-resolver-4.17-sources.jar` confirms MavenRoboSettings defaults to repo1.maven.org and supports the `robolectric.dependency.repo.url` property. Android's root test configuration now explicitly selects Maven Central's canonical https://repo.maven.apache.org/maven2 endpoint, matching Gradle mavenCentral(). Tests and API levels remain unchanged; no warning/test failure is suppressed. Full test exception causes and failed native JUnit reports are preserved for diagnosing future network or assertion failures. A passing rerun is required; changing an endpoint is not itself a successful test.
