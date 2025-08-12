package com.roomfinder.android;

import android.app.Application;
import android.util.Log;

public class RoomFinderApplication extends Application {
    
    private static final String TAG = "RoomFinderApplication";
    
    @Override
    public void onCreate() {
        super.onCreate();
        
        // Set up global exception handler
        Thread.setDefaultUncaughtExceptionHandler(new Thread.UncaughtExceptionHandler() {
            @Override
            public void uncaughtException(Thread thread, Throwable throwable) {
                Log.e(TAG, "Uncaught exception in thread " + thread.getName(), throwable);
                
                // Log the stack trace
                StringBuilder stackTrace = new StringBuilder();
                for (StackTraceElement element : throwable.getStackTrace()) {
                    stackTrace.append(element.toString()).append("\n");
                }
                Log.e(TAG, "Stack trace: " + stackTrace.toString());
                
                // Try to handle the crash gracefully
                handleCrash(throwable);
            }
        });
        
        Log.d(TAG, "RoomFinder Application started successfully");
    }
    
    private void handleCrash(Throwable throwable) {
        try {
            // Log crash details
            Log.e(TAG, "Application crashed: " + throwable.getMessage());
            
            // You could send crash reports to a service here
            // For now, we'll just log and try to continue
            
        } catch (Exception e) {
            Log.e(TAG, "Error handling crash: " + e.getMessage(), e);
        } finally {
            // Let the system handle the crash
            System.exit(1);
        }
    }
    
    @Override
    public void onTerminate() {
        Log.d(TAG, "RoomFinder Application terminating");
        super.onTerminate();
    }
    
    @Override
    public void onLowMemory() {
        Log.w(TAG, "RoomFinder Application low on memory");
        super.onLowMemory();
        
        // Clear any caches or non-essential data
        System.gc(); // Suggest garbage collection
    }
}