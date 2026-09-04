package com.roomfinder.android.adapters;

import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.ImageView;
import android.widget.TextView;

import androidx.annotation.NonNull;
import androidx.recyclerview.widget.RecyclerView;

import com.bumptech.glide.Glide;
import com.bumptech.glide.request.RequestOptions;
import com.roomfinder.android.R;
import com.roomfinder.android.models.RoommateProfile;
import com.roomfinder.android.models.SubleaseRequest;

import java.util.ArrayList;
import java.util.List;

/**
 * One adapter for both halves of the People tab. The two card shapes are
 * different enough to warrant separate layouts, but they never appear at the
 * same time, so a single adapter with two view types keeps the fragment simple.
 */
public class PeopleAdapter extends RecyclerView.Adapter<RecyclerView.ViewHolder> {

    private static final int TYPE_ROOMMATE = 0;
    private static final int TYPE_SUBLEASE = 1;

    public interface Listener {
        void onRoommateClick(RoommateProfile profile);

        void onSubleaseClick(SubleaseRequest request);
    }

    private final List<Object> items = new ArrayList<>();
    private final Listener listener;

    /**
     * Every card was stamped "Looking for a room" while the filter above the
     * list already said exactly that. A label that repeats the filter you just
     * chose is noise on every row, so it only appears when the list can
     * actually hold both kinds.
     */
    private boolean showKindBadge = true;

    public PeopleAdapter(Listener listener) {
        this.listener = listener;
    }

    public void setShowKindBadge(boolean showKindBadge) {
        this.showKindBadge = showKindBadge;
    }

    @SuppressWarnings("NotifyDataSetChanged")
    public void submitRoommates(List<RoommateProfile> profiles) {
        items.clear();
        if (profiles != null) {
            items.addAll(profiles);
        }
        notifyDataSetChanged();
    }

    @SuppressWarnings("NotifyDataSetChanged")
    public void submitSubleases(List<SubleaseRequest> requests) {
        items.clear();
        if (requests != null) {
            items.addAll(requests);
        }
        notifyDataSetChanged();
    }

    @Override
    public int getItemViewType(int position) {
        return items.get(position) instanceof RoommateProfile ? TYPE_ROOMMATE : TYPE_SUBLEASE;
    }

    @Override
    public int getItemCount() {
        return items.size();
    }

    @NonNull
    @Override
    public RecyclerView.ViewHolder onCreateViewHolder(@NonNull ViewGroup parent, int viewType) {
        LayoutInflater inflater = LayoutInflater.from(parent.getContext());
        if (viewType == TYPE_ROOMMATE) {
            return new RoommateHolder(inflater.inflate(R.layout.item_roommate_card, parent, false));
        }
        return new SubleaseHolder(inflater.inflate(R.layout.item_sublease_card, parent, false));
    }

    @Override
    public void onBindViewHolder(@NonNull RecyclerView.ViewHolder holder, int position) {
        Object item = items.get(position);
        if (holder instanceof RoommateHolder && item instanceof RoommateProfile) {
            ((RoommateHolder) holder).bind((RoommateProfile) item);
        } else if (holder instanceof SubleaseHolder && item instanceof SubleaseRequest) {
            ((SubleaseHolder) holder).bind((SubleaseRequest) item);
        }
    }

    class RoommateHolder extends RecyclerView.ViewHolder {
        private final TextView initials;
        private final ImageView avatar;
        private final TextView name;
        private final TextView location;
        private final TextView kind;
        private final TextView bio;
        private final TextView budget;

        RoommateHolder(@NonNull View itemView) {
            super(itemView);
            initials = itemView.findViewById(R.id.roommateInitials);
            avatar = itemView.findViewById(R.id.roommateAvatar);
            name = itemView.findViewById(R.id.roommateName);
            location = itemView.findViewById(R.id.roommateLocation);
            kind = itemView.findViewById(R.id.roommateKind);
            bio = itemView.findViewById(R.id.roommateBio);
            budget = itemView.findViewById(R.id.roommateBudget);
        }

        void bind(RoommateProfile profile) {
            name.setText(profile.getDisplayName());
            location.setText(profile.getLocationText());
            kind.setText(profile.getKindLabel());
            kind.setVisibility(showKindBadge ? View.VISIBLE : View.GONE);
            String budgetText = profile.getBudgetText();
            budget.setText(budgetText);
            budget.setTextColor(androidx.core.content.ContextCompat.getColor(
                    budget.getContext(),
                    "Budget not set".equals(budgetText) ? R.color.ink_tertiary : R.color.ink));
            initials.setText(profile.getInitials());

            String text = profile.getBio();
            if (text.isEmpty()) {
                bio.setVisibility(View.GONE);
            } else {
                bio.setVisibility(View.VISIBLE);
                bio.setText(text);
            }

            String photo = profile.getAvatarUrl();
            if (photo != null && !photo.trim().isEmpty()) {
                avatar.setVisibility(View.VISIBLE);
                Glide.with(avatar.getContext())
                        .load(photo)
                        .apply(RequestOptions.circleCropTransform())
                        .into(avatar);
            } else {
                // Initials on the brand gradient, rather than a blank disc.
                avatar.setVisibility(View.GONE);
                avatar.setImageDrawable(null);
            }

            itemView.setOnClickListener(v -> {
                if (listener != null) {
                    listener.onRoommateClick(profile);
                }
            });
        }
    }

    class SubleaseHolder extends RecyclerView.ViewHolder {
        private final TextView type;
        private final TextView price;
        private final TextView location;
        private final TextView dates;
        private final TextView summary;
        private final TextView description;

        SubleaseHolder(@NonNull View itemView) {
            super(itemView);
            type = itemView.findViewById(R.id.subleaseType);
            price = itemView.findViewById(R.id.subleasePrice);
            location = itemView.findViewById(R.id.subleaseLocation);
            dates = itemView.findViewById(R.id.subleaseDates);
            summary = itemView.findViewById(R.id.subleaseSummary);
            description = itemView.findViewById(R.id.subleaseDescription);
        }

        void bind(SubleaseRequest request) {
            type.setText(request.getTypeLabel());
            price.setText(request.getPriceText());
            location.setText(request.getLocationText());
            dates.setText(request.getDatesText());

            String line = request.getSummaryLine();
            if (line.isEmpty()) {
                summary.setVisibility(View.GONE);
            } else {
                summary.setVisibility(View.VISIBLE);
                summary.setText(line);
            }

            String body = request.getDescription();
            if (body.isEmpty()) {
                description.setVisibility(View.GONE);
            } else {
                description.setVisibility(View.VISIBLE);
                description.setText(body);
            }

            itemView.setOnClickListener(v -> {
                if (listener != null) {
                    listener.onSubleaseClick(request);
                }
            });
        }
    }
}
