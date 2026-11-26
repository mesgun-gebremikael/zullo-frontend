#!/usr/bin/env python3
"""Exercise Gradle's real release-signing configuration with disposable CI keys."""
from pathlib import Path
import os
import secrets
import subprocess
import tempfile

root = Path(__file__).resolve().parents[1]
android = root / 'android'
assert os.environ.get('CI') == 'true', 'Run only on a disposable CI runner.'
assert not (android / 'key.properties').exists(), 'CI must not use an owner signing file.'
base = dict(os.environ)
for name in ('ZULLO_ANDROID_KEYSTORE_PATH', 'ZULLO_ANDROID_STORE_PASSWORD',
             'ZULLO_ANDROID_KEY_ALIAS', 'ZULLO_ANDROID_KEY_PASSWORD'):
    base.pop(name, None)


def gradle(arguments, env, succeeds=True, marker=None):
    result = subprocess.run(['./gradlew', '--console=plain', *arguments],
                            cwd=android, env=env, capture_output=True, text=True,
                            timeout=240)
    output = result.stdout + result.stderr
    if (result.returncode == 0) != succeeds or (marker and marker not in output):
        print(output[-12000:])
        raise SystemExit('Unexpected Gradle release-signing result.')
    return output


gradle([':app:validateZulloReleaseSigning'], base, False,
       'ZULLO_RELEASE_SIGNING_REQUIRED')
for artifact in ('assembleRelease', 'bundleRelease'):
    graph = gradle([f':app:{artifact}', '--dry-run'], base)
    assert graph.index(':app:validateZulloReleaseSigning') < graph.index(f':app:{artifact}')

with tempfile.TemporaryDirectory(prefix='zullo-signing-ci-') as temporary:
    store = Path(temporary) / 'disposable.p12'
    env = dict(base,
               ZULLO_ANDROID_KEYSTORE_PATH=str(store),
               ZULLO_ANDROID_STORE_PASSWORD=secrets.token_urlsafe(24),
               ZULLO_ANDROID_KEY_ALIAS='disposable-ci-key')
    env['ZULLO_ANDROID_KEY_PASSWORD'] = env['ZULLO_ANDROID_STORE_PASSWORD']
    # These credentials belong only to this temporary CI key and are never saved
    # as an owner key, uploaded as an artifact or used to publish an app.
    keytool = Path(env['JAVA_HOME']) / 'bin' / 'keytool'
    subprocess.run([str(keytool), '-genkeypair', '-noprompt', '-storetype', 'PKCS12',
                    '-keystore', str(store), '-alias', env['ZULLO_ANDROID_KEY_ALIAS'],
                    '-storepass:env', 'ZULLO_ANDROID_STORE_PASSWORD',
                    '-keypass:env', 'ZULLO_ANDROID_KEY_PASSWORD',
                    '-keyalg', 'RSA', '-keysize', '2048', '-validity', '1',
                    '-dname', 'CN=Disposable ZULLO CI'],
                   env=env, check=True, capture_output=True, text=True)
    gradle([':app:validateSigningRelease'], env)
    env['ZULLO_ANDROID_KEYSTORE_PATH'] = str(Path(temporary) / 'missing.p12')
    gradle([':app:validateZulloReleaseSigning'], env, False,
           'ZULLO_RELEASE_KEYSTORE_MISSING')
print('Real Gradle signing checks passed: missing configuration, artifact guards, '
      'disposable valid key and missing keystore. No owner key or release artifact created.')
