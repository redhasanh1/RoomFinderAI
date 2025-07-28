package com.roomfinder.android.activities;

import android.os.Bundle;
import android.util.Log;
import android.view.View;
import android.widget.Toast;
import androidx.appcompat.app.AppCompatActivity;
import com.roomfinder.android.auth.SupabaseAuthService;
import com.roomfinder.android.databinding.ActivityLoginBinding;
import com.roomfinder.android.models.User;

public class LoginActivity extends AppCompatActivity {
    
    private static final String TAG = "LoginActivity";
    private ActivityLoginBinding binding;
    private SupabaseAuthService authService;
    private boolean showSignup = false;
    
    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        
        binding = ActivityLoginBinding.inflate(getLayoutInflater());
        setContentView(binding.getRoot());
        
        authService = SupabaseAuthService.getInstance(this);
        showSignup = getIntent().getBooleanExtra("show_signup", false);
        
        setupViews();
    }
    
    private void setupViews() {
        if (showSignup) {
            showSignupForm();
        } else {
            showLoginForm();
        }
        
        binding.toggleButton.setOnClickListener(v -> {
            showSignup = !showSignup;
            if (showSignup) {
                showSignupForm();
            } else {
                showLoginForm();
            }
        });
        
        binding.actionButton.setOnClickListener(v -> {
            if (showSignup) {
                performSignup();
            } else {
                performLogin();
            }
        });
        
        binding.skipButton.setOnClickListener(v -> {
            finish();
        });
    }
    
    private void showLoginForm() {
        binding.titleText.setText("Welcome Back!");
        binding.nameLayout.setVisibility(View.GONE);
        binding.confirmPasswordLayout.setVisibility(View.GONE);
        binding.actionButton.setText("Login");
        binding.toggleButton.setText("Don't have an account? Sign Up");
    }
    
    private void showSignupForm() {
        binding.titleText.setText("Create Account");
        binding.nameLayout.setVisibility(View.VISIBLE);
        binding.confirmPasswordLayout.setVisibility(View.VISIBLE);
        binding.actionButton.setText("Sign Up");
        binding.toggleButton.setText("Already have an account? Login");
    }
    
    private void performLogin() {
        String email = binding.emailInput.getText().toString().trim();
        String password = binding.passwordInput.getText().toString();
        
        // Validation
        if (email.isEmpty() || password.isEmpty()) {
            Toast.makeText(this, "Please fill all fields", Toast.LENGTH_SHORT).show();
            return;
        }
        
        if (!isValidEmail(email)) {
            Toast.makeText(this, "Please enter a valid email address", Toast.LENGTH_SHORT).show();
            return;
        }
        
        // Show loading state
        setLoadingState(true, "Signing in...");
        
        // Perform login with Supabase
        authService.signIn(email, password, new SupabaseAuthService.AuthCallback() {
            @Override
            public void onSuccess(User user) {
                Log.d(TAG, "Login successful for user: " + user.getEmail());
                setLoadingState(false, null);
                
                Toast.makeText(LoginActivity.this, "Welcome back, " + user.getFirstName() + "!", 
                    Toast.LENGTH_SHORT).show();
                
                // Return success result
                setResult(RESULT_OK);
                finish();
            }
            
            @Override
            public void onError(String error) {
                Log.e(TAG, "Login failed: " + error);
                setLoadingState(false, null);
                
                Toast.makeText(LoginActivity.this, "Login failed: " + error, 
                    Toast.LENGTH_LONG).show();
            }
        });
    }
    
    private void performSignup() {
        String name = binding.nameInput.getText().toString().trim();
        String email = binding.emailInput.getText().toString().trim();
        String password = binding.passwordInput.getText().toString();
        String confirmPassword = binding.confirmPasswordInput.getText().toString();
        
        // Validation
        if (name.isEmpty() || email.isEmpty() || password.isEmpty() || confirmPassword.isEmpty()) {
            Toast.makeText(this, "Please fill all fields", Toast.LENGTH_SHORT).show();
            return;
        }
        
        if (!isValidEmail(email)) {
            Toast.makeText(this, "Please enter a valid email address", Toast.LENGTH_SHORT).show();
            return;
        }
        
        if (password.length() < 8) {
            Toast.makeText(this, "Password must be at least 8 characters long", Toast.LENGTH_SHORT).show();
            return;
        }
        
        if (!isValidPassword(password)) {
            Toast.makeText(this, "Password must contain uppercase, lowercase, and numeric characters", Toast.LENGTH_LONG).show();
            return;
        }
        
        if (!password.equals(confirmPassword)) {
            Toast.makeText(this, "Passwords don't match", Toast.LENGTH_SHORT).show();
            return;
        }
        
        // Parse name (assuming format "First Last" or just "First")
        String[] nameParts = name.split(" ", 2);
        String firstName = nameParts[0];
        String lastName = nameParts.length > 1 ? nameParts[1] : "";
        
        // Show loading state
        setLoadingState(true, "Creating account...");
        
        // Perform signup with Supabase
        authService.signUp(email, password, firstName, lastName, new SupabaseAuthService.AuthCallback() {
            @Override
            public void onSuccess(User user) {
                Log.d(TAG, "Signup successful for user: " + user.getEmail());
                setLoadingState(false, null);
                
                // Check if email verification is needed
                String message;
                if (user.isEmailVerified()) {
                    message = "Account created successfully! Welcome, " + user.getFirstName() + "!";
                } else {
                    message = "Account created! Please check your email to verify your account, " + user.getFirstName() + ".";
                }
                
                Toast.makeText(LoginActivity.this, message, Toast.LENGTH_LONG).show();
                
                // Return success result
                setResult(RESULT_OK);
                finish();
            }
            
            @Override
            public void onError(String error) {
                Log.e(TAG, "Signup failed: " + error);
                setLoadingState(false, null);
                
                Toast.makeText(LoginActivity.this, "Signup failed: " + error, 
                    Toast.LENGTH_LONG).show();
            }
        });
    }
    
    private void setLoadingState(boolean loading, String message) {
        binding.actionButton.setEnabled(!loading);
        binding.toggleButton.setEnabled(!loading);
        binding.skipButton.setEnabled(!loading);
        
        // Disable input fields during loading
        binding.emailInput.setEnabled(!loading);
        binding.passwordInput.setEnabled(!loading);
        binding.nameInput.setEnabled(!loading);
        binding.confirmPasswordInput.setEnabled(!loading);
        
        if (loading) {
            binding.actionButton.setText(message != null ? message : "Loading...");
        } else {
            if (showSignup) {
                binding.actionButton.setText("Sign Up");
            } else {
                binding.actionButton.setText("Login");
            }
        }
    }
    
    private boolean isValidEmail(String email) {
        return email != null && email.contains("@") && email.contains(".") && email.length() > 5;
    }
    
    private boolean isValidPassword(String password) {
        if (password == null || password.length() < 8) {
            return false;
        }
        
        boolean hasUpper = false;
        boolean hasLower = false;
        boolean hasDigit = false;
        
        for (char c : password.toCharArray()) {
            if (Character.isUpperCase(c)) {
                hasUpper = true;
            } else if (Character.isLowerCase(c)) {
                hasLower = true;
            } else if (Character.isDigit(c)) {
                hasDigit = true;
            }
        }
        
        return hasUpper && hasLower && hasDigit;
    }
    
    @Override
    protected void onDestroy() {
        super.onDestroy();
        if (binding != null) {
            binding = null;
        }
    }
}