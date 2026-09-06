package com.roomfinder.android.activities;

import android.content.Context;
import android.content.Intent;
import android.os.Bundle;
import android.view.View;
import android.widget.ImageButton;
import android.widget.ImageView;
import android.widget.LinearLayout;
import android.widget.TextView;
import android.widget.Toast;

import androidx.annotation.Nullable;
import androidx.appcompat.app.AppCompatActivity;
import androidx.appcompat.widget.PopupMenu;

import com.bumptech.glide.Glide;
import com.google.android.material.button.MaterialButton;
import com.roomfinder.android.R;
import com.roomfinder.android.models.RoommateProfile;
import com.roomfinder.android.utils.Insets;

/**
 * Who somebody is, before you message them.
 *
 * Mirrors RoommateDetailScreen on iOS. Android had nothing equivalent: the
 * People tab listed people and tapping one did nothing useful, so the only
 * basis for deciding whether to contact somebody was the two lines that fit on
 * their card.
 *
 * Sections hide when they have nothing in them. Most of these profiles are
 * sparse, and a column of headings over blank space reads as a broken screen
 * rather than as a thin profile.
 */
public class RoommateDetailActivity extends AppCompatActivity {

    private static final String EXTRA_PROFILE = "profile";

    private RoommateProfile profile;

    /**
     * The intent, rather than starting it here.
     *
     * The caller launches it for a result, because "Message them" is answered
     * by the screen that knows how to open a conversation - see
     * PeopleFragment.messageRoommate.
     */
    public static Intent intent(Context context, RoommateProfile profile) {
        Intent intent = new Intent(context, RoommateDetailActivity.class);
        intent.putExtra(EXTRA_PROFILE, profile);
        return intent;
    }

    public static void start(Context context, RoommateProfile profile) {
        context.startActivity(intent(context, profile));
    }

    @Override
    protected void onCreate(@Nullable Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_roommate_detail);

        profile = (RoommateProfile) getIntent().getSerializableExtra(EXTRA_PROFILE);
        if (profile == null) {
            // Nothing to show and nothing worth inventing.
            finish();
            return;
        }

        // targetSdk 35+ draws edge to edge whether asked or not, so the top bar
        // would sit under the clock and the back button would be half dead.
        Insets.padTopForStatusBar(findViewById(R.id.roommateTopBar));

        bindHeader();
        bindSections();
        bindActions();
    }

    private void bindHeader() {
        ((TextView) findViewById(R.id.roommateName)).setText(profile.getDisplayName());
        ((TextView) findViewById(R.id.roommateInitials)).setText(profile.getInitials());
        ((TextView) findViewById(R.id.roommateKind)).setText(profile.getKindLabel());
        ((TextView) findViewById(R.id.roommateBudget)).setText(profile.getBudgetText());

        String avatar = profile.getAvatarUrl();
        if (avatar != null && !avatar.isEmpty()) {
            ImageView image = findViewById(R.id.roommateAvatar);
            image.setVisibility(View.VISIBLE);
            // The initials stay underneath as the placeholder, so a slow or
            // broken image leaves a filled circle rather than a hole.
            Glide.with(this).load(avatar).circleCrop().into(image);
        }
    }

    private void bindSections() {
        String bio = profile.getBio();
        if (bio != null && !bio.trim().isEmpty()) {
            findViewById(R.id.roommateAboutSection).setVisibility(View.VISIBLE);
            ((TextView) findViewById(R.id.roommateBio)).setText(bio.trim());
        }

        row(R.id.roommateRowStatus, "Status", profile.getKindLabel());
        // Somebody offering a room quotes a rent; somebody looking states a
        // budget. Same field, opposite meaning, so the label has to follow.
        row(R.id.roommateRowBudget,
                "hasSpot".equals(profile.getKind()) ? "Rent" : "Budget",
                profile.getBudgetText());
        row(R.id.roommateRowArea, "Area", profile.getLocationText());
        row(R.id.roommateRowMoveIn, "Move-in", profile.getMoveInDate());

        String room = profile.getRoomDescription();
        if (room != null && !room.trim().isEmpty()) {
            findViewById(R.id.roommateRoomSection).setVisibility(View.VISIBLE);
            ((TextView) findViewById(R.id.roommateRoomDescription)).setText(room.trim());
        }
    }

    /** Writes "Label   value", or hides the row when there is no value. */
    private void row(int id, String label, String value) {
        TextView view = findViewById(id);
        if (value == null || value.trim().isEmpty()) {
            view.setVisibility(View.GONE);
            return;
        }
        view.setVisibility(View.VISIBLE);
        view.setText(label + "   " + value.trim());
    }

    private void bindActions() {
        ImageButton back = findViewById(R.id.roommateBack);
        back.setOnClickListener(v -> finish());

        MaterialButton message = findViewById(R.id.roommateMessageButton);
        message.setOnClickListener(v -> {
            // The People tab already knows how to open a conversation with a
            // profile - it resolves the owner through the server, because these
            // rows carry a user_id and no email. Handing the result back keeps
            // that logic in one place.
            Intent result = new Intent();
            result.putExtra("message_profile_id", profile.getId());
            result.putExtra("message_profile_name", profile.getDisplayName());
            setResult(RESULT_OK, result);
            finish();
        });

        ImageButton overflow = findViewById(R.id.roommateOverflow);
        overflow.setOnClickListener(v -> {
            PopupMenu popup = new PopupMenu(this, v);
            popup.getMenu().add(0, 1, 0, "Report this profile");
            popup.getMenu().add(0, 2, 1, "Block this person");
            popup.setOnMenuItemClickListener(item -> {
                // Reporting and blocking both exist elsewhere in the app and
                // are not wired here yet. Saying so is better than a menu that
                // silently does nothing when tapped.
                Toast.makeText(this,
                        "Reporting and blocking are not wired to this screen yet",
                        Toast.LENGTH_LONG).show();
                return true;
            });
            popup.show();
        });
    }
}
