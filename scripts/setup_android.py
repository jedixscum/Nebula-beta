#!/usr/bin/env python3
"""Patch the Flutter-generated android/ project for Nebula (run after `flutter create`).
Idempotent: safe to run more than once."""
import pathlib, re, sys

root = pathlib.Path('android')
if not root.exists():
    sys.exit('android/ not found: run `flutter create --platforms=android --project-name nebula .` first')

# --- AndroidManifest: internet, cleartext (some addons serve http), Picture-in-Picture
mf = root / 'app/src/main/AndroidManifest.xml'
s = mf.read_text()
if 'android.permission.INTERNET' not in s:
    s = s.replace('<application', '<uses-permission android:name="android.permission.INTERNET"/>\n    <application', 1)
if 'usesCleartextTraffic' not in s:
    s = s.replace('<application', '<application android:usesCleartextTraffic="true"', 1)
if 'supportsPictureInPicture' not in s:
    s = s.replace('<activity', '<activity android:supportsPictureInPicture="true"', 1)
mf.write_text(s)

# --- minSdk 24 (media_kit needs >= 21; we target 24)
for name in ('app/build.gradle.kts', 'app/build.gradle'):
    f = root / name
    if not f.exists():
        continue
    t = f.read_text()
    t = re.sub(r'minSdk\s*=\s*flutter\.minSdkVersion', 'minSdk = 24', t)
    t = re.sub(r'minSdkVersion\s+flutter\.minSdkVersion', 'minSdkVersion 24', t)
    f.write_text(t)
print('android/ patched')
