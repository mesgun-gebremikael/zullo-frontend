#!/usr/bin/env python3
"""Check security and dependency prerequisites; native compilation runs separately."""
from pathlib import Path
import xml.etree.ElementTree as ET

root = Path(__file__).resolve().parents[1]
manifest = ET.parse(root / 'android/app/src/main/AndroidManifest.xml').getroot()
ns = '{http://schemas.android.com/apk/res/android}'
permissions = {node.get(ns + 'name') for node in manifest.findall('uses-permission')}
assert {'android.permission.ACCESS_COARSE_LOCATION', 'android.permission.ACCESS_FINE_LOCATION'} <= permissions
assert 'android.permission.ACCESS_BACKGROUND_LOCATION' not in permissions
assert manifest.find('application').get(ns + 'allowBackup') == 'false', 'Keystore-backed data must not be restored without its key'
gradle = (root / 'android/app/build.gradle.kts').read_text()
assert 'sourceCompatibility = JavaVersion.VERSION_17' in gradle
assert 'targetCompatibility = JavaVersion.VERSION_17' in gradle
assert 'jvmTarget = JavaVersion.VERSION_17.toString()' in gradle
assert 'isCoreLibraryDesugaringEnabled = true' in gradle
assert 'desugar_jdk_libs:2.1.4' in gradle
print('Android foreground permissions, backup policy and Java 17/desugaring configuration OK.')
