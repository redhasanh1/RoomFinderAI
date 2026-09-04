package com.roomfinder.android.activities;

import android.content.Intent;
import android.os.Bundle;
import android.text.Editable;
import android.text.TextWatcher;
import android.util.Log;
import android.view.View;
import android.widget.Toast;
import androidx.activity.result.ActivityResultLauncher;
import androidx.activity.result.contract.ActivityResultContracts;
import androidx.appcompat.app.AppCompatActivity;
import com.roomfinder.android.auth.AuthManager;
import com.roomfinder.android.auth.SupabaseOAuthManager;
import com.google.android.gms.auth.api.signin.GoogleSignIn;
import com.google.android.gms.auth.api.signin.GoogleSignInAccount;
import com.google.android.gms.auth.api.signin.GoogleSignInClient;
import com.google.android.gms.auth.api.signin.GoogleSignInOptions;
import com.google.android.gms.common.api.ApiException;
import com.google.android.gms.tasks.Task;
import com.roomfinder.android.BuildConfig;
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
    private GoogleSignInClient googleSignInClient;
    private ActivityResultLauncher<Intent> googleSignInLauncher;
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
        
        // Initialize Google Sign-In (matching website configuration)
        initializeGoogleSignIn();
        
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
        // "Continue as guest" used to be a bare finish(). When this screen is
        // the only one in the task - a cold start, a notification, a deep link -
        // finishing it closes the app, so tapping "continue" looked exactly
        // like a crash. Go to the app instead, and let an existing MainActivity
        // below be reused rather than stacking a second one.
        binding.skipButton.setOnClickListener(v -> {
            Intent intent = new Intent(this, com.roomfinder.android.MainActivity.class);
            intent.addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP | Intent.FLAG_ACTIVITY_SINGLE_TOP);
            startActivity(intent);
            finish();
        });
        
        // Forgot password. This link was rendered but never wired, so tapping it
        // did nothing at all.
        binding.forgotPassword.setOnClickListener(v -> {
            Intent intent = new Intent(this, ForgotPasswordActivity.class);
            String typedEmail = binding.emailInput.getText() == null
                    ? "" : binding.emailInput.getText().toString().trim();
            if (!typedEmail.isEmpty()) {
                intent.putExtra("email", typedEmail);
            }
            startActivity(intent);
        });

        // Google Sign-In button (matching website googleSignInBtn)
        binding.googleButton.setOnClickListener(v -> performGoogleSignIn());

        // Apple Sign-In: same Supabase OAuth flow the website uses. This button
        // existed in the layout but had no listener at all.
        binding.appleButton.setOnClickListener(v -> {
            setLoadingState(true, "Opening Apple sign-in...");
            SupabaseOAuthManager.launch(this, SupabaseOAuthManager.PROVIDER_APPLE);
        });
        
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
            binding.forgotPassword.setVisibility(View.VISIBLE);
        } else {
            // Signup form
            binding.titleText.setText("Create Account");
            binding.nameLayout.setVisibility(View.VISIBLE);
            binding.confirmPasswordLayout.setVisibility(View.VISIBLE);
            binding.actionButton.setText("Create Account");
            binding.toggleButton.setText("Already have an account? Sign in");
            // You cannot have forgotten the password for an account you are
            // about to create.
            binding.forgotPassword.setVisibility(View.GONE);
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
     * Initialize Google Sign-In (matching website loadOAuthConfig and initializeGoogleSignIn)
     */
    private void initializeGoogleSignIn() {
        // requestIdToken() throws on an empty string, which used to crash the
        // screen whenever GOOGLE_OAUTH_CLIENT_ID was not set.
        GoogleSignInOptions.Builder builder =
                new GoogleSignInOptions.Builder(GoogleSignInOptions.DEFAULT_SIGN_IN)
                        .requestEmail()
                        .requestProfile();
        if (isGoogleClientIdConfigured()) {
            builder.requestIdToken(BuildConfig.GOOGLE_OAUTH_CLIENT_ID);
        }
        GoogleSignInOptions gso = builder.build();

        googleSignInClient = GoogleSignIn.getClient(this, gso);
        
        // Register for activity result (modern approach)
        googleSignInLauncher = registerForActivityResult(
            new ActivityResultContracts.StartActivityForResult(),
            result -> {
                if (result.getResultCode() == RESULT_OK) {
                    handleGoogleSignInResult(result.getData());
                } else {
                    Log.w(TAG, "Google Sign-In cancelled or failed");
                    Toast.makeText(this, "Google Sign-In cancelled", Toast.LENGTH_SHORT).show();
                }
            }
        );
        
        Log.d(TAG, "Google Sign-In initialized with client ID: " + BuildConfig.GOOGLE_OAUTH_CLIENT_ID);
    }
    
    /**
     * Perform Google Sign-In (matching website handleGoogleSignIn)
     */
    private void performGoogleSignIn() {
        Log.d(TAG, "Starting Google Sign-In process");

        // Without a configured OAuth client ID the native flow can only fail with
        // DEVELOPER_ERROR (10). Use the browser flow instead, which is what the
        // website does and needs no per-app credential.
        if (googleSignInClient == null || !isGoogleClientIdConfigured()) {
            Log.w(TAG, "No Google OAuth client ID configured - using Supabase browser flow");
            setLoadingState(true, "Opening Google sign-in...");
            SupabaseOAuthManager.launch(this, SupabaseOAuthManager.PROVIDER_GOOGLE);
            return;
        }
        
        // Sign out any previous account to force account picker
        googleSignInClient.signOut().addOnCompleteListener(this, task -> {
            // Launch sign-in intent
            Intent signInIntent = googleSignInClient.getSignInIntent();
            googleSignInLauncher.launch(signInIntent);
        });
    }
    
    /**
     * Handle Google Sign-In result (matching website handleGoogleIdToken)
     */
    private void handleGoogleSignInResult(Intent data) {
        try {
            Task<GoogleSignInAccount> task = GoogleSignIn.getSignedInAccountFromIntent(data);
            GoogleSignInAccount account = task.getResult(ApiException.class);
            
            if (account != null && account.getIdToken() != null) {
                Log.d(TAG, "Google Sign-In successful, ID token received");
                Log.d(TAG, "User: " + account.getDisplayName() + " (" + account.getEmail() + ")");
                
                // Show loading state
                setLoadingState(true, "Signing in with Google...");
                
                // Send ID token to backend (matching website)
                authService.authenticateWithGoogle(account.getIdToken(), new AuthService.AuthCallback() {
                    @Override
                    public void onSuccess(User user) {
                        Log.d(TAG, "Google authentication successful for user: " + user.getEmail());
                        setLoadingState(false, null);
                        
                        Toast.makeText(LoginActivity.this, "Welcome " + user.getFirstName() + "!", Toast.LENGTH_SHORT).show();
                        
                        // Navigate to main activity (matching website redirect)
                        navigateToMainActivity();
                    }
                    
                    @Override
                    public void onError(String error) {
                        Log.e(TAG, "Google authentication failed: " + error);
                        setLoadingState(false, null);
                        
                        Toast.makeText(LoginActivity.this, "Google Sign-In failed: " + error, Toast.LENGTH_LONG).show();
                    }
                });
            } else {
                Log.e(TAG, "Google Sign-In result missing ID token");
                Toast.makeText(this, "Google Sign-In failed - no authentication token received", Toast.LENGTH_LONG).show();
            }
        } catch (ApiException e) {
            Log.e(TAG, "Google Sign-In failed with exception: " + e.getStatusCode(), e);
            Toast.makeText(this, "Google Sign-In failed: " + e.getMessage(), Toast.LENGTH_LONG).show();
        }
    }
    
    private boolean isGoogleClientIdConfigured() {
        String clientId = BuildConfig.GOOGLE_OAUTH_CLIENT_ID;
        return clientId != null
                && !clientId.trim().isEmpty()
                && !"API_KEY_NOT_CONFIGURED".equals(clientId);
    }

    @Override
    protected void onNewIntent(Intent intent) {
        super.onNewIntent(intent);
        setIntent(intent);
        handleOAuthCallback(intent);
    }

    @Override
    protected void onResume() {
        super.onResume();
        handleOAuthCallback(getIntent());
    }

    /** Completes a Google / Apple sign-in that came back over the deep link. */
    private void handleOAuthCallback(Intent intent) {
        if (intent == null || intent.getData() == null) {
            return;
        }
        android.net.Uri data = intent.getData();
        if (!SupabaseOAuthManager.isCallback(data)) {
            return;
        }

        // Consume it so a rotation or a return to this screen cannot replay it.
        intent.setData(null);
        setLoadingState(false, null);

        String error = SupabaseOAuthManager.errorFrom(data);
        if (error != null) {
            Log.e(TAG, "OAuth sign-in failed: " + error);
            Toast.makeText(this, "Sign-in failed: " + error, Toast.LENGTH_LONG).show();
            return;
        }

        User user = SupabaseOAuthManager.userFrom(data);
        if (user == null) {
            Log.e(TAG, "OAuth callback carried no usable session");
            Toast.makeText(this, "Sign-in failed - no session returned", Toast.LENGTH_LONG).show();
            return;
        }

        AuthManager authManager = AuthManager.getInstance(this);
        authManager.registerUser(user);
        authManager.storeCurrentUser(user);

        Log.d(TAG, "OAuth sign-in complete for " + user.getEmail());
        Toast.makeText(this, "Welcome " + user.getFirstName() + "!", Toast.LENGTH_SHORT).show();
        navigateToMainActivity();
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