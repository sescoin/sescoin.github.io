package com.example.ses_coin

import android.nfc.cardemulation.HostApduService
import android.os.Bundle

/**
 * HCE service that emulates an NFC card so other phones can read a payment token
 * without needing a physical NFC tag.
 *
 * AID: F053455343 4F494E ("F0" + "SESCOIN" in ASCII)
 *
 * APDU protocol:
 *   SELECT AID  → 90 00
 *   GET DATA    → [token bytes] 90 00
 */
class SESCoinHceService : HostApduService() {

    companion object {
        // 8-byte proprietary AID: F0 + "SESCOIN"
        val AID_BYTES: ByteArray = byteArrayOf(
            0xF0.toByte(), 0x53, 0x45, 0x53, 0x43, 0x4F.toByte(), 0x49, 0x4E
        )

        // Token set by MainActivity via the platform channel
        @Volatile
        var currentToken: String? = null

        // Status words
        private val SW_SUCCESS = byteArrayOf(0x90.toByte(), 0x00)
        private val SW_FILE_NOT_FOUND = byteArrayOf(0x6A, 0x82.toByte())
        private val SW_INS_NOT_SUPPORTED = byteArrayOf(0x6D, 0x00)
        private val SW_UNKNOWN = byteArrayOf(0x6F, 0x00)
    }

    override fun processCommandApdu(apdu: ByteArray, extras: Bundle?): ByteArray {
        if (apdu.size < 4) return SW_UNKNOWN

        val cla = apdu[0]
        val ins = apdu[1]
        val p1  = apdu[2]

        return when {
            // SELECT FILE by AID (CLA=00, INS=A4, P1=04)
            cla == 0x00.toByte() && ins == 0xA4.toByte() && p1 == 0x04.toByte() -> {
                SW_SUCCESS
            }

            // GET DATA (CLA=00, INS=CA) — return the payment token
            cla == 0x00.toByte() && ins == 0xCA.toByte() -> {
                val token = currentToken
                if (token == null) {
                    SW_FILE_NOT_FOUND
                } else {
                    token.toByteArray(Charsets.UTF_8) + SW_SUCCESS
                }
            }

            else -> SW_INS_NOT_SUPPORTED
        }
    }

    override fun onDeactivated(reason: Int) {
        // Called when the reader moves away — no cleanup needed
    }
}
