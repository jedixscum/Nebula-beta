#!/usr/bin/env python3
"""Patch Flutter's generated Android project for Nebula phone or Android TV builds."""
import pathlib
import re
import sys

TV_MODE = "--tv" in sys.argv
root = pathlib.Path("android")
if not root.exists():
    sys.exit("android/ not found: run flutter create first")

mf = root / "app/src/main/AndroidManifest.xml"
s = mf.read_text()
if "android.permission.INTERNET" not in s:
    s = s.replace("<application", '<uses-permission android:name="android.permission.INTERNET"/>\n    <application', 1)
if "android.permission.REQUEST_INSTALL_PACKAGES" not in s:
    s = s.replace("<application", '<uses-permission android:name="android.permission.REQUEST_INSTALL_PACKAGES"/>\n    <application', 1)
if "usesCleartextTraffic" not in s:
    s = s.replace("<application", '<application android:usesCleartextTraffic="true"', 1)
if "supportsPictureInPicture" not in s:
    s = s.replace("<activity", '<activity android:supportsPictureInPicture="true"', 1)

if TV_MODE:
    if 'android:name="android.software.leanback"' not in s:
        s = s.replace("<application", '<uses-feature android:name="android.software.leanback" android:required="true"/>\n    <uses-feature android:name="android.hardware.touchscreen" android:required="false"/>\n    <application', 1)
    if 'android:banner="@drawable/tv_banner"' not in s:
        s = s.replace("<application", '<application android:banner="@drawable/tv_banner"', 1)
    s = s.replace('android:label="nebula"', 'android:label="Nebula TV"')
    launcher = '<category android:name="android.intent.category.LAUNCHER"/>'
    if launcher in s and 'android.intent.category.LEANBACK_LAUNCHER' not in s:
        s = s.replace(launcher, launcher + '\n                <category android:name="android.intent.category.LEANBACK_LAUNCHER"/>')

# Securely expose downloaded APKs to Android's package installer.
if 'androidx.core.content.FileProvider' not in s:
    provider = '''\n        <provider\n            android:name="androidx.core.content.FileProvider"\n            android:authorities="${applicationId}.fileprovider"\n            android:exported="false"\n            android:grantUriPermissions="true">\n            <meta-data\n                android:name="android.support.FILE_PROVIDER_PATHS"\n                android:resource="@xml/file_paths" />\n        </provider>'''
    s = s.replace('</application>', provider + '\n    </application>')

mf.write_text(s)

# Keep phone and TV installs side-by-side.
for name in ("app/build.gradle.kts", "app/build.gradle"):
    f = root / name
    if not f.exists():
        continue
    t = f.read_text()
    t = re.sub(r'minSdk\s*=\s*flutter\.minSdkVersion', "minSdk = 24", t)
    t = re.sub(r'minSdkVersion\s+flutter\.minSdkVersion', "minSdkVersion 24", t)
    if TV_MODE:
        t = re.sub(r'applicationId\s*=\s*"com\.nebula\.nebula"', 'applicationId = "com.nebula.nebula.tv"', t)
        t = re.sub(r'applicationId\s+"com\.nebula\.nebula"', 'applicationId "com.nebula.nebula.tv"', t)
    f.write_text(t)

# FileProvider paths: only the app-private cache is exposed.
paths = root / "app/src/main/res/xml/file_paths.xml"
paths.parent.mkdir(parents=True, exist_ok=True)
paths.write_text('''<?xml version="1.0" encoding="utf-8"?>\n<paths xmlns:android="http://schemas.android.com/apk/res/android">\n    <cache-path name="apk_cache" path="."/>\n</paths>\n''')

if TV_MODE:
    banner = root / "app/src/main/res/drawable-nodpi/tv_banner.xml"
    banner.parent.mkdir(parents=True, exist_ok=True)
    banner.write_text("""<?xml version="1.0" encoding="utf-8"?>
<vector xmlns:android="http://schemas.android.com/apk/res/android"
    android:width="320dp" android:height="180dp" android:viewportWidth="320" android:viewportHeight="180">
    <path android:fillColor="#05060F" android:pathData="M0,0h320v180h-320z"/>
    <path android:fillColor="#26165A" android:fillAlpha="0.55" android:pathData="M0,0h320v180h-320z"/>
    <path android:fillColor="#18FFFF" android:fillAlpha="0.10" android:pathData="M210,0h110v180h-110z"/>
    <path android:strokeColor="#7C4DFF" android:strokeWidth="3" android:fillColor="#05060F" android:pathData="M114,90a44,44 0,1 1,-88 0a44,44 0,1 1,88 0z"/>
    <path android:strokeColor="#18FFFF" android:strokeWidth="3" android:fillColor="#15102C" android:pathData="M102,90a32,32 0,1 1,-64 0a32,32 0,1 1,64 0z"/>
    <path android:fillColor="#18FFFF" android:pathData="M70,69l8,8 -8,8 -8,-8z"/>
    <path android:fillColor="#FFFFFF" android:pathData="M38,25l2,5 5,2 -5,2 -2,5 -2,-5 -5,-2 5,-2z M111,40l2,4 4,2 -4,2 -2,4 -2,-4 -4,-2 4,-2z M111,112l2,4 4,2 -4,2 -2,4 -2,-4 -4,-2 4,-2z"/>
    <path android:fillColor="#FFFFFF" android:pathData="M136,64h142v3h-142z M136,74h108v2h-108z"/>
</vector>
""")

acts = list(root.glob("app/src/main/kotlin/**/MainActivity.kt"))
if not acts:
    sys.exit("MainActivity.kt not found")
act = acts[0]
pkg_match = re.search(r"^package\s+([\w.]+)", act.read_text(), re.M)
if not pkg_match:
    sys.exit("Could not determine MainActivity package")
pkg = pkg_match.group(1)
act.write_text("""package %s

import android.app.PictureInPictureParams
import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import android.util.Rational
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

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

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "nebula/updater").setMethodCallHandler { call, result ->
            when (call.method) {
                "getVersion" -> {
                    @Suppress("DEPRECATION")
                    val info = packageManager.getPackageInfo(packageName, 0)
                    @Suppress("DEPRECATION")
                    val build = if (Build.VERSION.SDK_INT >= 28) info.longVersionCode else info.versionCode.toLong()
                    result.success(mapOf("name" to (info.versionName ?: "0.1.0"), "build" to build))
                }
                "isTv" -> {
                    val mode = resources.configuration.uiMode and android.content.res.Configuration.UI_MODE_TYPE_MASK
                    result.success(mode == android.content.res.Configuration.UI_MODE_TYPE_TELEVISION)
                }
                "openInstallSettings" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        startActivity(Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES, Uri.parse("package:$packageName")))
                    }
                    result.success("opened")
                }
                "installApk" -> {
                    val path = call.argument<String>("path")
                    if (path.isNullOrBlank()) {
                        result.error("INVALID_PATH", "APK path is missing", null)
                    } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O && !packageManager.canRequestPackageInstalls()) {
                        result.success("permission_required")
                    } else {
                        try {
                            val file = File(path)
                            if (!file.exists()) {
                                result.error("MISSING_FILE", "APK no longer exists", null)
                                return@setMethodCallHandler
                            }
                            val uri = FileProvider.getUriForFile(this, "$packageName.fileprovider", file)
                            val intent = Intent(Intent.ACTION_VIEW).apply {
                                setDataAndType(uri, "application/vnd.android.package-archive")
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                            }
                            startActivity(intent)
                            result.success("started")
                        } catch (e: ActivityNotFoundException) {
                            result.error("NO_INSTALLER", "No Android package installer is available", null)
                        } catch (e: Exception) {
                            result.error("INSTALL_ERROR", e.message, null)
                        }
                    }
                }
                else -> result.notImplemented()
            }
        }
    }
}
""" % pkg)
print("android/ patched for " + ("Android TV" if TV_MODE else "phone"))
