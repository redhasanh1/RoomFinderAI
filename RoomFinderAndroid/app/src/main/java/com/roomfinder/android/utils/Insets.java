package com.roomfinder.android.utils;

import android.view.View;

import androidx.core.view.ViewCompat;
import androidx.core.view.WindowInsetsCompat;

/**
 * Keeps content out from under the system bars.
 *
 * targetSdk 35 on Android 15 draws every app edge to edge whether it asks or
 * not, and `android:statusBarColor` is ignored, so any screen that does not
 * handle this itself ends up with its top row underneath the clock. That is not
 * only cosmetic: the status bar takes the touches. On the listing detail screen
 * the back, favourite and share buttons sat at y=42..168 while the status bar
 * owned everything above roughly y=110, so two thirds of each button was dead
 * and the heart looked broken.
 *
 * The height is read from the inset rather than hardcoded, because it differs
 * between notched, punch-hole and plain screens.
 */
public final class Insets {

    private Insets() {
    }

    /** Adds the status bar height to whatever top padding the view already has. */
    public static void padTopForStatusBar(final View view) {
        if (view == null) {
            return;
        }
        final int left = view.getPaddingLeft();
        final int top = view.getPaddingTop();
        final int right = view.getPaddingRight();
        final int bottom = view.getPaddingBottom();

        ViewCompat.setOnApplyWindowInsetsListener(view, (v, insets) -> {
            int statusBar = insets.getInsets(WindowInsetsCompat.Type.statusBars()).top;
            v.setPadding(left, top + statusBar, right, bottom);
            return insets;
        });
        ViewCompat.requestApplyInsets(view);
    }
}
