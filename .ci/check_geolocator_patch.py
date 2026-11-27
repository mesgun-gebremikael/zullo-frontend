#!/usr/bin/env python3
"""Check the narrow, licensed Android location patch against upstream hashes."""
from pathlib import Path
import hashlib
import json

root = Path(__file__).resolve().parents[1]
package = root / 'packages/geolocator_android'
manifest = json.loads((package / 'UPSTREAM_SHA256.json').read_text())
# Update these pins only alongside reviewed source changes and native regression
# verification. Merely differing from upstream is not sufficient proof of scope.
reviewed_changes = {
    'android/build.gradle': '8d01a5d2e6e73ef3822dd2a36fb2567fe5a3646ea59e87c6231116c8620be347',
    'android/src/main/java/com/baseflow/geolocator/location/LocationMapper.java': 'ee6bbfd80c7b67ca1b08fc363cc3ee5a55280573baa5890da7b2bf02a0602a97',
    'android/src/test/java/com/baseflow/geolocator/location/LocationMapperTest.java': '8f9a3e4b04b42b8616abda691919e38f7559df8a5e6e69b6ddf9c0d612ba9664',
}
for relative, expected in manifest.items():
    if relative.startswith('example/'):
        continue  # The unpublished demo is deliberately not part of the app dependency.
    path = package / relative
    assert path.is_file(), f'Missing upstream file: {relative}'
    actual = hashlib.sha256(path.read_bytes()).hexdigest()
    if relative in reviewed_changes:
        assert actual != expected, f'Expected reviewed patch is absent: {relative}'
        assert actual == reviewed_changes[relative], f'Unreviewed patch drift: {relative}'
    else:
        assert actual == expected, f'Unreviewed upstream change: {relative}'
reviewed_additions = {
    'UPSTREAM_SHA256.json',
    'ZULLO_PATCH.md',
    'android/src/test/java/com/baseflow/geolocator/location/LocationMapperCompatibilityTest.java',
}
for path in package.rglob('*'):
    if not path.is_file():
        continue
    relative = path.relative_to(package).as_posix()
    if any(part in {'.dart_tool', '.gradle', 'build'} for part in path.relative_to(package).parts):
        continue
    assert relative in manifest or relative in reviewed_additions, f'Unreviewed extra package file: {relative}'
assert hashlib.sha256((package / 'android/src/test/java/com/baseflow/geolocator/location/LocationMapperCompatibilityTest.java').read_bytes()).hexdigest() == 'b15f1ca0d4831558cdaee26c1530c8ed600ff012b6b54440f282bfca32d9a536', 'Unreviewed native compatibility-test drift'
mapper = (package / 'android/src/main/java/com/baseflow/geolocator/location/LocationMapper.java').read_text()
assert 'BundleCompat.getSerializable(extras, key, Number.class)' in mapper
assert 'extras.get(' not in mapper, 'The deprecated untyped accessor must not return'
assert '-Xlint:none' not in (root / 'android/build.gradle.kts').read_text()
assert 'javaCompiler.set(java17Compiler)' in (root / 'android/build.gradle.kts').read_text()
assert 'languageVersion.set(JavaLanguageVersion.of(17))' in (root / 'android/build.gradle.kts').read_text()
assert (package / 'android/src/test/java/com/baseflow/geolocator/location/LocationMapperCompatibilityTest.java').is_file()
assert 'packages/geolocator_android' in (root / 'pubspec.yaml').read_text()
print('Reviewed MIT Android location patch and Java17 compiler contract verified.')
