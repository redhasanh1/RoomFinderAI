package com.roomfinderai.app;

import android.os.Bundle;
import android.view.MenuItem;
import android.widget.EditText;
import android.widget.ImageButton;
import androidx.appcompat.app.AppCompatActivity;
import androidx.fragment.app.Fragment;
import androidx.fragment.app.FragmentManager;
import androidx.fragment.app.FragmentTransaction;
import com.google.android.material.bottomnavigation.BottomNavigationView;
import com.roomfinderai.app.fragments.CategoriesFragment;
import com.roomfinderai.app.fragments.ListingsFragment;
import com.roomfinderai.app.fragments.MessagesFragment;
import com.roomfinderai.app.fragments.PostFragment;
import com.roomfinderai.app.fragments.ProfileFragment;

public class MarketplaceActivity extends AppCompatActivity {

    private BottomNavigationView bottomNavigation;
    private EditText searchBar;
    private ImageButton filterButton;
    private FragmentManager fragmentManager;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setTheme(R.style.MarketplaceTheme);
        setContentView(R.layout.activity_marketplace);

        initializeViews();
        setupBottomNavigation();
        setupSearchBar();
        
        if (savedInstanceState == null) {
            loadFragment(new ListingsFragment());
        }
    }

    private void initializeViews() {
        bottomNavigation = findViewById(R.id.bottomNavigation);
        searchBar = findViewById(R.id.searchBar);
        filterButton = findViewById(R.id.filterButton);
        fragmentManager = getSupportFragmentManager();
    }

    private void setupBottomNavigation() {
        bottomNavigation.setOnNavigationItemSelectedListener(item -> {
            Fragment fragment = null;
            
            switch (item.getItemId()) {
                case R.id.navigation_home:
                    fragment = new ListingsFragment();
                    break;
                case R.id.navigation_categories:
                    fragment = new CategoriesFragment();
                    break;
                case R.id.navigation_post:
                    fragment = new PostFragment();
                    break;
                case R.id.navigation_messages:
                    fragment = new MessagesFragment();
                    break;
                case R.id.navigation_profile:
                    fragment = new ProfileFragment();
                    break;
            }
            
            if (fragment != null) {
                loadFragment(fragment);
                return true;
            }
            return false;
        });
    }

    private void loadFragment(Fragment fragment) {
        FragmentTransaction transaction = fragmentManager.beginTransaction();
        transaction.setCustomAnimations(
            android.R.anim.fade_in,
            android.R.anim.fade_out,
            android.R.anim.fade_in,
            android.R.anim.fade_out
        );
        transaction.replace(R.id.fragmentContainer, fragment);
        transaction.commit();
    }

    private void setupSearchBar() {
        searchBar.setOnEditorActionListener((v, actionId, event) -> {
            String query = searchBar.getText().toString();
            performSearch(query);
            return true;
        });

        filterButton.setOnClickListener(v -> {
            showFilterDialog();
        });
    }

    private void performSearch(String query) {
        Fragment currentFragment = fragmentManager.findFragmentById(R.id.fragmentContainer);
        if (currentFragment instanceof ListingsFragment) {
            ((ListingsFragment) currentFragment).searchListings(query);
        }
    }

    private void showFilterDialog() {
        // Implement filter dialog
    }

    @Override
    public void onBackPressed() {
        if (fragmentManager.getBackStackEntryCount() > 0) {
            fragmentManager.popBackStack();
        } else {
            super.onBackPressed();
        }
    }
}