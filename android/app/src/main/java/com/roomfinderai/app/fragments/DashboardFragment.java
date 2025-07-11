package com.roomfinderai.app.fragments;

import android.os.Bundle;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.TextView;
import android.widget.LinearLayout;
import androidx.fragment.app.Fragment;
import androidx.recyclerview.widget.GridLayoutManager;
import androidx.recyclerview.widget.LinearLayoutManager;
import androidx.recyclerview.widget.RecyclerView;
import com.roomfinderai.app.R;
import java.util.ArrayList;
import java.util.List;

public class DashboardFragment extends Fragment {
    
    private TextView totalListingsText;
    private TextView activeListingsText;
    private TextView totalViewsText;
    private TextView messagesCountText;
    private RecyclerView myListingsRecycler;
    private RecyclerView recentActivityRecycler;
    private LinearLayout quickActionsContainer;
    
    @Override
    public View onCreateView(LayoutInflater inflater, ViewGroup container, Bundle savedInstanceState) {
        View view = inflater.inflate(R.layout.fragment_dashboard, container, false);
        
        initializeViews(view);
        loadDashboardData();
        setupQuickActions();
        
        return view;
    }
    
    private void initializeViews(View view) {
        // Stats cards
        totalListingsText = view.findViewById(R.id.totalListingsText);
        activeListingsText = view.findViewById(R.id.activeListingsText);
        totalViewsText = view.findViewById(R.id.totalViewsText);
        messagesCountText = view.findViewById(R.id.messagesCountText);
        
        // RecyclerViews
        myListingsRecycler = view.findViewById(R.id.myListingsRecycler);
        recentActivityRecycler = view.findViewById(R.id.recentActivityRecycler);
        
        // Quick actions
        quickActionsContainer = view.findViewById(R.id.quickActionsContainer);
    }
    
    private void loadDashboardData() {
        // Load statistics (replace with actual API calls)
        totalListingsText.setText("12");
        activeListingsText.setText("8");
        totalViewsText.setText("3,456");
        messagesCountText.setText("24");
        
        // Setup my listings
        setupMyListings();
        
        // Setup recent activity
        setupRecentActivity();
    }
    
    private void setupMyListings() {
        List<ListingItem> myListings = new ArrayList<>();
        myListings.add(new ListingItem("Downtown Studio", "$1,200/mo", "Active", 234));
        myListings.add(new ListingItem("2BR Near Campus", "$1,800/mo", "Active", 567));
        myListings.add(new ListingItem("Shared Room", "$600/mo", "Inactive", 123));
        myListings.add(new ListingItem("Luxury Condo", "$3,500/mo", "Active", 890));
        
        MyListingsAdapter adapter = new MyListingsAdapter(myListings);
        myListingsRecycler.setLayoutManager(new GridLayoutManager(getContext(), 2));
        myListingsRecycler.setAdapter(adapter);
    }
    
    private void setupRecentActivity() {
        List<ActivityItem> activities = new ArrayList<>();
        activities.add(new ActivityItem("New message", "John Doe interested in Downtown Studio", "2 hours ago"));
        activities.add(new ActivityItem("Listing viewed", "Your 2BR Near Campus was viewed 15 times", "5 hours ago"));
        activities.add(new ActivityItem("Price update", "Luxury Condo price updated to $3,500", "1 day ago"));
        activities.add(new ActivityItem("New follower", "Sarah Smith started following your listings", "2 days ago"));
        
        RecentActivityAdapter adapter = new RecentActivityAdapter(activities);
        recentActivityRecycler.setLayoutManager(new LinearLayoutManager(getContext()));
        recentActivityRecycler.setAdapter(adapter);
    }
    
    private void setupQuickActions() {
        // Quick action buttons would be added here
        // For now, they're defined in the XML layout
    }
    
    // Data models
    private static class ListingItem {
        String title;
        String price;
        String status;
        int views;
        
        ListingItem(String title, String price, String status, int views) {
            this.title = title;
            this.price = price;
            this.status = status;
            this.views = views;
        }
    }
    
    private static class ActivityItem {
        String type;
        String description;
        String time;
        
        ActivityItem(String type, String description, String time) {
            this.type = type;
            this.description = description;
            this.time = time;
        }
    }
    
    // Adapters
    private class MyListingsAdapter extends RecyclerView.Adapter<MyListingsAdapter.ViewHolder> {
        private List<ListingItem> listings;
        
        MyListingsAdapter(List<ListingItem> listings) {
            this.listings = listings;
        }
        
        @Override
        public ViewHolder onCreateViewHolder(ViewGroup parent, int viewType) {
            View view = LayoutInflater.from(parent.getContext())
                .inflate(R.layout.item_dashboard_listing, parent, false);
            return new ViewHolder(view);
        }
        
        @Override
        public void onBindViewHolder(ViewHolder holder, int position) {
            ListingItem item = listings.get(position);
            holder.titleText.setText(item.title);
            holder.priceText.setText(item.price);
            holder.statusText.setText(item.status);
            holder.viewsText.setText(item.views + " views");
            
            // Set status color
            if ("Active".equals(item.status)) {
                holder.statusText.setTextColor(getResources().getColor(android.R.color.holo_green_dark));
            } else {
                holder.statusText.setTextColor(getResources().getColor(android.R.color.darker_gray));
            }
        }
        
        @Override
        public int getItemCount() {
            return listings.size();
        }
        
        class ViewHolder extends RecyclerView.ViewHolder {
            TextView titleText, priceText, statusText, viewsText;
            
            ViewHolder(View itemView) {
                super(itemView);
                titleText = itemView.findViewById(R.id.listingTitle);
                priceText = itemView.findViewById(R.id.listingPrice);
                statusText = itemView.findViewById(R.id.listingStatus);
                viewsText = itemView.findViewById(R.id.listingViews);
            }
        }
    }
    
    private class RecentActivityAdapter extends RecyclerView.Adapter<RecentActivityAdapter.ViewHolder> {
        private List<ActivityItem> activities;
        
        RecentActivityAdapter(List<ActivityItem> activities) {
            this.activities = activities;
        }
        
        @Override
        public ViewHolder onCreateViewHolder(ViewGroup parent, int viewType) {
            View view = LayoutInflater.from(parent.getContext())
                .inflate(R.layout.item_recent_activity, parent, false);
            return new ViewHolder(view);
        }
        
        @Override
        public void onBindViewHolder(ViewHolder holder, int position) {
            ActivityItem item = activities.get(position);
            holder.typeText.setText(item.type);
            holder.descriptionText.setText(item.description);
            holder.timeText.setText(item.time);
        }
        
        @Override
        public int getItemCount() {
            return activities.size();
        }
        
        class ViewHolder extends RecyclerView.ViewHolder {
            TextView typeText, descriptionText, timeText;
            
            ViewHolder(View itemView) {
                super(itemView);
                typeText = itemView.findViewById(R.id.activityType);
                descriptionText = itemView.findViewById(R.id.activityDescription);
                timeText = itemView.findViewById(R.id.activityTime);
            }
        }
    }
}