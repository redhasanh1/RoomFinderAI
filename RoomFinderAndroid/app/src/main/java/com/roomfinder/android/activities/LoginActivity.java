package com.roomfinder.android.activities;

import android.content.SharedPreferences;
import android.os.Bundle;
import android.widget.Toast;
import androidx.appcompat.app.AppCompatActivity;
import android.content.Context;
import com.roomfinder.android.databinding.ActivityLoginBinding;

public class LoginActivity extends AppCompatActivity {
    
    private ActivityLoginBinding binding;
    private SharedPreferences prefs;
    private boolean showSignup = false;
    
    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        
        binding = ActivityLoginBinding.inflate(getLayoutInflater());
        setContentView(binding.getRoot());
        
        prefs = getSharedPreferences("roomfinder_prefs", Context.MODE_PRIVATE);
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
        binding.nameLayout.setVisibility(android.view.View.GONE);
        binding.confirmPasswordLayout.setVisibility(android.view.View.GONE);
        binding.actionButton.setText("Login");
        binding.toggleButton.setText("Don't have an account? Sign Up");
    }
    
    private void showSignupForm() {
        binding.titleText.setText("Create Account");
        binding.nameLayout.setVisibility(android.view.View.VISIBLE);
        binding.confirmPasswordLayout.setVisibility(android.view.View.VISIBLE);
        binding.actionButton.setText("Sign Up");
        binding.toggleButton.setText("Already have an account? Login");
    }
    
    private void performLogin() {
        String email = binding.emailInput.getText().toString();
        String password = binding.passwordInput.getText().toString();
        
        if (email.isEmpty() || password.isEmpty()) {
            Toast.makeText(this, "Please fill all fields", Toast.LENGTH_SHORT).show();
            return;
        }
        
        // Simple mock login - in real app this would call API
        prefs.edit()
            .putString("user_email", email)
            .putString("user_name", email.split("@")[0])
            .putString("auth_token", "mock_token_123")
            .apply();
        
        Toast.makeText(this, "Login successful!", Toast.LENGTH_SHORT).show();
        finish();
    }
    
    private void performSignup() {
        String name = binding.nameInput.getText().toString();
        String email = binding.emailInput.getText().toString();
        String password = binding.passwordInput.getText().toString();
        String confirmPassword = binding.confirmPasswordInput.getText().toString();
        
        if (name.isEmpty() || email.isEmpty() || password.isEmpty() || confirmPassword.isEmpty()) {
            Toast.makeText(this, "Please fill all fields", Toast.LENGTH_SHORT).show();
            return;
        }
        
        if (!password.equals(confirmPassword)) {
            Toast.makeText(this, "Passwords don't match", Toast.LENGTH_SHORT).show();
            return;
        }
        
        // Simple mock signup - in real app this would call API
        prefs.edit()
            .putString("user_email", email)
            .putString("user_name", name)
            .putString("auth_token", "mock_token_123")
            .apply();
        
        Toast.makeText(this, "Account created successfully!", Toast.LENGTH_SHORT).show();
        finish();
    }
}