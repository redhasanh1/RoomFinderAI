package com.roomfinder.android.adapters;

import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.ImageView;
import android.widget.TextView;

import androidx.annotation.NonNull;
import androidx.recyclerview.widget.LinearLayoutManager;
import androidx.recyclerview.widget.RecyclerView;

import com.bumptech.glide.Glide;
import com.roomfinder.android.R;
import com.roomfinder.android.models.Listing;

import java.util.ArrayList;
import java.util.List;

/**
 * The Home feed, laid out the way the iOS app lays it out.
 *
 * iOS groups rooms into sections rather than one undifferentiated column:
 * "Featured", "Under $1,200", "Verified hosts" and "Good for sharing" are
 * horizontal shelves, and "All rooms" is the full-width list underneath. The
 * shelves only appear when they would hold at least two rooms, so a section is
 * never shown empty.
 *
 * Rows are flattened into a single RecyclerView (header / carousel / card)
 * instead of nesting vertical lists, which keeps recycling working.
 */
public class HomeFeedAdapter extends RecyclerView.Adapter<RecyclerView.ViewHolder> {

    private static final int TYPE_HEADER = 0;
    private static final int TYPE_CAROUSEL = 1;
    private static final int TYPE_CARD = 2;
    private static final int TYPE_SKELETON = 3;
    private static final int TYPE_SUMMARY = 4;

    /** How many placeholder cards to show before the first response lands. */
    private static final int SKELETON_ROWS = 4;

    private static final double BUDGET_CEILING = 1200;
    private static final int SHELF_LIMIT = 8;
    private static final int MIN_FOR_SHELF = 2;

    private final List<Listing> source;
    private final ListingsAdapter.OnListingClickListener listener;
    private final List<Row> rows = new ArrayList<>();
    private final RecyclerView.RecycledViewPool shelfPool = new RecyclerView.RecycledViewPool();

    /** True while a search or filter is active: iOS drops the curated shelves then. */
    private boolean showsSections = true;

    /** First load, nothing to show yet: draw the page's shape rather than a spinner. */
    private boolean loading = false;

    /** Set when the list is narrowed, so the footer can offer a way out. */
    private boolean filtered = false;
    private Runnable clearFiltersAction;

    /** Held only so submit() can tell whether a layout pass is in progress. */
    private RecyclerView attachedTo;

    private static class Row {
        final int type;
        final String title;
        final String subtitle;
        final List<Listing> listings;
        final Listing listing;
        final int sourceIndex;

        Row(int type, String title, String subtitle, List<Listing> listings, Listing listing, int sourceIndex) {
            this.type = type;
            this.title = title;
            this.subtitle = subtitle;
            this.listings = listings;
            this.listing = listing;
            this.sourceIndex = sourceIndex;
        }
    }

    public HomeFeedAdapter(List<Listing> listings, ListingsAdapter.OnListingClickListener listener) {
        this.source = listings;
        this.listener = listener;
        rebuild();
    }

    /**
     * When the list is narrowed, the curated shelves are in the way: someone who
     * asked for particular rooms does not want a "Featured" carousel above the
     * answer. Same rule as the iOS screen.
     */
    public void setShowsSections(boolean showsSections) {
        this.showsSections = showsSections;
    }

    public void setLoading(boolean loading) {
        this.loading = loading;
    }

    /** Tells the footer whether to offer "Clear filters", and what it does. */
    public void setFiltered(boolean filtered, Runnable clearFiltersAction) {
        this.filtered = filtered;
        this.clearFiltersAction = clearFiltersAction;
    }

    /**
     * Recomputes the sections from the backing list and refreshes the feed.
     * notifyDataSetChanged() is final on RecyclerView.Adapter, so the rebuild
     * has to hang off a method of our own that callers use instead.
     */
    @SuppressWarnings("NotifyDataSetChanged")
    public void submit() {
        // RecyclerView forbids changing the adapter while it is laying out, and
        // throws "Inconsistency detected. Invalid view holder adapter position"
        // if you do. This crashed the app on launch on a tablet-sized screen:
        // the taller viewport binds a shelf that is still in scrap when the
        // second load lands and moves it (oldPos=5 -> position=18), and the
        // whole process died. Deferring to the next frame is the documented
        // way out, and it is cheap - the common case is not mid-layout.
        if (attachedTo != null && (attachedTo.isComputingLayout() || attachedTo.isAnimating())) {
            attachedTo.post(this::submit);
            return;
        }
        rebuild();
        notifyDataSetChanged();
    }

    @Override
    public void onAttachedToRecyclerView(@NonNull RecyclerView recyclerView) {
        super.onAttachedToRecyclerView(recyclerView);
        attachedTo = recyclerView;
    }

    @Override
    public void onDetachedFromRecyclerView(@NonNull RecyclerView recyclerView) {
        super.onDetachedFromRecyclerView(recyclerView);
        if (attachedTo == recyclerView) {
            attachedTo = null;
        }
    }

    private void rebuild() {
        rows.clear();

        if (source == null || source.isEmpty()) {
            // Placeholders keep the filter chips and the page rhythm in place
            // while the first response is in flight.
            if (loading) {
                for (int i = 0; i < SKELETON_ROWS; i++) {
                    rows.add(new Row(TYPE_SKELETON, null, null, null, null, -1));
                }
            }
            return;
        }

        List<Listing> rooms = new ArrayList<>(source);

        if (showsSections) {
            List<Listing> featured = addShelf("Featured", "Newest rooms on RoomFinderAI", rooms);

            List<Listing> affordable = new ArrayList<>();
            List<Listing> verified = new ArrayList<>();
            List<Listing> shared = new ArrayList<>();
            for (Listing room : rooms) {
                if (room.getSafePrice() > 0 && room.getSafePrice() <= BUDGET_CEILING) {
                    affordable.add(room);
                }
                if (room.isUserVerified()) {
                    verified.add(room);
                }
                if (room.getBedrooms() >= 2) {
                    shared.add(room);
                }
            }

            addThemedShelf("Under $1,200", "Easier on the rent", affordable, featured);
            addThemedShelf("Verified hosts", "Identity checked by us", verified, featured);
            addThemedShelf("Good for sharing", "Two bedrooms or more", shared, featured);
        }

        // Everything, so no room is reachable only through a themed shelf.
        String allTitle = rooms.size() == 1 ? "1 room" : rooms.size() + " rooms";
        rows.add(new Row(TYPE_HEADER, showsSections ? "All rooms" : allTitle, null, null, null, -1));
        for (int i = 0; i < rooms.size(); i++) {
            rows.add(new Row(TYPE_CARD, null, null, null, rooms.get(i), i));
        }

        // The count, and one tap back to everything.
        rows.add(new Row(TYPE_SUMMARY, allTitle, null, null, null, -1));
    }

    /**
     * A themed shelf, showing only rooms "Featured" is not already showing.
     *
     * Featured is the newest rooms, so while the catalogue is small it holds
     * most of them - and every themed shelf below it came out as the same first
     * three cards over again. On a tablet both shelves are on screen at once and
     * the repetition is the first thing you notice. Subtracting Featured makes
     * each shelf additive: scrolling past one always shows rooms you have not
     * seen. If too few are left to be worth a row, the shelf is dropped rather
     * than padded back out with duplicates.
     */
    private void addThemedShelf(String title, String subtitle,
                                List<Listing> candidate, List<Listing> featured) {
        List<Listing> fresh = new ArrayList<>();
        for (Listing room : candidate) {
            if (!featured.contains(room)) {
                fresh.add(room);
            }
        }
        if (fresh.size() >= MIN_FOR_SHELF) {
            addShelf(title, subtitle, fresh);
        }
    }

    /** Adds a shelf and returns the rooms it actually shows, after the cap. */
    private List<Listing> addShelf(String title, String subtitle, List<Listing> listings) {
        List<Listing> capped = listings.size() > SHELF_LIMIT
                ? new ArrayList<>(listings.subList(0, SHELF_LIMIT))
                : new ArrayList<>(listings);
        rows.add(new Row(TYPE_HEADER, title, subtitle, null, null, -1));
        rows.add(new Row(TYPE_CAROUSEL, null, null, capped, null, -1));
        return capped;
    }

    @Override
    public int getItemViewType(int position) {
        return rows.get(position).type;
    }

    @Override
    public int getItemCount() {
        return rows.size();
    }

    @NonNull
    @Override
    public RecyclerView.ViewHolder onCreateViewHolder(@NonNull ViewGroup parent, int viewType) {
        LayoutInflater inflater = LayoutInflater.from(parent.getContext());
        switch (viewType) {
            case TYPE_HEADER:
                return new HeaderHolder(inflater.inflate(R.layout.item_section_header, parent, false));
            case TYPE_CAROUSEL:
                return new CarouselHolder(inflater.inflate(R.layout.item_section_carousel, parent, false));
            case TYPE_SKELETON:
                return new SkeletonHolder(inflater.inflate(R.layout.item_listing_skeleton_card, parent, false));
            case TYPE_SUMMARY:
                return new SummaryHolder(inflater.inflate(R.layout.item_feed_summary, parent, false));
            default:
                return new CardHolder(inflater.inflate(R.layout.item_listing_card, parent, false));
        }
    }

    @Override
    public void onBindViewHolder(@NonNull RecyclerView.ViewHolder holder, int position) {
        Row row = rows.get(position);
        if (holder instanceof HeaderHolder) {
            ((HeaderHolder) holder).bind(row);
        } else if (holder instanceof CarouselHolder) {
            ((CarouselHolder) holder).bind(row);
        } else if (holder instanceof CardHolder) {
            ((CardHolder) holder).bind(row.listing, row.sourceIndex);
        } else if (holder instanceof SummaryHolder) {
            ((SummaryHolder) holder).bind(row);
        }
    }

    static class SkeletonHolder extends RecyclerView.ViewHolder {
        SkeletonHolder(@NonNull View itemView) {
            super(itemView);
        }
    }

    class SummaryHolder extends RecyclerView.ViewHolder {
        private final TextView summary;
        private final TextView clear;

        SummaryHolder(@NonNull View itemView) {
            super(itemView);
            summary = itemView.findViewById(R.id.summaryText);
            clear = itemView.findViewById(R.id.clearFiltersAction);
        }

        void bind(Row row) {
            summary.setText(row.title);
            clear.setVisibility(filtered ? View.VISIBLE : View.GONE);
            clear.setOnClickListener(v -> {
                if (clearFiltersAction != null) {
                    clearFiltersAction.run();
                }
            });
        }
    }

    static class HeaderHolder extends RecyclerView.ViewHolder {
        private final TextView title;
        private final TextView subtitle;

        HeaderHolder(@NonNull View itemView) {
            super(itemView);
            title = itemView.findViewById(R.id.sectionTitle);
            subtitle = itemView.findViewById(R.id.sectionSubtitle);
        }

        void bind(Row row) {
            title.setText(row.title);
            if (row.subtitle == null || row.subtitle.isEmpty()) {
                subtitle.setVisibility(View.GONE);
            } else {
                subtitle.setVisibility(View.VISIBLE);
                subtitle.setText(row.subtitle);
            }
        }
    }

    class CarouselHolder extends RecyclerView.ViewHolder {
        private final RecyclerView recycler;

        CarouselHolder(@NonNull View itemView) {
            super(itemView);
            recycler = (RecyclerView) itemView;
            recycler.setLayoutManager(new LinearLayoutManager(itemView.getContext(),
                    LinearLayoutManager.HORIZONTAL, false));
            recycler.setRecycledViewPool(shelfPool);
            recycler.setNestedScrollingEnabled(false);
            // The row's height is fixed by its layout, so measurement can skip
            // the children entirely.
            recycler.setHasFixedSize(true);
        }

        void bind(Row row) {
            recycler.setAdapter(new ShelfAdapter(row.listings, listener));
        }
    }

    class CardHolder extends RecyclerView.ViewHolder {
        private final ImageView image;
        private final ImageView favorite;
        private final TextView verified;
        private final TextView title;
        private final TextView location;
        private final TextView price;
        private final TextView summary;

        CardHolder(@NonNull View itemView) {
            super(itemView);
            image = itemView.findViewById(R.id.listingImage);
            favorite = itemView.findViewById(R.id.favoriteButton);
            verified = itemView.findViewById(R.id.verifiedBadge);
            title = itemView.findViewById(R.id.titleText);
            location = itemView.findViewById(R.id.locationText);
            price = itemView.findViewById(R.id.priceText);
            summary = itemView.findViewById(R.id.bedBathText);
        }

        void bind(Listing listing, int index) {
            title.setText(listing.getTitle());
            location.setText(listing.getLocation());
            price.setText(listing.getPriceText());
            summary.setText(listing.getSummaryLine());
            verified.setVisibility(listing.isUserVerified() ? View.VISIBLE : View.GONE);
            favorite.setSelected(listing.isFavorite());

            String url = listing.getFirstImageUrl();
            if (url != null && !url.isEmpty()) {
                Glide.with(image.getContext())
                        .load(url)
                        .placeholder(R.drawable.placeholder_image)
                        .error(R.drawable.placeholder_image)
                        .centerCrop()
                        .override(720, 400)
                        .into(image);
            } else {
                image.setImageResource(R.drawable.placeholder_image);
            }

            itemView.setOnClickListener(v -> {
                if (listener != null) {
                    listener.onListingClick(listing);
                }
            });
            favorite.setOnClickListener(v -> {
                if (listener != null) {
                    listener.onFavoriteClick(listing, index);
                }
            });
        }
    }
}
