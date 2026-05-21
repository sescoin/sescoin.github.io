package com.example.ses_coin

import android.content.Context
import android.content.Intent
import android.nfc.NfcManager
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val HCE_CHANNEL = "ses_coin/hce"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, HCE_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "startEmitting" -> {
                        SESCoinHceService.currentToken = call.argument<String>("token")
                        result.success(null)
                    }
                    "stopEmitting" -> {
                        SESCoinHceService.currentToken = null
                        result.success(null)
                    }
                    "isEmitting" -> {
                        result.success(SESCoinHceService.currentToken != null)
                    }
                    "openNfcSettings" -> {
                        startActivity(Intent(Settings.ACTION_NFC_SETTINGS))
                        result.success(null)
                    }
                    "getNfcState" -> {
                        val mgr = getSystemService(Context.NFC_SERVICE) as? NfcManager
                        val adapter = mgr?.defaultAdapter
                        val state = when {
                            adapter == null      -> "not_supported"
                            adapter.isEnabled    -> "enabled"
                            else                 -> "disabled"
                        }
                        result.success(state)
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
