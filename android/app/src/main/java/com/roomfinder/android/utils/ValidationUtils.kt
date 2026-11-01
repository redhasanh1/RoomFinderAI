package com.roomfinder.android.utils

import android.util.Patterns
import java.util.regex.Pattern

class ValidationUtils {
    
    // Common disposable email domains
    private val disposableDomains = setOf(
        "10minutemail.com", "guerrillamail.com", "mailinator.com", 
        "tempmail.org", "throwaway.email", "getnada.com",
        "maildrop.cc", "temp-mail.org", "sharklasers.com"
    )
    
    fun isValidEmail(email: String): Boolean {
        return email.isNotEmpty() && Patterns.EMAIL_ADDRESS.matcher(email).matches()
    }
    
    fun isDisposableEmail(email: String): Boolean {
        if (!isValidEmail(email)) return false
        
        val domain = email.substringAfter("@").lowercase()
        return disposableDomains.contains(domain)
    }
    
    fun isValidName(name: String): Boolean {
        if (name.trim().length < 2) return false
        if (name.trim().length > 50) return false
        
        // Check for valid name characters (letters, spaces, hyphens, apostrophes)
        val namePattern = Pattern.compile("^[a-zA-Z\\s\\-']+$")
        return namePattern.matcher(name.trim()).matches()
    }
    
    fun isValidPassword(password: String): Boolean {
        return password.length >= 8
    }
    
    fun isStrongPassword(password: String): Boolean {
        if (password.length < 8) return false
        
        val hasLower = password.any { it.isLowerCase() }
        val hasUpper = password.any { it.isUpperCase() }
        val hasDigit = password.any { it.isDigit() }
        val hasSpecial = password.any { !it.isLetterOrDigit() }
        
        return hasLower && hasUpper && hasDigit && hasSpecial
    }
    
    fun validateEmailFormat(email: String): ValidationResult {
        return when {
            email.isEmpty() -> ValidationResult.Invalid("Email is required")
            !Patterns.EMAIL_ADDRESS.matcher(email).matches() -> ValidationResult.Invalid("Invalid email format")
            isDisposableEmail(email) -> ValidationResult.Invalid("Please use a permanent email address")
            email.length > 254 -> ValidationResult.Invalid("Email is too long")
            else -> ValidationResult.Valid
        }
    }
    
    fun validatePasswordStrength(password: String): ValidationResult {
        return when {
            password.isEmpty() -> ValidationResult.Invalid("Password is required")
            password.length < 8 -> ValidationResult.Invalid("Password must be at least 8 characters")
            password.length > 128 -> ValidationResult.Invalid("Password is too long")
            isWeakPassword(password) -> ValidationResult.Invalid("Password is too weak")
            else -> ValidationResult.Valid
        }
    }
    
    fun validateNameFormat(name: String): ValidationResult {
        val trimmedName = name.trim()
        return when {
            trimmedName.isEmpty() -> ValidationResult.Invalid("Name is required")
            trimmedName.length < 2 -> ValidationResult.Invalid("Name must be at least 2 characters")
            trimmedName.length > 50 -> ValidationResult.Invalid("Name is too long")
            !isValidName(trimmedName) -> ValidationResult.Invalid("Name contains invalid characters")
            containsProfanity(trimmedName) -> ValidationResult.Invalid("Name contains inappropriate content")
            else -> ValidationResult.Valid
        }
    }
    
    fun validatePasswordMatch(password: String, confirmPassword: String): ValidationResult {
        return when {
            confirmPassword.isEmpty() -> ValidationResult.Invalid("Please confirm your password")
            password != confirmPassword -> ValidationResult.Invalid("Passwords don't match")
            else -> ValidationResult.Valid
        }
    }
    
    private fun isWeakPassword(password: String): Boolean {
        val weakPatterns = listOf(
            Pattern.compile("^\\d+$"), // Only numbers
            Pattern.compile("^[a-zA-Z]+$"), // Only letters
            Pattern.compile("^(.)\\1{7,}$"), // Repeating characters
            Pattern.compile("^(password|123456|qwerty)", Pattern.CASE_INSENSITIVE), // Common passwords
            Pattern.compile("^(abc|123|qwe)"), // Sequential patterns
        )
        
        return weakPatterns.any { it.matcher(password).find() }
    }
    
    private fun containsProfanity(text: String): Boolean {
        // Basic profanity filter - implement more sophisticated filtering as needed
        val profanityWords = setOf("badword1", "badword2") // Add actual words as needed
        val lowerText = text.lowercase()
        return profanityWords.any { lowerText.contains(it) }
    }
    
    fun sanitizeInput(input: String): String {
        return input.trim()
            .replace(Regex("[<>\"'&]"), "") // Remove potentially dangerous characters
            .take(255) // Limit length
    }
    
    fun isValidPhoneNumber(phone: String): Boolean {
        // Simple phone validation - enhance based on requirements
        val phonePattern = Pattern.compile("^\\+?[1-9]\\d{1,14}$")
        return phonePattern.matcher(phone.replace("[\\s\\-\\(\\)]".toRegex(), "")).matches()
    }
    
    fun getEmailSuggestion(email: String): String? {
        if (!email.contains("@")) return null
        
        val parts = email.split("@")
        if (parts.size != 2) return null
        
        val localPart = parts[0]
        val domain = parts[1].lowercase()
        
        // Common domain corrections
        val corrections = mapOf(
            "gmial.com" to "gmail.com",
            "gmai.com" to "gmail.com",
            "gmail.co" to "gmail.com",
            "yahooo.com" to "yahoo.com",
            "yahoo.co" to "yahoo.com",
            "hotmial.com" to "hotmail.com",
            "hotmail.co" to "hotmail.com",
            "outlookk.com" to "outlook.com",
            "outlook.co" to "outlook.com"
        )
        
        val correctedDomain = corrections[domain]
        return if (correctedDomain != null) {
            "$localPart@$correctedDomain"
        } else null
    }
    
    sealed class ValidationResult {
        object Valid : ValidationResult()
        data class Invalid(val message: String) : ValidationResult()
    }
}