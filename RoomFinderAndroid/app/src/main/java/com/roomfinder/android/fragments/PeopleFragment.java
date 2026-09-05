package com.roomfinder.android.fragments;

import android.os.Bundle;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.util.Log;
import android.widget.Toast;

import com.roomfinder.android.auth.AuthManager;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.core.content.ContextCompat;
import androidx.fragment.app.Fragment;
import androidx.recyclerview.widget.LinearLayoutManager;

import com.roomfinder.android.R;
import com.roomfinder.android.adapters.PeopleAdapter;
import com.roomfinder.android.databinding.FragmentPeopleBinding;
import com.roomfinder.android.models.RoommateProfile;
import com.roomfinder.android.models.SubleaseRequest;
import com.roomfinder.android.network.PeopleService;

import java.util.List;

/**
 * The people side of the marketplace: Subleases and RoomPal, sharing one tab
 * the way they do on iOS.
 *
 * This replaces StudentHousingFragment. Student housing was removed from the
 * website and never existed on iOS, so a whole tab of the Android app pointed
 * at a product that is gone.
 */
public class PeopleFragment extends Fragment implements PeopleAdapter.Listener {

    private static final String TAG = "PeopleFragment";

    private FragmentPeopleBinding binding;
    private PeopleAdapter adapter;
    private PeopleService service;

    /** Subleases is the default half, matching iOS. */
    private boolean showingRoommates = false;

    @Override
    public View onCreateView(@NonNull LayoutInflater inflater, ViewGroup container, Bundle savedInstanceState) {
        binding = FragmentPeopleBinding.inflate(inflater, container, false);
        return binding.getRoot();
    }

    @Override
    public void onViewCreated(@NonNull View view, @Nullable Bundle savedInstanceState) {
        super.onViewCreated(view, savedInstanceState);

        service = PeopleService.getInstance();
        adapter = new PeopleAdapter(this);
        binding.peopleRecycler.setLayoutManager(new LinearLayoutManager(requireContext()));
        binding.peopleRecycler.setAdapter(adapter);

        binding.modeSubleases.setOnClickListener(v -> setMode(false));
        binding.modeRoommates.setOnClickListener(v -> setMode(true));

        binding.roommateKindGroup.setOnCheckedStateChangeListener((group, ids) -> load());
        binding.peopleRefresh.setOnRefreshListener(this::load);
        binding.peopleRefresh.setColorSchemeColors(
                ContextCompat.getColor(requireContext(), R.color.purple_primary));

        applyModeStyling();
        load();
    }

    @Override
    public void onDestroyView() {
        super.onDestroyView();
        binding = null;
    }

    private void setMode(boolean roommates) {
        if (showingRoommates == roommates) {
            return;
        }
        showingRoommates = roommates;
        applyModeStyling();
        load();
    }

    /** The selected half is a filled brand pill; the other is a quiet surface. */
    private void applyModeStyling() {
        if (binding == null) {
            return;
        }
        int brand = ContextCompat.getColor(requireContext(), R.color.purple_primary);
        int quiet = ContextCompat.getColor(requireContext(), R.color.ios_gray6);
        int onBrand = ContextCompat.getColor(requireContext(), R.color.white);
        int onQuiet = ContextCompat.getColor(requireContext(), R.color.text_primary);

        binding.modeSubleases.setBackgroundTintList(
                android.content.res.ColorStateList.valueOf(showingRoommates ? quiet : brand));
        binding.modeSubleases.setTextColor(showingRoommates ? onQuiet : onBrand);
        binding.modeSubleases.setIconTint(
                android.content.res.ColorStateList.valueOf(showingRoommates ? onQuiet : onBrand));

        binding.modeRoommates.setBackgroundTintList(
                android.content.res.ColorStateList.valueOf(showingRoommates ? brand : quiet));
        binding.modeRoommates.setTextColor(showingRoommates ? onBrand : onQuiet);
        binding.modeRoommates.setIconTint(
                android.content.res.ColorStateList.valueOf(showingRoommates ? onBrand : onQuiet));

        binding.peopleTitle.setText(showingRoommates ? "RoomPal" : "Subleases");
        // Only RoomPal has two sides to choose between.
        binding.roommateKindGroup.setVisibility(showingRoommates ? View.VISIBLE : View.GONE);
    }

    private void load() {
        if (binding == null) {
            return;
        }
        binding.peopleEmpty.setVisibility(View.GONE);
        if (!binding.peopleRefresh.isRefreshing()) {
            binding.peopleProgress.setVisibility(View.VISIBLE);
        }

        if (showingRoommates) {
            String kind = binding.chipHasSpot.isChecked()
                    ? RoommateProfile.KIND_HAS_SPOT
                    : RoommateProfile.KIND_SEEKING;
            service.loadRoommates(kind, null, new PeopleService.RoommatesCallback() {
                @Override
                public void onSuccess(List<RoommateProfile> profiles) {
                    if (binding == null) {
                        return;
                    }
                    finishLoading();
                    // The kind chip above the list already says which half this
                    // is, so the per-card badge would only repeat it.
                    adapter.setShowKindBadge(false);
                    adapter.submitRoommates(profiles);
                    binding.peopleCount.setText(countText(profiles.size(),
                            "person", "people"));
                    showEmptyState(profiles.isEmpty(),
                            binding.chipHasSpot.isChecked()
                                    ? "No rooms on offer yet"
                                    : "Nobody looking right now",
                            "Post your profile and be the first");
                }

                @Override
                public void onError(String message) {
                    reportError(message);
                }
            });
        } else {
            service.loadSubleases(null, new PeopleService.SubleasesCallback() {
                @Override
                public void onSuccess(List<SubleaseRequest> requests) {
                    if (binding == null) {
                        return;
                    }
                    finishLoading();
                    adapter.submitSubleases(requests);
                    binding.peopleCount.setText(countText(requests.size(),
                            "sublease", "subleases"));
                    showEmptyState(requests.isEmpty(),
                            "No subleases yet",
                            "Post one and it will show up here");
                }

                @Override
                public void onError(String message) {
                    reportError(message);
                }
            });
        }
    }

    private void finishLoading() {
        binding.peopleProgress.setVisibility(View.GONE);
        binding.peopleRefresh.setRefreshing(false);
    }

    private String countText(int count, String singular, String plural) {
        return count + " " + (count == 1 ? singular : plural);
    }

    private void showEmptyState(boolean empty, String title, String body) {
        binding.peopleEmpty.setVisibility(empty ? View.VISIBLE : View.GONE);
        binding.peopleEmptyTitle.setText(title);
        binding.peopleEmptyBody.setText(body);
        if (empty) {
            binding.peopleCount.setText("");
        }
    }

    private void reportError(String message) {
        if (binding == null) {
            return;
        }
        finishLoading();
        binding.peopleCount.setText("");
        showEmptyState(true, message, "Pull down to try again");
    }

    /**
     * Opens a conversation with the person whose card was tapped.
     *
     * This used to raise a toast saying messaging was "coming next", which was
     * not true: the chat is fully built and opens from listing detail,
     * favourites and the AI chat. What was missing is smaller and less obvious.
     *
     * roommate_profiles carries user_id but no email, and IndividualChatActivity
     * identifies the other party by email - so there was nothing here to open a
     * chat *with*. Rather than expose emails on a public table, the server
     * resolves it: POST /api/roommate-conversations takes { profileId,
     * userEmail }, looks the owner up, finds or creates the conversation, and
     * returns its id along with the other party. That is the same endpoint the
     * iOS app calls from its roommate detail screen.
     *
     * It answers 409 for your own profile, and 409 again when the owner has no
     * account to message - both of which are worth saying out loud rather than
     * failing silently, so the server's own message is shown.
     */
    @Override
    public void onRoommateClick(RoommateProfile profile) {
        AuthManager authManager = AuthManager.getInstance(requireContext());
        if (!authManager.isUserAuthenticated()) {
            Toast.makeText(requireContext(),
                    "Sign in from the Profile tab to send a message",
                    Toast.LENGTH_LONG).show();
            return;
        }

        final String me = authManager.getUserEmail();
        if (me == null || me.isEmpty()) {
            Toast.makeText(requireContext(),
                    "Could not tell which account you are signed in as",
                    Toast.LENGTH_LONG).show();
            return;
        }

        Toast.makeText(requireContext(),
                "Opening chat with " + profile.getDisplayName(),
                Toast.LENGTH_SHORT).show();

        new Thread(() -> {
            try {
                org.json.JSONObject body = new org.json.JSONObject();
                body.put("profileId", profile.getId());
                body.put("userEmail", me);

                okhttp3.OkHttpClient client = new okhttp3.OkHttpClient.Builder()
                        .connectTimeout(30, java.util.concurrent.TimeUnit.SECONDS)
                        .readTimeout(30, java.util.concurrent.TimeUnit.SECONDS)
                        .build();

                okhttp3.Request request = new okhttp3.Request.Builder()
                        .url("https://www.roomfinderai.com/api/roommate-conversations")
                        .post(okhttp3.RequestBody.create(
                                body.toString(),
                                okhttp3.MediaType.parse("application/json")))
                        .build();

                try (okhttp3.Response response = client.newCall(request).execute()) {
                    String payload = response.body() != null ? response.body().string() : "";
                    org.json.JSONObject parsed = new org.json.JSONObject(payload);

                    if (!response.isSuccessful() || !parsed.optBoolean("success", false)) {
                        // The server explains itself well here - own profile,
                        // no account behind the profile - so pass it through
                        // rather than replacing it with something vaguer.
                        final String message = parsed.optString("message",
                                "Could not open that conversation");
                        postToUi(() -> Toast.makeText(requireContext(), message, Toast.LENGTH_LONG).show());
                        return;
                    }

                    org.json.JSONObject data = parsed.getJSONObject("data");
                    final String conversationId = data.getString("id");
                    final String otherParty = data.optString("otherParty", "");

                    postToUi(() -> com.roomfinder.android.activities.IndividualChatActivity
                            .openExistingConversation(requireContext(), conversationId, otherParty));
                }
            } catch (Exception e) {
                Log.e("PeopleFragment", "Could not open a roommate conversation", e);
                postToUi(() -> Toast.makeText(requireContext(),
                        "Could not reach the server. Check your connection.",
                        Toast.LENGTH_LONG).show());
            }
        }).start();
    }

    /** Runs on the UI thread, but only while the fragment is still attached. */
    private void postToUi(Runnable action) {
        if (!isAdded() || getActivity() == null) {
            return;
        }
        getActivity().runOnUiThread(() -> {
            if (isAdded() && binding != null) {
                action.run();
            }
        });
    }

    @Override
    public void onSubleaseClick(SubleaseRequest request) {
        Toast.makeText(requireContext(),
                request.getLocationText() + " · " + request.getPriceText(),
                Toast.LENGTH_SHORT).show();
    }
}
