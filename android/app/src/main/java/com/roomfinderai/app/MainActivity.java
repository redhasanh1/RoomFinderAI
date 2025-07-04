package com.roomfinderai.app;

import android.os.Bundle;
import android.util.Log;
import android.webkit.WebView;
import com.getcapacitor.BridgeActivity;

public class MainActivity extends BridgeActivity {
    private static final String TAG = "RoomFinderAI";
    
    @Override
    public void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        
        // Enable debugging for web views
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.KITKAT) {
            WebView.setWebContentsDebuggingEnabled(true);
        }
        
        Log.d(TAG, "RoomFinderAI app initialized successfully");
    }
    
    @Override
    public void onResume() {
        super.onResume();
        Log.d(TAG, "App resumed");
    }
    
    @Override
    public void onPause() {
        super.onPause();
        Log.d(TAG, "App paused");
    }
}
