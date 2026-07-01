package com.roomfinder.android.utils

import java.util.regex.Pattern

class PasswordStrengthCalculator {
    
    private val commonPasswords = setOf(
        "password", "123456", "password123", "admin", "qwerty", 
        "letmein", "welcome", "monkey", "1234567890", "abc123",
        "password1", "12345678", "123456789", "welcome123"
    )
    
    fun calculateStrength(password: String): Int {
        if (password.isEmpty()) return 0
        
        var score = 0
        val checks = mutableListOf<Boolean>()
        
        // Length checks
        checks.add(password.length >= 8) // Minimum length
        checks.add(password.length >= 12) // Good length
        
        // Character variety checks
        checks.add(password.any { it.isLowerCase() }) // Lowercase
        checks.add(password.any { it.isUpperCase() }) // Uppercase
        checks.add(password.any { it.isDigit() }) // Numbers
        checks.add(password.any { !it.isLetterOrDigit() }) // Special characters
        
        // Pattern checks
        checks.add(!hasRepeatingCharacters(password)) // No repeating chars
        checks.add(!hasSequentialCharacters(password)) // No sequential chars
        checks.add(!isCommonPassword(password.lowercase())) // Not common password
        checks.add(!containsPersonalInfo(password)) // No obvious personal info
        
        // Calculate score based on checks passed
        score = checks.count { it }
        
        // Bonus points for very long passwords
        if (password.length >= 16) score += 1
        if (password.length >= 20) score += 1
        
        // Penalty for very short passwords
        if (password.length < 6) score = 0
        
        // Normalize to 0-4 scale
        return when {
            score <= 2 -> 0 // Very weak
            score <= 4 -> 1 // Weak
            score <= 6 -> 2 // Fair
            score <= 8 -> 3 // Good
            else -> 4 // Strong
        }
    }
    
    fun getStrengthDescription(strength: Int): String {
        return when (strength) {
            0 -> "Very Weak"
            1 -> "Weak"
            2 -> "Fair"
            3 -> "Good"
            4 -> "Strong"
            else -> "Unknown"
        }
    }
    
    fun getStrengthSuggestions(password: String): List<String> {
        val suggestions = mutableListOf<String>()
        
        if (password.length < 8) {
            suggestions.add("Use at least 8 characters")
        }
        
        if (!password.any { it.isLowerCase() }) {
            suggestions.add("Add lowercase letters")
        }
        
        if (!password.any { it.isUpperCase() }) {
            suggestions.add("Add uppercase letters")
        }
        
        if (!password.any { it.isDigit() }) {
            suggestions.add("Add numbers")
        }
        
        if (!password.any { !it.isLetterOrDigit() }) {
            suggestions.add("Add special characters (!@#$%^&*)")
        }
        
        if (hasRepeatingCharacters(password)) {
            suggestions.add("Avoid repeating characters")
        }
        
        if (hasSequentialCharacters(password)) {
            suggestions.add("Avoid sequential characters (123, abc)")
        }
        
        if (isCommonPassword(password.lowercase())) {
            suggestions.add("Avoid common passwords")
        }
        
        if (password.length >= 12 && suggestions.isEmpty()) {
            suggestions.add("Excellent password strength!")
        }
        
        return suggestions
    }
    
    private fun hasRepeatingCharacters(password: String): Boolean {
        var repeatCount = 1
        for (i in 1 until password.length) {
            if (password[i] == password[i - 1]) {
                repeatCount++
                if (repeatCount >= 3) return true
            } else {
                repeatCount = 1
            }
        }
        return false
    }
    
    private fun hasSequentialCharacters(password: String): Boolean {
        val sequences = listOf(
            "0123456789", "abcdefghijklmnopqrstuvwxyz", "qwertyuiop", "asdfghjkl", "zxcvbnm"
        )
        
        val lowerPassword = password.lowercase()
        
        for (sequence in sequences) {
            for (i in 0..sequence.length - 3) {
                val subSeq = sequence.substring(i, i + 3)
                if (lowerPassword.contains(subSeq) || lowerPassword.contains(subSeq.reversed())) {
                    return true
                }
            }
        }
        
        return false
    }
    
    private fun isCommonPassword(password: String): Boolean {
        return commonPasswords.contains(password) || 
               commonPasswords.any { password.contains(it) }
    }
    
    private fun containsPersonalInfo(password: String): Boolean {
        // Basic check for obvious personal info patterns
        val personalPatterns = listOf(
            Pattern.compile("(19|20)\\d{2}"), // Years
            Pattern.compile("\\b(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)\\b", Pattern.CASE_INSENSITIVE), // Months
            Pattern.compile("\\b(monday|tuesday|wednesday|thursday|friday|saturday|sunday)\\b", Pattern.CASE_INSENSITIVE) // Days
        )
        
        return personalPatterns.any { it.matcher(password).find() }
    }
    
    fun estimateCrackTime(password: String): String {
        val strength = calculateStrength(password)
        val charsetSize = getCharsetSize(password)
        val combinations = Math.pow(charsetSize.toDouble(), password.length.toDouble())
        
        // Rough estimation based on modern computing power
        val attemptsPerSecond = 1_000_000_000L // 1 billion attempts per second
        val seconds = combinations / (2 * attemptsPerSecond) // Average case
        
        return when {
            seconds < 1 -> "Instant"
            seconds < 60 -> "${seconds.toInt()} seconds"
            seconds < 3600 -> "${(seconds / 60).toInt()} minutes"
            seconds < 86400 -> "${(seconds / 3600).toInt()} hours"
            seconds < 31536000 -> "${(seconds / 86400).toInt()} days"
            else -> "${(seconds / 31536000).toInt()} years"
        }
    }
    
    private fun getCharsetSize(password: String): Int {
        var size = 0
        if (password.any { it.isLowerCase() }) size += 26
        if (password.any { it.isUpperCase() }) size += 26
        if (password.any { it.isDigit() }) size += 10
        if (password.any { !it.isLetterOrDigit() }) size += 32 // Approximate special chars
        return size
    }
}