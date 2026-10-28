#!/usr/bin/env python3
"""Portable checks of iOS packaging prerequisites; not a substitute for Xcode."""
from pathlib import Path
import plistlib
import json

root = Path(__file__).resolve().parents[1]
with (root / 'ios/Runner/Info.plist').open('rb') as stream:
    info = plistlib.load(stream)
with (root / 'ios/Runner/Runner.entitlements').open('rb') as stream:
    entitlements = plistlib.load(stream)
assert info.get('NSPhotoLibraryUsageDescription'), 'Photo selection needs an iOS usage description'
assert 'remote-notification' in info.get('UIBackgroundModes', []), 'Missing remote notification capability'
assert not info.get('NSAppTransportSecurity', {}).get('NSAllowsArbitraryLoads'), 'Do not disable iOS transport security'
assert entitlements.get('aps-environment') == '$(APS_ENVIRONMENT)', 'APNs environment must match the build configuration'
project = (root / 'ios/Runner.xcodeproj/project.pbxproj').read_text()
assert project.count('CODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements;') == 3
assert project.count('APS_ENVIRONMENT = development;') == 1
assert project.count('APS_ENVIRONMENT = production;') == 2
for name in ['Debug', 'Release']:
    config = (root / f'ios/Flutter/{name}.xcconfig').read_text()
    assert 'Pods-Runner.' in config and 'Generated.xcconfig' in config
assert "platform :ios, '13.0'" in (root / 'ios/Podfile').read_text()
registration = json.loads((root / 'config/ios.firebase.json').read_text())
bundle = registration['ZULLO_IOS_BUNDLE_ID']
assert project.count(f'PRODUCT_BUNDLE_IDENTIFIER = {bundle};') == 3, 'Runner must match the registered Firebase bundle ID'
assert project.count(f'PRODUCT_BUNDLE_IDENTIFIER = {bundle}.RunnerTests;') == 3
print('iOS packaging and registered bundle ID OK; Apple signing and device delivery remain separate.')
