package com.amirani.amirani_app

import android.content.SharedPreferences
import android.nfc.cardemulation.HostApduService
import android.os.Bundle
import android.util.Log

/**
 * Amirani HCE (Host Card Emulation) Service
 *
 * Makes the Android phone behave like an NFC card at the gym entrance.
 *
 * Protocol:
 *   1. Pi sends SELECT AID  → [00 A4 04 00 07 F0 4D 49 52 41 4E 49 00]
 *   2. We respond           → [90 00]
 *   3. Pi sends GET CRED    → [00 CA 00 00 08]
 *   4. We respond           → [<8-byte credential> 90 00]
 *
 * The 8-byte credential is generated once, stored in SharedPreferences,
 * and enrolled to the backend via the Flutter layer (NfcHceService.dart).
 *
 * AID: F0 4D 49 52 41 4E 49  (proprietary prefix F0 + "MIRANI")
 */
class AmiraniHceService : HostApduService() {

    companion object {
        private const val TAG = "AmiraniHCE"

        // AID = F0 + "MIRANI" (7 bytes)
        val AID = byteArrayOf(
            0xF0.toByte(), 0x4D.toByte(), 0x49.toByte(), 0x52.toByte(),
            0x41.toByte(), 0x4E.toByte(), 0x49.toByte()
        )

        // GET CREDENTIAL APDU: CLA=00 INS=CA P1=00 P2=00 Le=08
        val GET_CREDENTIAL_APDU = byteArrayOf(
            0x00.toByte(), 0xCA.toByte(), 0x00.toByte(), 0x00.toByte(), 0x08.toByte()
        )

        val SW_OK            = byteArrayOf(0x90.toByte(), 0x00.toByte())
        val SW_UNKNOWN_INS   = byteArrayOf(0x6D.toByte(), 0x00.toByte())
        val SW_CONDITIONS    = byteArrayOf(0x69.toByte(), 0x85.toByte()) // Conditions not satisfied
        val SW_NOT_FOUND     = byteArrayOf(0x6A.toByte(), 0x82.toByte()) // Application not found

        const val PREFS_NAME    = "amirani_hce"
        const val KEY_CREDENTIAL = "hce_credential"
        const val KEY_ENABLED    = "hce_enabled"

        /** Generate a cryptographically random 8-byte credential (hex string). */
        fun generateCredential(): String {
            val bytes = ByteArray(8)
            java.security.SecureRandom().nextBytes(bytes)
            return bytes.joinToString("") { "%02X".format(it) }
        }
    }

    // Track whether our AID was selected in this NFC session
    private var aidSelected = false

    override fun processCommandApdu(commandApdu: ByteArray, extras: Bundle?): ByteArray {
        Log.d(TAG, "APDU ← ${commandApdu.toHex()}")

        // ── SELECT AID ──────────────────────────────────────────────────────
        // Frame: 00 A4 04 00 <len> <AID bytes> [00]
        if (commandApdu.size >= 6 &&
            commandApdu[0] == 0x00.toByte() &&
            commandApdu[1] == 0xA4.toByte() &&
            commandApdu[2] == 0x04.toByte()
        ) {
            val aidOffset = 5
            val aidLen = commandApdu[4].toInt() and 0xFF
            if (aidLen == AID.size &&
                commandApdu.size >= aidOffset + aidLen &&
                commandApdu.sliceArray(aidOffset until aidOffset + aidLen).contentEquals(AID)
            ) {
                val prefs = getPrefs()
                if (prefs.getBoolean(KEY_ENABLED, false) && prefs.contains(KEY_CREDENTIAL)) {
                    aidSelected = true
                    Log.i(TAG, "AID selected — HCE active")
                    return SW_OK
                }
                // Phone key not enrolled/enabled
                return SW_NOT_FOUND
            }
            return SW_NOT_FOUND
        }

        // ── GET CREDENTIAL ───────────────────────────────────────────────────
        if (aidSelected && commandApdu.contentEquals(GET_CREDENTIAL_APDU)) {
            val credHex = getPrefs().getString(KEY_CREDENTIAL, null)
            return if (credHex != null && credHex.length == 16) {
                val credBytes = credHex.chunked(2).map { it.toInt(16).toByte() }.toByteArray()
                Log.i(TAG, "Sending credential: $credHex")
                credBytes + SW_OK
            } else {
                SW_CONDITIONS
            }
        }

        return SW_UNKNOWN_INS
    }

    override fun onDeactivated(reason: Int) {
        aidSelected = false
        val reasonStr = when (reason) {
            DEACTIVATION_LINK_LOSS -> "link loss"
            DEACTIVATION_DESELECTED -> "deselected"
            else -> "unknown($reason)"
        }
        Log.d(TAG, "HCE deactivated: $reasonStr")
    }

    private fun getPrefs(): SharedPreferences =
        getSharedPreferences(PREFS_NAME, MODE_PRIVATE)

    private fun ByteArray.toHex() = joinToString(" ") { "%02X".format(it) }
}
