package com.roomfinder.android.activities

import android.animation.AnimatorSet
import android.animation.ObjectAnimator
import android.content.Context
import android.content.Intent
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.net.NetworkRequest
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.text.Editable
import android.text.TextWatcher
import android.util.Patterns
import android.view.View
import android.view.inputmethod.EditorInfo
import android.widget.*
import androidx.appcompat.app.AppCompatActivity
import androidx.biometric.BiometricManager
import androidx.biometric.BiometricPrompt
import androidx.core.content.ContextCompat
import androidx.lifecycle.lifecycleScope
import com.google.android.material.button.MaterialButton
import com.google.android.material.textfield.TextInputEditText
import com.google.android.material.textfield.TextInputLayout
import com.roomfinder.android.R
import com.roomfinder.android.utils.BiometricUtils
import com.roomfinder.android.utils.NetworkUtils
import com.roomfinder.android.utils.PasswordStrengthCalculator
import com.roomfinder.android.utils.ValidationUtils
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import java.util.concurrent.Executor

class EnhancedLoginActivity : AppCompatActivity() {
    
    // UI Components
    private lateinit var biometricSection: LinearLayout
    private lateinit var biometricButton: MaterialButton
    private lateinit var nameLayout: TextInputLayout
    private lateinit var emailLayout: TextInputLayout
    private lateinit var passwordLayout: TextInputLayout
    private lateinit var confirmPasswordLayout: TextInputLayout
    private lateinit var passwordStrengthContainer: LinearLayout
    private lateinit var passwordStrengthBar: ProgressBar
    private lateinit var passwordStrengthText: TextView
    private lateinit var networkStatus: LinearLayout
    private lateinit var termsContainer: LinearLayout
    private lateinit var termsCheck: CheckBox
    
    private lateinit var nameInput: TextInputEditText
    private lateinit var emailInput: TextInputEditText
    private lateinit var passwordInput: TextInputEditText
    private lateinit var confirmPasswordInput: TextInputEditText
    
    private lateinit var actionButton: MaterialButton
    private lateinit var toggleButton: TextView
    private lateinit var forgotPassword: TextView
    private lateinit var skipButton: TextView
    private lateinit var googleButton: MaterialButton
    private lateinit var appleButton: MaterialButton
    
    // State
    private var isSignupMode = false
    private var isLoading = false
    private var isNetworkAvailable = true
    private var passwordStrength = 0
    private var rateLimitUntil = 0L
    
    // Utils
    private lateinit var biometricUtils: BiometricUtils
    private lateinit var passwordStrengthCalculator: PasswordStrengthCalculator
    private lateinit var validationUtils: ValidationUtils
    private lateinit var networkUtils: NetworkUtils
    
    // Biometric
    private lateinit var executor: Executor
    private lateinit var biometricPrompt: BiometricPrompt
    private lateinit var promptInfo: BiometricPrompt.PromptInfo
    
    // Network
    private lateinit var connectivityManager: ConnectivityManager
    private lateinit var networkCallback: ConnectivityManager.NetworkCallback
    
    // Common email domains for auto-completion
    private val commonDomains = listOf("gmail.com", "yahoo.com", "outlook.com", "hotmail.com", "icloud.com")
    
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_login)
        
        initializeComponents()
        setupUI()
        setupBiometric()
        setupNetworkMonitoring()
        setupValidation()
        setupEventListeners()
        
        // Check for existing biometric credentials
        checkBiometricAvailability()
    }
    
    private fun initializeComponents() {
        // Initialize UI components
        biometricSection = findViewById(R.id.biometricSection)
        biometricButton = findViewById(R.id.biometricButton)
        nameLayout = findViewById(R.id.nameLayout)
        emailLayout = findViewById(R.id.emailLayout)
        passwordLayout = findViewById(R.id.passwordLayout)
        confirmPasswordLayout = findViewById(R.id.confirmPasswordLayout)
        passwordStrengthContainer = findViewById(R.id.passwordStrengthContainer)
        passwordStrengthBar = findViewById(R.id.passwordStrengthBar)
        passwordStrengthText = findViewById(R.id.passwordStrengthText)
        networkStatus = findViewById(R.id.networkStatus)
        termsContainer = findViewById(R.id.termsContainer)
        termsCheck = findViewById(R.id.termsCheck)
        
        nameInput = findViewById(R.id.nameInput)
        emailInput = findViewById(R.id.emailInput)
        passwordInput = findViewById(R.id.passwordInput)
        confirmPasswordInput = findViewById(R.id.confirmPasswordInput)
        
        actionButton = findViewById(R.id.actionButton)
        toggleButton = findViewById(R.id.toggleButton)
        forgotPassword = findViewById(R.id.forgotPassword)
        skipButton = findViewById(R.id.skipButton)
        googleButton = findViewById(R.id.googleButton)
        appleButton = findViewById(R.id.appleButton)
        
        // Initialize utilities
        biometricUtils = BiometricUtils(this)
        passwordStrengthCalculator = PasswordStrengthCalculator()
        validationUtils = ValidationUtils()
        networkUtils = NetworkUtils(this)
        
        connectivityManager = getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
    }
    
    private fun setupUI() {
        // Set initial state
        setMode(signup = false)
        
        // Setup IME actions
        nameInput.setOnEditorActionListener { _, actionId, _ ->
            if (actionId == EditorInfo.IME_ACTION_NEXT) {
                emailInput.requestFocus()
                true
            } else false
        }
        
        emailInput.setOnEditorActionListener { _, actionId, _ ->
            if (actionId == EditorInfo.IME_ACTION_NEXT) {
                passwordInput.requestFocus()
                true
            } else false
        }
        
        passwordInput.setOnEditorActionListener { _, actionId, _ ->
            if (actionId == EditorInfo.IME_ACTION_DONE && !isSignupMode) {
                if (validateForm()) {
                    performLogin()
                }
                true
            } else if (actionId == EditorInfo.IME_ACTION_DONE && isSignupMode) {
                confirmPasswordInput.requestFocus()
                true
            } else false
        }
        
        confirmPasswordInput.setOnEditorActionListener { _, actionId, _ ->
            if (actionId == EditorInfo.IME_ACTION_DONE && isSignupMode) {
                if (validateForm()) {
                    performSignup()
                }
                true
            } else false
        }
    }
    
    private fun setupBiometric() {
        executor = ContextCompat.getMainExecutor(this)
        biometricPrompt = BiometricPrompt(this, executor, object : BiometricPrompt.AuthenticationCallback() {
            override fun onAuthenticationError(errorCode: Int, errString: CharSequence) {
                super.onAuthenticationError(errorCode, errString)
                showError("Biometric authentication error: $errString")
            }
            
            override fun onAuthenticationSucceeded(result: BiometricPrompt.AuthenticationResult) {
                super.onAuthenticationSucceeded(result)
                performBiometricLogin()
            }
            
            override fun onAuthenticationFailed() {
                super.onAuthenticationFailed()
                showError("Authentication failed")
            }
        })
        
        promptInfo = BiometricPrompt.PromptInfo.Builder()
            .setTitle(getString(R.string.biometric_login_title))
            .setSubtitle(getString(R.string.biometric_login_subtitle))
            .setNegativeButtonText(getString(R.string.use_password))
            .build()
    }
    
    private fun setupNetworkMonitoring() {
        networkCallback = object : ConnectivityManager.NetworkCallback() {
            override fun onAvailable(network: Network) {
                runOnUiThread {
                    isNetworkAvailable = true
                    networkStatus.visibility = View.GONE
                    updateButtonState()
                }
            }
            
            override fun onLost(network: Network) {
                runOnUiThread {
                    isNetworkAvailable = false
                    networkStatus.visibility = View.VISIBLE
                    updateButtonState()
                }
            }
        }
        
        val networkRequest = NetworkRequest.Builder()
            .addCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
            .build()
        
        connectivityManager.registerNetworkCallback(networkRequest, networkCallback)
    }
    
    private fun setupValidation() {
        val textWatcher = object : TextWatcher {
            override fun beforeTextChanged(s: CharSequence?, start: Int, count: Int, after: Int) {}
            override fun onTextChanged(s: CharSequence?, start: Int, before: Int, count: Int) {}
            override fun afterTextChanged(s: Editable?) {
                Handler(Looper.getMainLooper()).postDelayed({
                    validateForm()
                }, 300) // Debounce validation
            }
        }
        
        nameInput.addTextChangedListener(textWatcher)
        emailInput.addTextChangedListener(textWatcher)
        passwordInput.addTextChangedListener(textWatcher)
        confirmPasswordInput.addTextChangedListener(textWatcher)
        
        // Email domain suggestion
        emailInput.addTextChangedListener(object : TextWatcher {
            override fun beforeTextChanged(s: CharSequence?, start: Int, count: Int, after: Int) {}
            override fun onTextChanged(s: CharSequence?, start: Int, before: Int, count: Int) {}
            override fun afterTextChanged(s: Editable?) {
                suggestEmailDomain(s.toString())
            }
        })
        
        // Password strength indicator
        passwordInput.addTextChangedListener(object : TextWatcher {
            override fun beforeTextChanged(s: CharSequence?, start: Int, count: Int, after: Int) {}
            override fun onTextChanged(s: CharSequence?, start: Int, before: Int, count: Int) {}
            override fun afterTextChanged(s: Editable?) {
                if (isSignupMode) {
                    updatePasswordStrength(s.toString())
                }
            }
        })
        
        // Show/hide password strength on focus
        passwordInput.setOnFocusChangeListener { _, hasFocus ->
            if (isSignupMode) {
                passwordStrengthContainer.visibility = if (hasFocus) View.VISIBLE else View.GONE
            }
        }
    }
    
    private fun setupEventListeners() {
        toggleButton.setOnClickListener {
            setMode(!isSignupMode)
        }
        
        actionButton.setOnClickListener {
            if (rateLimitUntil > System.currentTimeMillis()) {
                val remainingSeconds = (rateLimitUntil - System.currentTimeMillis()) / 1000
                showError(getString(R.string.rate_limit_message, remainingSeconds))
                return@setOnClickListener
            }
            
            if (!validateForm()) return@setOnClickListener
            
            if (isSignupMode) {
                performSignup()
            } else {
                performLogin()
            }
        }
        
        biometricButton.setOnClickListener {
            biometricPrompt.authenticate(promptInfo)
        }
        
        forgotPassword.setOnClickListener {
            showForgotPasswordDialog()
        }
        
        skipButton.setOnClickListener {
            continueAsGuest()
        }
        
        googleButton.setOnClickListener {
            performGoogleSignIn()
        }
        
        appleButton.setOnClickListener {
            performAppleSignIn()
        }
        
        termsCheck.setOnCheckedChangeListener { _, _ ->
            updateButtonState()
        }
    }
    
    private fun setMode(signup: Boolean) {
        isSignupMode = signup
        
        // Update visibility
        nameLayout.visibility = if (signup) View.VISIBLE else View.GONE
        confirmPasswordLayout.visibility = if (signup) View.VISIBLE else View.GONE
        termsContainer.visibility = if (signup) View.VISIBLE else View.GONE
        passwordStrengthContainer.visibility = if (signup && passwordInput.hasFocus()) View.VISIBLE else View.GONE
        
        // Update text
        actionButton.text = getString(if (signup) R.string.signup else R.string.login)
        toggleButton.text = getString(if (signup) R.string.have_account else R.string.dont_have_account)
        
        // Animate transition
        animateTransition()
        
        // Clear errors and validate
        clearErrors()
        validateForm()
    }
    
    private fun animateTransition() {
        val fadeOut = ObjectAnimator.ofFloat(actionButton, "alpha", 1f, 0.7f)
        val fadeIn = ObjectAnimator.ofFloat(actionButton, "alpha", 0.7f, 1f)
        
        val animatorSet = AnimatorSet()
        animatorSet.playSequentially(fadeOut, fadeIn)
        animatorSet.duration = 200
        animatorSet.start()
    }
    
    private fun validateForm(): Boolean {
        var isValid = true
        
        clearErrors()
        
        // Name validation (signup only)
        if (isSignupMode) {
            val name = nameInput.text?.toString()?.trim() ?: ""
            if (name.isEmpty()) {
                nameLayout.error = getString(R.string.error_name_required)
                isValid = false
            } else if (name.length < 2) {
                nameLayout.error = getString(R.string.error_name_too_short)
                isValid = false
            }
        }
        
        // Email validation
        val email = emailInput.text?.toString()?.trim() ?: ""
        if (email.isEmpty()) {
            emailLayout.error = getString(R.string.error_email_required)
            isValid = false
        } else if (!Patterns.EMAIL_ADDRESS.matcher(email).matches()) {
            emailLayout.error = getString(R.string.error_email_invalid)
            isValid = false
        } else if (validationUtils.isDisposableEmail(email)) {
            emailLayout.error = getString(R.string.error_email_disposable)
            isValid = false
        }
        
        // Password validation
        val password = passwordInput.text?.toString() ?: ""
        if (password.isEmpty()) {
            passwordLayout.error = getString(R.string.error_password_required)
            isValid = false
        } else if (password.length < 8) {
            passwordLayout.error = getString(R.string.error_password_too_short)
            isValid = false
        } else if (isSignupMode && passwordStrength < 2) {
            passwordLayout.error = getString(R.string.error_password_weak)
            isValid = false
        }
        
        // Confirm password validation (signup only)
        if (isSignupMode) {
            val confirmPassword = confirmPasswordInput.text?.toString() ?: ""
            if (confirmPassword.isEmpty()) {
                confirmPasswordLayout.error = getString(R.string.error_confirm_password_required)
                isValid = false
            } else if (password != confirmPassword) {
                confirmPasswordLayout.error = getString(R.string.error_passwords_dont_match)
                isValid = false
            }
            
            // Terms validation
            if (!termsCheck.isChecked) {
                isValid = false
            }
        }
        
        updateButtonState()
        return isValid
    }
    
    private fun clearErrors() {
        nameLayout.error = null
        emailLayout.error = null
        passwordLayout.error = null
        confirmPasswordLayout.error = null
    }
    
    private fun updateButtonState() {
        val isFormValid = when {
            !isNetworkAvailable -> false
            isLoading -> false
            rateLimitUntil > System.currentTimeMillis() -> false
            isSignupMode -> {
                val name = nameInput.text?.toString()?.trim() ?: ""
                val email = emailInput.text?.toString()?.trim() ?: ""
                val password = passwordInput.text?.toString() ?: ""
                val confirmPassword = confirmPasswordInput.text?.toString() ?: ""
                
                name.isNotEmpty() && 
                email.isNotEmpty() && 
                Patterns.EMAIL_ADDRESS.matcher(email).matches() &&
                password.length >= 8 && 
                password == confirmPassword && 
                termsCheck.isChecked
            }
            else -> {
                val email = emailInput.text?.toString()?.trim() ?: ""
                val password = passwordInput.text?.toString() ?: ""
                
                email.isNotEmpty() && 
                Patterns.EMAIL_ADDRESS.matcher(email).matches() &&
                password.isNotEmpty()
            }
        }
        
        actionButton.isEnabled = isFormValid && !isLoading
        actionButton.alpha = if (isFormValid && !isLoading) 1.0f else 0.6f
    }
    
    private fun updatePasswordStrength(password: String) {
        passwordStrength = passwordStrengthCalculator.calculateStrength(password)
        
        passwordStrengthBar.progress = passwordStrength
        
        val (colorResId, textResId) = when (passwordStrength) {
            0 -> Pair(R.color.password_strength_very_weak, R.string.password_very_weak)
            1 -> Pair(R.color.password_strength_weak, R.string.password_weak)
            2 -> Pair(R.color.password_strength_fair, R.string.password_fair)
            3 -> Pair(R.color.password_strength_good, R.string.password_good)
            4 -> Pair(R.color.password_strength_strong, R.string.password_strong)
            else -> Pair(R.color.password_strength_weak, R.string.password_weak)
        }
        
        passwordStrengthBar.progressTintList = ContextCompat.getColorStateList(this, colorResId)
        passwordStrengthText.text = getString(textResId)
        passwordStrengthText.setTextColor(ContextCompat.getColor(this, colorResId))
    }
    
    private fun suggestEmailDomain(email: String) {
        if (!email.contains("@") || email.endsWith("@")) {
            return
        }
        
        val parts = email.split("@")
        if (parts.size == 2) {
            val domain = parts[1]
            val suggestion = commonDomains.find { it.startsWith(domain, ignoreCase = true) }
            
            if (suggestion != null && domain != suggestion) {
                emailLayout.helperText = getString(R.string.email_suggestion, "${parts[0]}@$suggestion")
            } else {
                emailLayout.helperText = getString(R.string.email_helper)
            }
        }
    }
    
    private fun checkBiometricAvailability() {
        when (BiometricManager.from(this).canAuthenticate(BiometricManager.Authenticators.BIOMETRIC_STRONG)) {
            BiometricManager.BIOMETRIC_SUCCESS -> {
                // Check if user has previously logged in with biometrics
                if (biometricUtils.hasBiometricCredentials()) {
                    biometricSection.visibility = View.VISIBLE
                }
            }
            else -> {
                biometricSection.visibility = View.GONE
            }
        }
    }
    
    private fun performLogin() {
        if (isLoading) return
        
        setLoadingState(true)
        val email = emailInput.text?.toString()?.trim() ?: ""
        val password = passwordInput.text?.toString() ?: ""
        
        lifecycleScope.launch {
            try {
                // Simulate network call
                delay(2000)
                
                // TODO: Replace with actual authentication logic
                if (authenticateUser(email, password)) {
                    // Save biometric credentials if available
                    if (BiometricManager.from(this@EnhancedLoginActivity)
                            .canAuthenticate(BiometricManager.Authenticators.BIOMETRIC_STRONG) == BiometricManager.BIOMETRIC_SUCCESS) {
                        biometricUtils.saveBiometricCredentials(email)
                    }
                    
                    navigateToMainActivity()
                } else {
                    setRateLimit()
                    showError(getString(R.string.login_failed))
                }
            } catch (e: Exception) {
                showError(getString(R.string.network_error))
            } finally {
                setLoadingState(false)
            }
        }
    }
    
    private fun performSignup() {
        if (isLoading) return
        
        setLoadingState(true)
        val name = nameInput.text?.toString()?.trim() ?: ""
        val email = emailInput.text?.toString()?.trim() ?: ""
        val password = passwordInput.text?.toString() ?: ""
        
        lifecycleScope.launch {
            try {
                // Simulate network call
                delay(2500)
                
                // TODO: Replace with actual registration logic
                if (registerUser(name, email, password)) {
                    showSuccess(getString(R.string.signup_success))
                    setMode(signup = false)
                } else {
                    setRateLimit()
                    showError(getString(R.string.signup_failed))
                }
            } catch (e: Exception) {
                showError(getString(R.string.network_error))
            } finally {
                setLoadingState(false)
            }
        }
    }
    
    private fun performBiometricLogin() {
        lifecycleScope.launch {
            try {
                val credentials = biometricUtils.getBiometricCredentials()
                if (credentials != null) {
                    // TODO: Use saved credentials to authenticate
                    navigateToMainActivity()
                } else {
                    showError(getString(R.string.biometric_credentials_not_found))
                }
            } catch (e: Exception) {
                showError(getString(R.string.biometric_login_failed))
            }
        }
    }
    
    private fun performGoogleSignIn() {
        // TODO: Implement Google Sign-In
        showComingSoon("Google Sign-In")
    }
    
    private fun performAppleSignIn() {
        // TODO: Implement Apple Sign-In
        showComingSoon("Apple Sign-In")
    }
    
    private fun showForgotPasswordDialog() {
        // TODO: Implement forgot password flow
        showComingSoon("Forgot Password")
    }
    
    private fun continueAsGuest() {
        // TODO: Implement guest mode
        navigateToMainActivity()
    }
    
    private fun setLoadingState(loading: Boolean) {
        isLoading = loading
        actionButton.isEnabled = !loading
        
        if (loading) {
            actionButton.text = getString(R.string.loading)
            actionButton.setIconResource(R.drawable.ic_loading)
        } else {
            actionButton.text = getString(if (isSignupMode) R.string.signup else R.string.login)
            actionButton.icon = null
        }
        
        // Disable inputs during loading
        nameInput.isEnabled = !loading
        emailInput.isEnabled = !loading
        passwordInput.isEnabled = !loading
        confirmPasswordInput.isEnabled = !loading
        googleButton.isEnabled = !loading
        appleButton.isEnabled = !loading
        biometricButton.isEnabled = !loading
    }
    
    private fun setRateLimit() {
        rateLimitUntil = System.currentTimeMillis() + (60 * 1000) // 1 minute
    }
    
    private fun showError(message: String) {
        Toast.makeText(this, message, Toast.LENGTH_LONG).show()
    }
    
    private fun showSuccess(message: String) {
        Toast.makeText(this, message, Toast.LENGTH_LONG).show()
    }
    
    private fun showComingSoon(feature: String) {
        Toast.makeText(this, "$feature coming soon!", Toast.LENGTH_SHORT).show()
    }
    
    private fun navigateToMainActivity() {
        // TODO: Navigate to main activity
        finish()
    }
    
    // Mock authentication methods - replace with actual implementation
    private suspend fun authenticateUser(email: String, password: String): Boolean {
        // Mock implementation
        return email.isNotEmpty() && password.length >= 8
    }
    
    private suspend fun registerUser(name: String, email: String, password: String): Boolean {
        // Mock implementation
        return name.isNotEmpty() && email.isNotEmpty() && password.length >= 8
    }
    
    override fun onDestroy() {
        super.onDestroy()
        connectivityManager.unregisterNetworkCallback(networkCallback)
    }
}