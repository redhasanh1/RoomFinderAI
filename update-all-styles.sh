#!/bin/bash

# List of main pages to update
PAGES=(
    "index.html"
    "sublease.html"
    "student-housing.html" 
    "listings.html"
    "ai-negotiator.html"
    "dashboard.html"
    "legal.html"
    "mortgage.html"
    "payment.html"
    "pricing.html"
    "profile.html"
    "support.html"
    "login.html"
    "signup.html"
)

echo "Updating styles for all pages..."

for page in "${PAGES[@]}"; do
    if [ -f "/app/frontend/$page" ]; then
        echo "Processing $page..."
        
        # Check if global-styles.css is already included
        if ! grep -q "css/global-styles.css" "/app/frontend/$page"; then
            # Find the closing </head> tag and add the CSS before it
            sed -i 's|</head>|    <link rel="stylesheet" href="css/global-styles.css">\n</head>|' "/app/frontend/$page"
            echo "  ✓ Added global-styles.css to $page"
        else
            echo "  - global-styles.css already included in $page"
        fi
        
        # Ensure RoomFinderAI logo uses brand-logo class
        sed -i 's|class="[^"]*gradient-text[^"]*">RoomFinderAI|class="text-xl md:text-2xl font-bold brand-logo font-display">RoomFinderAI|g' "/app/frontend/$page"
        sed -i 's|<div class="text-xl md:text-2xl font-bold[^>]*">RoomFinderAI|<div class="text-xl md:text-2xl font-bold brand-logo font-display">RoomFinderAI|g' "/app/frontend/$page"
        
    else
        echo "  ! $page not found, skipping..."
    fi
done

echo "Style updates completed!"