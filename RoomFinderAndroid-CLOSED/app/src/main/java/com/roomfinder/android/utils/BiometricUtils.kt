package com.roomfinder.android.utils

import android.content.Context
import android.content.SharedPreferences
import androidx.biometric.BiometricManager
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKeys

class BiometricUtils(private val context: Context) {
    
    private val sharedPreferences: SharedPreferences by lazy {
        try {
            val masterKeyAlias = MasterKeys.getOrCreate(MasterKeys.AES256_GCM_SPEC)
            EncryptedSharedPreferences.create(
                PREF_NAME,
                masterKeyAlias,
                context,
                EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
                EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM
            )
        } catch (e: Exception) {
            // Fallback to regular SharedPreferences if encryption fails
            context.getSharedPreferences(PREF_NAME, Context.MODE_PRIVATE)
        }
    }
    
    fun canUseBiometric(): Boolean {
        return when (BiometricManager.from(context).canAuthenticate(BiometricManager.Authenticators.BIOMETRIC_STRONG)) {
            BiometricManager.BIOMETRIC_SUCCESS -> true
            else -> false
        }
    }
    
    fun hasBiometricCredentials(): Boolean {
        return sharedPreferences.contains(KEY_BIOMETRIC_EMAIL) && 
               sharedPreferences.getBoolean(KEY_BIOMETRIC_ENABLED, false)
    }
    
    fun saveBiometricCredentials(email: String) {
        sharedPreferences.edit()
            .putString(KEY_BIOMETRIC_EMAIL, email)
            .putBoolean(KEY_BIOMETRIC_ENABLED, true)
            .putLong(KEY_BIOMETRIC_TIMESTAMP, System.currentTimeMillis())
            .apply()
    }
    
    fun getBiometricCredentials(): BiometricCredentials? {
        if (!hasBiometricCredentials()) return null
        
        val email = sharedPreferences.getString(KEY_BIOMETRIC_EMAIL, null)
        val timestamp = sharedPreferences.getLong(KEY_BIOMETRIC_TIMESTAMP, 0L)
        
        return if (email != null) {
            BiometricCredentials(email, timestamp)
        } else null
    }
    
    fun clearBiometricCredentials() {
        sharedPreferences.edit()
            .remove(KEY_BIOMETRIC_EMAIL)
            .putBoolean(KEY_BIOMETRIC_ENABLED, false)
            .remove(KEY_BIOMETRIC_TIMESTAMP)
            .apply()
    }
    
    fun isBiometricExpired(expirationDays: Int = 30): Boolean {
        val timestamp = sharedPreferences.getLong(KEY_BIOMETRIC_TIMESTAMP, 0L)
        val expirationTime = timestamp + (expirationDays * 24 * 60 * 60 * 1000L)
        return System.currentTimeMillis() > expirationTime
    }
    
    companion object {
        private const val PREF_NAME = "biometric_prefs"
        private const val KEY_BIOMETRIC_EMAIL = "biometric_email"
        private const val KEY_BIOMETRIC_ENABLED = "biometric_enabled"
        private const val KEY_BIOMETRIC_TIMESTAMP = "biometric_timestamp"
    }
    
    data class BiometricCredentials(
        val email: String,
        val timestamp: Long
    )
}