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
# --- Picture-in-Picture: tiny MethodChannel in MainActivity (no third-party plugin)
acts = list(root.glob('app/src/main/kotlin/**/MainActivity.kt'))
if not acts:
    sys.exit('MainActivity.kt not found')
act = acts[0]
pkg = re.search(r'^package\s+([\w.]+)', act.read_text(), re.M).group(1)
act.write_text('''package %s

import android.app.PictureInPictureParams
import android.os.Build
import android.util.Rational
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "nebula/pip").setMethodCallHandler { call, result ->
            when (call.method) {
                "isAvailable" -> result.success(
                    Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
                        packageManager.hasSystemFeature("android.software.picture_in_picture"))
                "enter" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        val params = PictureInPictureParams.Builder().setAspectRatio(Rational(16, 9)).build()
                        result.success(enterPictureInPictureMode(params))
                    } else {
                        result.success(false)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }
}
''' % pkg)
print('android/ patched')
