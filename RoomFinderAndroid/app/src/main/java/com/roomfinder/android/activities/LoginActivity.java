package com.roomfinder.android.activities;

import android.content.Intent;
import android.os.Bundle;
import android.text.Editable;
import android.text.TextWatcher;
import android.util.Log;
import android.view.View;
import android.widget.Toast;
import androidx.appcompat.app.AppCompatActivity;
import com.roomfinder.android.auth.AuthManager;
import com.roomfinder.android.auth.AuthService;
import com.roomfinder.android.databinding.ActivityLoginBinding;
import com.roomfinder.android.models.User;

/**
 * LoginActivity - Exact copy of website login.html logic
 * Handles both login and signup flows with email verification
 */
public class LoginActivity extends AppCompatActivity {
    
    private static final String TAG = "LoginActivity";
    private ActivityLoginBinding binding;
    private AuthService authService;
    private AuthManager authManager;
    private boolean isLogin = true; // Start with login form (matching website)
    
    // Pending user data for verification (matching website)
    private String pendingFirstName;
    private String pendingLastName;
    private String pendingEmail;
    private String pendingPassword;
    
    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        
        binding = ActivityLoginBinding.inflate(getLayoutInflater());
        setContentView(binding.getRoot());
        
        authService = AuthService.getInstance(this);
        authManager = AuthManager.getInstance(this);
        
        // Upgrade existing users by generating tokens if they don't have them
        User currentUser = authManager.getCurrentUser();
        if (currentUser != null && (currentUser.getAccessToken() == null || currentUser.getAccessToken().isEmpty())) {
            Log.w(TAG, "Found user without valid access token, generating tokens to upgrade account");
            if (!authManager.generateTokensForUser(currentUser)) {
                Log.e(TAG, "Failed to generate tokens, clearing invalid authentication data");
                authManager.clearAllAuthData();
            } else {
                Log.d(TAG, "Successfully upgraded user account with tokens");
            }
        }
        
        // Demo accounts will only be used if no real users exist - handled automatically
        
        // Only redirect to main if user is already authenticated AND we came from main activity
        boolean fromMain = getIntent().getBooleanExtra("from_main", false);
        if (authManager.isUserAuthenticated() && fromMain) {
            navigateToMainActivity();
            return;
        }
        
        // Check if we should show signup form
        boolean showSignup = getIntent().getBooleanExtra("show_signup", false);
        if (showSignup) {
            isLogin = false;
        }
        
        setupViews();
    }
    
    private void setupViews() {
        updateFormUI();
        
        // Toggle between login and signup (matching website toggleForm logic)
        binding.toggleButton.setOnClickListener(v -> {
            isLogin = !isLogin;
            updateFormUI();
            clearForm();
        });
        
        // Main form submission (matching website form.addEventListener('submit'))
        binding.actionButton.setOnClickListener(v -> {
            if (isLogin) {
                performLogin();
            } else {
                performSignup();
            }
        });
        
        // Skip button
        binding.skipButton.setOnClickListener(v -> finish());
        
        // Add form validation (matching website real-time validation)
        setupFormValidation();
    }
    
    /**
     * Setup form validation listeners (matching website real-time validation)
     */
    private void setupFormValidation() {
        TextWatcher validationWatcher = new TextWatcher() {
            @Override
            public void beforeTextChanged(CharSequence s, int start, int count, int after) {}
            
            @Override
            public void onTextChanged(CharSequence s, int start, int before, int count) {}
            
            @Override
            public void afterTextChanged(Editable s) {
                validateForm();
            }
        };
        
        // Add watchers to all input fields
        binding.emailInput.addTextChangedListener(validationWatcher);
        binding.passwordInput.addTextChangedListener(validationWatcher);
        binding.nameInput.addTextChangedListener(validationWatcher);
        binding.confirmPasswordInput.addTextChangedListener(validationWatcher);
        
        // Initial validation
        validateForm();
    }
    
    /**
     * Validate form and enable/disable submit button (matching website logic)
     */
    private void validateForm() {
        boolean isValid = false;
        
        if (isLogin) {
            // Login validation: email and password required
            String email = binding.emailInput.getText().toString().trim();
            String password = binding.passwordInput.getText().toString();
            isValid = !email.isEmpty() && !password.isEmpty() && isValidEmail(email);
        } else {
            // Signup validation: all fields required + password match
            String name = binding.nameInput.getText().toString().trim();
            String email = binding.emailInput.getText().toString().trim();
            String password = binding.passwordInput.getText().toString();
            String confirmPassword = binding.confirmPasswordInput.getText().toString();
            
            isValid = !name.isEmpty() && !email.isEmpty() && !password.isEmpty() && 
                     !confirmPassword.isEmpty() && isValidEmail(email) && 
                     password.length() >= 8 && password.equals(confirmPassword);
        }
        
        // Enable/disable button based on validation
        binding.actionButton.setEnabled(isValid);
        binding.actionButton.setAlpha(isValid ? 1.0f : 0.6f);
    }
    
    /**
     * Update form UI based on isLogin state (matching website logic)
     */
    private void updateFormUI() {
        if (isLogin) {
            // Login form
            binding.titleText.setText("Welcome Back");
            binding.nameLayout.setVisibility(View.GONE);
            binding.confirmPasswordLayout.setVisibility(View.GONE);
            binding.actionButton.setText("Sign In");
            binding.toggleButton.setText("Don't have an account? Register now");
        } else {
            // Signup form
            binding.titleText.setText("Create Account");
            binding.nameLayout.setVisibility(View.VISIBLE);
            binding.confirmPasswordLayout.setVisibility(View.VISIBLE);
            binding.actionButton.setText("Create Account");
            binding.toggleButton.setText("Already have an account? Sign in");
        }
        
        // Re-validate form when switching modes
        validateForm();
    }
    
    /**
     * Clear form fields
     */
    private void clearForm() {
        binding.emailInput.setText("");
        binding.passwordInput.setText("");
        binding.nameInput.setText("");
        binding.confirmPasswordInput.setText("");
    }
    
    /**
     * Perform login (matching website login logic exactly)
     */
    private void performLogin() {
        String email = binding.emailInput.getText().toString().trim();
        String password = binding.passwordInput.getText().toString();
        
        // Basic validation (matching website)
        if (email.isEmpty() || password.isEmpty()) {
            Toast.makeText(this, "Please fill in all fields", Toast.LENGTH_SHORT).show();
            return;
        }
        
        if (!isValidEmail(email)) {
            Toast.makeText(this, "Please enter a valid email address", Toast.LENGTH_SHORT).show();
            return;
        }
        
        // Show loading state
        setLoadingState(true, "Signing in...");
        
        // Call login API (matching website fetch('/api/login'))
        authService.login(email, password, new AuthService.AuthCallback() {
            @Override
            public void onSuccess(User user) {
                Log.d(TAG, "Login successful for user: " + user.getEmail());
                setLoadingState(false, null);
                
                Toast.makeText(LoginActivity.this, "Welcome back!", Toast.LENGTH_SHORT).show();
                
                // Navigate to main activity (matching website redirect)
                navigateToMainActivity();
            }
            
            @Override
            public void onError(String error) {
                Log.e(TAG, "Login failed: " + error);
                setLoadingState(false, null);
                
                Toast.makeText(LoginActivity.this, error, Toast.LENGTH_LONG).show();
            }
        });
    }
    
    /**
     * Perform signup (matching website registration logic exactly)
     */
    private void performSignup() {
        String name = binding.nameInput.getText().toString().trim();
        String email = binding.emailInput.getText().toString().trim();
        String password = binding.passwordInput.getText().toString();
        String confirmPassword = binding.confirmPasswordInput.getText().toString();
        
        // Basic validation (matching website)
        if (name.isEmpty() || email.isEmpty() || password.isEmpty() || confirmPassword.isEmpty()) {
            Toast.makeText(this, "Please fill in all fields", Toast.LENGTH_SHORT).show();
            return;
        }
        
        if (!isValidEmail(email)) {
            Toast.makeText(this, "Please enter a valid email address", Toast.LENGTH_SHORT).show();
            return;
        }
        
        // Password validation (matching website)
        if (!validatePassword(password)) {
            Toast.makeText(this, "Password must be at least 8 characters long", Toast.LENGTH_SHORT).show();
            return;
        }
        
        if (!password.equals(confirmPassword)) {
            Toast.makeText(this, "Passwords don't match", Toast.LENGTH_SHORT).show();
            return;
        }
        
        // Parse name (matching website logic)
        String[] nameParts = name.split(" ", 2);
        String firstName = nameParts[0];
        String lastName = nameParts.length > 1 ? nameParts[1] : "";
        
        // Show loading state
        setLoadingState(true, "Sending verification...");
        
        // Send verification (matching website fetch('/api/send-verification'))
        authService.sendVerification(firstName, lastName, email, password, new AuthService.VerificationCallback() {
            @Override
            public void onSuccess(String message) {
                Log.d(TAG, "Verification email sent successfully: " + message);
                setLoadingState(false, null);
                
                // Show the success message to user (especially important for demo mode)
                Toast.makeText(LoginActivity.this, message, Toast.LENGTH_LONG).show();
                
                // Store pending user data for verification (matching website)
                pendingFirstName = firstName;
                pendingLastName = lastName;
                pendingEmail = email;
                pendingPassword = password;
                
                // Extract demo code from message if present
                String demoCode = extractDemoCode(message);
                Log.d(TAG, "Extracted demo code: " + (demoCode != null ? demoCode : "null"));
                
                // Show verification section (matching website showVerificationSection)
                showVerificationSection(demoCode);
            }
            
            @Override
            public void onError(String error) {
                Log.e(TAG, "Signup failed: " + error);
                setLoadingState(false, null);
                
                Toast.makeText(LoginActivity.this, error, Toast.LENGTH_LONG).show();
            }
        });
    }
    
    /**
     * Show verification section (matching website showVerificationSection)
     */
    private void showVerificationSection(String demoCode) {
        // For now, launch VerificationActivity
        // In the future, we could implement inline verification like the website
        Intent intent = new Intent(this, VerificationActivity.class);
        intent.putExtra("email", pendingEmail);
        intent.putExtra("firstName", pendingFirstName);
        intent.putExtra("lastName", pendingLastName);
        if (demoCode != null) {
            intent.putExtra("demo_code", demoCode);
        }
        startActivityForResult(intent, 1001);
    }
    
    /**
     * Set loading state (matching website button state management)
     */
    private void setLoadingState(boolean loading, String message) {
        binding.actionButton.setEnabled(!loading);
        binding.toggleButton.setEnabled(!loading);
        binding.skipButton.setEnabled(!loading);
        
        // Disable input fields during loading
        binding.emailInput.setEnabled(!loading);
        binding.passwordInput.setEnabled(!loading);
        binding.nameInput.setEnabled(!loading);
        binding.confirmPasswordInput.setEnabled(!loading);
        
        if (loading && message != null) {
            binding.actionButton.setText(message);
        } else {
            updateFormUI(); // Reset button text
        }
    }
    
    /**
     * Navigate to main activity
     */
    private void navigateToMainActivity() {
        // Set result to indicate successful login
        setResult(RESULT_OK);
        
        Intent intent = new Intent(this, com.roomfinder.android.MainActivity.class);
        intent.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_CLEAR_TASK);
        startActivity(intent);
        finish();
    }
    
    /**
     * Email validation (matching website logic)
     */
    private boolean isValidEmail(String email) {
        return email != null && email.contains("@") && email.contains(".") && email.length() > 5;
    }
    
    /**
     * Password validation (matching website validatePassword)
     */
    private boolean validatePassword(String password) {
        return password != null && password.length() >= 8;
    }
    
    /**
     * Extract demo verification code from success message with multiple fallback methods
     */
    private String extractDemoCode(String message) {
        if (message == null) return null;
        
        Log.d(TAG, "Attempting to extract demo code from message: " + message);
        
        // Method 1: Look for "verification code is XXXXXX"
        if (message.contains("verification code is ")) {
            try {
                int startIndex = message.indexOf("verification code is ") + "verification code is ".length();
                String potentialCode = message.substring(startIndex, Math.min(startIndex + 6, message.length()));
                
                // Validate it's 6 digits
                if (potentialCode.matches("\\d{6}")) {
                    Log.d(TAG, "Method 1 - Extracted demo code: " + potentialCode);
                    return potentialCode;
                }
            } catch (Exception e) {
                Log.e(TAG, "Method 1 failed to extract demo code", e);
            }
        }
        
        // Method 2: Use regex to find any 6-digit number in the message
        try {
            java.util.regex.Pattern pattern = java.util.regex.Pattern.compile("\\b(\\d{6})\\b");
            java.util.regex.Matcher matcher = pattern.matcher(message);
            if (matcher.find()) {
                String potentialCode = matcher.group(1);
                Log.d(TAG, "Method 2 - Extracted demo code via regex: " + potentialCode);
                return potentialCode;
            }
        } catch (Exception e) {
            Log.e(TAG, "Method 2 regex extraction failed", e);
        }
        
        // Method 3: Look for "DEMO MODE" and extract the first 6-digit sequence after it
        if (message.contains("DEMO MODE")) {
            try {
                int demoIndex = message.indexOf("DEMO MODE");
                String afterDemo = message.substring(demoIndex);
                java.util.regex.Pattern pattern = java.util.regex.Pattern.compile("(\\d{6})");
                java.util.regex.Matcher matcher = pattern.matcher(afterDemo);
                if (matcher.find()) {
                    String potentialCode = matcher.group(1);
                    Log.d(TAG, "Method 3 - Extracted demo code after DEMO MODE: " + potentialCode);
                    return potentialCode;
                }
            } catch (Exception e) {
                Log.e(TAG, "Method 3 failed to extract demo code", e);
            }
        }
        
        Log.w(TAG, "All extraction methods failed for message: " + message);
        return null;
    }
    
    /**
     * Handle result from VerificationActivity
     */
    @Override
    protected void onActivityResult(int requestCode, int resultCode, Intent data) {
        super.onActivityResult(requestCode, resultCode, data);
        
        if (requestCode == 1001) { // Verification activity
            if (resultCode == RESULT_OK) {
                // Email verified successfully, navigate to main activity
                navigateToMainActivity();
            }
            // If RESULT_CANCELED, user can try again or go back
        }
    }
    
    @Override
    protected void onDestroy() {
        super.onDestroy();
        if (binding != null) {
            binding = null;
        }
    }
}