package com.amirani.amirani_app

import android.nfc.NfcAdapter
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * MainActivity
 *
 * Exposes a MethodChannel "com.amirani/hce" to Flutter so the Dart layer
 * can manage the phone NFC key credential without needing a Flutter NFC plugin.
 *
 * Methods:
 *   isHceSupported()   → bool
 *   isNfcEnabled()     → bool
 *   getOrCreateCred()  → String (16-char hex, e.g. "A1B2C3D4E5F60708")
 *   getCred()          → String? (null if not enrolled)
 *   enableHce()        → void  (marks credential as active)
 *   disableHce()       → void  (marks credential as inactive, keeps stored)
 *   clearCred()        → void  (removes credential — unenroll)
 *   isHceEnabled()     → bool
 */
class MainActivity : FlutterActivity() {

    companion object {
        private const val CHANNEL = "com.amirani/hce"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                val prefs = getSharedPreferences(AmiraniHceService.PREFS_NAME, MODE_PRIVATE)

                when (call.method) {
                    "isHceSupported" -> {
                        val adapter = NfcAdapter.getDefaultAdapter(this)
                        result.success(adapter != null && adapter.isEnabled)
                    }

                    "isNfcEnabled" -> {
                        val adapter = NfcAdapter.getDefaultAdapter(this)
                        result.success(adapter?.isEnabled == true)
                    }

                    "getOrCreateCred" -> {
                        var cred = prefs.getString(AmiraniHceService.KEY_CREDENTIAL, null)
                        if (cred == null || cred.length != 16) {
                            cred = AmiraniHceService.generateCredential()
                            prefs.edit().putString(AmiraniHceService.KEY_CREDENTIAL, cred).apply()
                        }
                        result.success(cred)
                    }

                    "getCred" -> {
                        result.success(prefs.getString(AmiraniHceService.KEY_CREDENTIAL, null))
                    }

                    "enableHce" -> {
                        prefs.edit().putBoolean(AmiraniHceService.KEY_ENABLED, true).apply()
                        result.success(null)
                    }

                    "disableHce" -> {
                        prefs.edit().putBoolean(AmiraniHceService.KEY_ENABLED, false).apply()
                        result.success(null)
                    }

                    "clearCred" -> {
                        prefs.edit()
                            .remove(AmiraniHceService.KEY_CREDENTIAL)
                            .remove(AmiraniHceService.KEY_ENABLED)
                            .apply()
                        result.success(null)
                    }

                    "isHceEnabled" -> {
                        result.success(prefs.getBoolean(AmiraniHceService.KEY_ENABLED, false))
                    }

                    else -> result.notImplemented()
                }
            }
    }
}
