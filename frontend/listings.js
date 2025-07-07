        // Map Variables
        let map;
        let markers = [];
        let markerClusterGroup;

        // Initialize Map with Retry Logic
        function initMap() {
            console.log('Attempting to initialize map');
            const mapElement = document.getElementById('map');
            const mapError = document.getElementById('map-error');

            if (!mapElement) {
                console.error('Map container not found');
                if (mapError) mapError.style.display = 'block';
                return false;
            }

            try {
                // Set default view to Toronto area for better initial positioning
                map = L.map('map').setView([43.6532, -79.3832], 10);
                
                L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
                    attribution: '© <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors',
                    maxZoom: 18,
                    minZoom: 2
                }).addTo(map);

                // Initialize marker cluster group with simpler settings
                markerClusterGroup = L.markerClusterGroup({
                    maxClusterRadius: 50,
                    showCoverageOnHover: false,
                    zoomToBoundsOnClick: true,
                    spiderfyOnMaxZoom: true,
                    iconCreateFunction: function(cluster) {
                        const count = cluster.getChildCount();
                        return L.divIcon({
                            html: `<div style="background-color: #3b82f6; color: white; border-radius: 50%; width: 35px; height: 35px; display: flex; align-items: center; justify-content: center; font-weight: bold; border: 2px solid white; box-shadow: 0 2px 6px rgba(0,0,0,0.3); font-size: 12px;">${count}</div>`,
                            className: 'marker-cluster',
                            iconSize: [35, 35]
                        });
                    }
                });
                map.addLayer(markerClusterGroup);

                // Force map to render properly
                setTimeout(() => {
                    map.invalidateSize();
                    console.log('Map size invalidated and rendered');
                }, 500);

                if (mapError) mapError.style.display = 'none';
                console.log('Map initialized successfully with clustering at Toronto view');
                return true;
            } catch (error) {
                console.error('Failed to initialize map:', error);
                if (mapError) mapError.style.display = 'block';
                return false;
            }
        }

        // Simple and reliable geocoding with fallback coordinates
        async function geocodeLocation(location, retries = 2, delay = 1000) {
            console.log('Geocoding location:', location);
            
            // Default coordinates for common cities if geocoding fails
            const cityDefaults = {
                'toronto': { lat: 43.6532, lon: -79.3832 },
                'vancouver': { lat: 49.2827, lon: -123.1207 },
                'montreal': { lat: 45.5017, lon: -73.5673 },
                'calgary': { lat: 51.0447, lon: -114.0719 },
                'ottawa': { lat: 45.4215, lon: -75.6972 },
                'london': { lat: 51.5074, lon: -0.1278 },
                'new york': { lat: 40.7128, lon: -74.0060 },
                'los angeles': { lat: 34.0522, lon: -118.2437 }
            };
            
            try {
                const encodedQuery = encodeURIComponent(location.trim());
                console.log('Attempting to geocode:', encodedQuery);
                
                const response = await fetch(`https://nominatim.openstreetmap.org/search?q=${encodedQuery}&format=json&limit=1`, {
                    headers: {
                        'User-Agent': 'RoomFinder/1.0'
                    }
                });

                if (response.ok) {
                    const data = await response.json();
                    console.log('Geocode API response:', data);

                    if (data && data.length > 0) {
                        const result = data[0];
                        const coords = {
                            lat: parseFloat(result.lat),
                            lon: parseFloat(result.lon),
                            display_name: result.display_name
                        };
                        
                        // Validate coordinates
                        if (coords.lat >= -90 && coords.lat <= 90 && coords.lon >= -180 && coords.lon <= 180) {
                            console.log('✅ Successfully geocoded:', location, '→', coords);
                            return coords;
                        }
                    }
                }
            } catch (error) {
                console.error('Geocoding API error:', error);
            }
            
            // Fallback: try to match city name with defaults
            const cityName = location.toLowerCase().split(',')[1]?.trim() || location.toLowerCase().split(',')[0]?.trim() || '';
            console.log('Trying fallback for city:', cityName);
            
            for (const [city, coords] of Object.entries(cityDefaults)) {
                if (cityName.includes(city) || city.includes(cityName)) {
                    console.log('🔄 Using fallback coordinates for', city, ':', coords);
                    return {
                        lat: coords.lat + (Math.random() - 0.5) * 0.01, // Add small random offset
                        lon: coords.lon + (Math.random() - 0.5) * 0.01,
                        display_name: `${location} (approximate)`
                    };
                }
            }
            
            // Last resort: use Toronto area with random offset
            console.log('⚠️ Using default Toronto area for:', location);
            return {
                lat: 43.6532 + (Math.random() - 0.5) * 0.1,
                lon: -79.3832 + (Math.random() - 0.5) * 0.1,
                display_name: `${location} (default location)`
            };
        }

        // Update Map with Listings - Simplified and More Reliable
        async function updateMap(listings) {
            console.log('🗺️ Starting updateMap with', listings.length, 'listings');
            
            // Ensure map is initialized
            if (!map || !markerClusterGroup) {
                console.log('Map not ready, initializing...');
                if (!initMap()) {
                    console.error('❌ Failed to initialize map');
                    return;
                }
                // Wait for map to be ready
                await new Promise(resolve => setTimeout(resolve, 1000));
            }

            // Clear existing markers
            console.log('Clearing existing markers...');
            markerClusterGroup.clearLayers();
            markers = [];
            const validCoordinates = [];
            let successfulMarkers = 0;

            console.log('Processing listings for markers...');
            
            for (let i = 0; i < listings.length; i++) {
                const listing = listings[i];
                console.log(`\n📍 Processing listing ${i + 1}/${listings.length}:`, listing.title);
                
                const location = `${listing.street}, ${listing.city}, ${listing.postalCode}`;
                console.log('Full address:', location);
                
                if (!listing.street || !listing.city) {
                    console.warn('⚠️ Listing missing required address components:', listing);
                    // Still try to geocode with available data
                }

                try {
                    // Get coordinates (this function now always returns coordinates)
                    const coords = await geocodeLocation(location);
                    console.log('Got coordinates:', coords);

                    if (coords && !isNaN(coords.lat) && !isNaN(coords.lon)) {
                        // Create simple, reliable marker
                        const marker = L.marker([coords.lat, coords.lon], {
                            title: listing.title
                        });

                        // Create simple popup
                        const popupContent = `
                            <div style="min-width: 200px; font-family: Arial, sans-serif;">
                                <h3 style="margin: 0 0 8px 0; font-size: 16px; font-weight: bold; color: #1f2937;">${listing.title}</h3>
                                <div style="color: #059669; font-weight: bold; font-size: 18px; margin-bottom: 6px;">$${listing.price.toLocaleString()}/mo</div>
                                <div style="color: #6b7280; font-size: 13px; margin-bottom: 8px;">${location}</div>
                                <div style="font-size: 12px; color: #6b7280; margin-bottom: 10px;">
                                    ${listing.bedrooms} Bed • ${listing.house_type} • ${listing.utilities}
                                </div>
                                <a href="/listing_details?id=${listing.id}" style="background-color: #3b82f6; color: white; padding: 6px 12px; border-radius: 4px; text-decoration: none; font-size: 12px; font-weight: 500;">View Details</a>
                            </div>
                        `;

                        marker.bindPopup(popupContent, { maxWidth: 250 });
                        
                        // Add to cluster group
                        markerClusterGroup.addLayer(marker);
                        markers.push(marker);
                        validCoordinates.push([coords.lat, coords.lon]);
                        successfulMarkers++;
                        
                        console.log(`✅ Added marker ${successfulMarkers} for:`, listing.title, 'at', [coords.lat, coords.lon]);
                    } else {
                        console.error('❌ Invalid coordinates for:', listing.title);
                    }
                } catch (error) {
                    console.error('❌ Error processing listing:', listing.title, error);
                }

                // Small delay between geocoding requests
                if (i < listings.length - 1) {
                    await new Promise(resolve => setTimeout(resolve, 200));
                }
            }

            console.log(`\n🎯 Map update complete! Successfully added ${successfulMarkers} markers out of ${listings.length} listings`);

            // Adjust map view - simplified and reliable
            if (validCoordinates.length > 0) {
                console.log('Setting map view for', validCoordinates.length, 'markers');
                
                if (validCoordinates.length === 1) {
                    // Single marker - zoom to street level
                    map.setView(validCoordinates[0], 14);
                    console.log('✅ Map centered on single marker at zoom 14');
                } else {
                    // Multiple markers - fit bounds
                    try {
                        const bounds = L.latLngBounds(validCoordinates);
                        map.fitBounds(bounds, { 
                            padding: [20, 20],
                            maxZoom: 15
                        });
                        console.log('✅ Map fitted to bounds for', validCoordinates.length, 'markers');
                    } catch (error) {
                        console.error('Error fitting bounds, using default view:', error);
                        map.setView([43.6532, -79.3832], 10);
                    }
                }
            } else {
                console.log('⚠️ No markers to display, keeping default view');
                map.setView([43.6532, -79.3832], 10);
            }

            // Force map refresh
            setTimeout(() => {
                if (map) {
                    map.invalidateSize();
                    console.log('✅ Map refreshed and invalidated');
                }
            }, 500);

            // Log final state
            console.log('📊 Final map state:');
            console.log('- Total listings processed:', listings.length);
            console.log('- Successful markers:', successfulMarkers);
            console.log('- Markers in cluster group:', markerClusterGroup.getLayers().length);
            console.log('- Valid coordinates:', validCoordinates.length);
        }

        // Authentication check and header update
        async function initializeListingsPage() {
            console.log('DOMContentLoaded event fired');
            // Default profile icon - SVG data URI with user icon
            const defaultProfileIcon = 'data:image/svg+xml;base64,' + btoa(`
                <svg xmlns="http://www.w3.org/2000/svg" width="100" height="100" viewBox="0 0 100 100">
                    <rect width="100" height="100" rx="50" fill="#E5E7EB"/>
                    <path d="M50 45C56.075 45 61 40.075 61 34C61 27.925 56.075 23 50 23C43.925 23 39 27.925 39 34C39 40.075 43.925 45 50 45Z" fill="#9CA3AF"/>
                    <path d="M30 77C30 77 30 66.103 30 62C30 55.373 36.268 50 44 50H56C63.732 50 70 55.373 70 62C70 66.103 70 77 70 77" fill="#9CA3AF"/>
                </svg>
            `.trim());
            
            const profileImages = [defaultProfileIcon];
            const currentUser = JSON.parse(localStorage.getItem('currentUser'));
            console.log('Current user:', currentUser);
            const authSection = document.getElementById('authSection');

            if (!currentUser) {
                console.log('No current user, redirecting to login');
                window.location.href = '/login';
                return;
            }

            // Set current user email for RLS
            try {
                const { error } = await supabase.rpc('set_current_user_email', { email: currentUser.email });
                console.log('RPC set_current_user_email response:', { error });
                if (error) {
                    console.error('Error setting current user email:', error);
                    alert('Failed to initialize session: ' + error.message);
                    return;
                }
                console.log('Current user email set for RLS:', currentUser.email);
            } catch (err) {
                console.error('RPC call failed:', err);
                alert('Failed to initialize session. Please check your connection.');
                return;
            }

            // Force update to new default profile icon if user has old placeholder images
            const oldPlaceholderPatterns = [
                'https://via.placeholder.com/',
                'https://ui-avatars.com/api/',
                'data:image/svg+xml;base64,PHN2ZyB3aWR0aD0iNDAiIGhlaWdodD0iNDA',
                'PHN2ZyB3aWR0aD0iNDAiIGhlaWdodD0iNDA'
            ];
            
            const needsUpdate = !currentUser.profileImage || 
                oldPlaceholderPatterns.some(pattern => currentUser.profileImage.includes(pattern));
            
            if (needsUpdate) {
                currentUser.profileImage = profileImages[Math.floor(Math.random() * profileImages.length)];
                let users = JSON.parse(localStorage.getItem('users')) || [];
                users = users.map(u => u.email === currentUser.email ? currentUser : u);
                localStorage.setItem('users', JSON.stringify(users));
                localStorage.setItem('currentUser', JSON.stringify(currentUser));
            }
            authSection.innerHTML = `
                <div class="flex items-center space-x-2">
                    <div class="relative">
                        <span id="profileNotificationBadge" class="absolute -top-2 -right-2 bg-red-500 text-white rounded-full w-5 h-5 text-xs flex items-center justify-center hidden z-10">0</span>
                        <a href="/profile">
                            <img id="profileLogo" src="${currentUser.profileImage}" alt="Profile" class="w-10 h-10 rounded-full profile-logo">
                        </a>
                    </div>
                </div>
            `;

            // Initialize map
            initMap();
            setupChat();
            setupMessagingPanel();
            
            // Initialize connection monitoring
            initializeConnectionMonitoring();
            
            // Enable diagnostics panel with Ctrl+Shift+D
            document.addEventListener('keydown', (e) => {
                if (e.ctrlKey && e.shiftKey && e.key === 'D') {
                    e.preventDefault();
                    if (document.getElementById('chat-diagnostics-panel')) {
                        toggleDiagnosticsPanel();
                    } else {
                        createChatDiagnosticsPanel();
                    }
                }
            });
            
            await displayListings();
        }


        // Initialize Typo.js for autocorrect
        const typo = new Typo('en_US', false, false, {
            dictionaryPath: 'https://unpkg.com/typo-js@1.2.3/dictionaries'
        });
        typo.dictionary['roomfinder'] = 1;
        typo.dictionary['wifi'] = 1;
        typo.dictionary['appartment'] = 1;
        typo.dictionary['condo'] = 1;
        typo.dictionary['sublease'] = 1;
        typo.dictionary['negoitator'] = 1;

        // Smart Autocorrect - preserves addresses, numbers, and proper nouns
        function autocorrectInput(input) {
            if (typeof input !== 'string' || !input) return input;
            
            const words = input.split(' ');
            const correctedWords = words.map(word => {
                const originalWord = word;
                
                // Skip correction for:
                // 1. Numbers (including mixed alphanumeric like postal codes)
                if (/\d/.test(word)) {
                    console.log(`Skipping autocorrect for number/code: ${word}`);
                    return word;
                }
                
                // 2. Capitalized words (likely proper nouns like street names)
                if (/^[A-Z]/.test(word)) {
                    console.log(`Skipping autocorrect for proper noun: ${word}`);
                    return word;
                }
                
                // 3. Common address terms
                const addressTerms = ['street', 'road', 'avenue', 'drive', 'lane', 'court', 'place', 'way', 'blvd', 'ave', 'rd', 'dr', 'st', 'ln', 'ct', 'pl'];
                if (addressTerms.includes(word.toLowerCase())) {
                    console.log(`Skipping autocorrect for address term: ${word}`);
                    return word;
                }
                
                // 4. Words that are already correctly spelled
                if (typo.check(word)) {
                    return word;
                }
                
                // 5. Only correct if word is clearly misspelled and suggestion is confident
                const suggestions = typo.suggest(word);
                if (suggestions.length > 0) {
                    const suggestion = suggestions[0];
                    // Only auto-correct if the suggestion is significantly different 
                    // and the original word is clearly wrong (not just uncommon)
                    if (word.length > 3 && suggestion.length > 2) {
                        console.log(`Autocorrect: ${word} -> ${suggestion}`);
                        return suggestion;
                    }
                }
                
                console.log(`No autocorrect applied to: ${word}`);
                return word;
            });
            
            return correctedWords.join(' ');
        }

        // Safe autocorrect for addresses - only basic cleanup
        function cleanAddressInput(input) {
            if (typeof input !== 'string') return '';
            return input.trim()
                .replace(/\s+/g, ' ')  // Multiple spaces to single
                .replace(/[^\w\s\-.,#]/g, ''); // Remove special chars except basic ones
        }

        function sanitizeInput(input) {
            if (typeof input !== 'string') return '';
            return input.replace(/[^a-zA-Z0-9\s,.-]/g, '').trim();
        }

        // Load cities.json for autocomplete
        let cities = [];
        fetch('https://unpkg.com/cities.json@1.1.0/cities.json')
            .then(response => response.json())
            .then(data => {
                cities = data;
                console.log('Cities loaded:', cities.length);
            })
            .catch(error => {
                console.error('Error loading cities:', error);
                alert('Failed to load city data. Please enter city manually.');
                document.getElementById('city').placeholder = 'Enter city manually (e.g., Toronto)';
            });

        // Autocomplete logic for city
        const cityInput = document.getElementById('city');
        const cityDropdown = document.getElementById('city-autocomplete-dropdown');
        let debounceTimeout;

        function showCitySuggestions(input) {
            cityDropdown.innerHTML = '';
            cityDropdown.classList.add('hidden');
            if (!input || cities.length === 0) return;

            const filtered = cities
                .filter(city => 
                    city.name.toLowerCase().startsWith(input.toLowerCase()) ||
                    city.name.toLowerCase().includes(input.toLowerCase())
                )
                .slice(0, 10)
                .map(city => ({
                    display: `${city.name}${city.admin_name ? `, ${city.admin_name}` : ''}, ${city.country}`,
                    value: city
                }));

            if (filtered.length === 0) {
                const item = document.createElement('div');
                item.className = 'autocomplete-item text-gray-500';
                item.textContent = 'No matching cities';
                cityDropdown.appendChild(item);
                cityDropdown.classList.remove('hidden');
                return;
            }

            filtered.forEach(loc => {
                const item = document.createElement('div');
                item.className = 'autocomplete-item';
                item.textContent = loc.display;
                item.addEventListener('click', () => {
                    cityInput.value = loc.display;
                    cityDropdown.classList.add('hidden');
                    console.log('Selected city:', loc.display);
                });
                cityDropdown.appendChild(item);
            });

            cityDropdown.classList.remove('hidden');
            console.log('Showing city suggestions for:', input, filtered.map(f => f.display));
        }

        cityInput.addEventListener('input', () => {
            clearTimeout(debounceTimeout);
            debounceTimeout = setTimeout(() => {
                const value = cityInput.value.trim();
                console.log('City input event:', value);
                showCitySuggestions(value);
            }, 300);
        });

        cityInput.addEventListener('keydown', (e) => {
            if (e.key === 'Enter' && !cityDropdown.classList.contains('hidden')) {
                const firstItem = cityDropdown.querySelector('.autocomplete-item:not(.text-gray-500)');
                if (firstItem) {
                    cityInput.value = firstItem.textContent;
                    cityDropdown.classList.add('hidden');
                    console.log('Enter key selected city:', firstItem.textContent);
                }
                e.preventDefault();
            }
        });

        document.addEventListener('click', (e) => {
            if (!cityInput.contains(e.target) && !cityDropdown.contains(e.target)) {
                cityDropdown.classList.add('hidden');
                console.log('City dropdown hidden');
            }
        });

        // File upload and preview
        const mediaInput = document.getElementById('media');
        const mediaPreview = document.getElementById('mediaPreview');
        let uploadedFiles = [];

        mediaInput.addEventListener('change', () => {
            mediaPreview.innerHTML = '';
            uploadedFiles = [];
            const files = Array.from(mediaInput.files);
            let totalSize = 0;

            files.forEach(file => {
                totalSize += file.size;
                if (totalSize > 10 * 1024 * 1024) {
                    alert('Total file size exceeds 10MB limit.');
                    mediaInput.value = '';
                    mediaPreview.innerHTML = '';
                    uploadedFiles = [];
                    return;
                }

                const reader = new FileReader();
                reader.onload = (e) => {
                    const dataUrl = e.target.result;
                    uploadedFiles.push({ name: file.name, type: file.type, data: dataUrl, file: file });
                    const previewElement = file.type.startsWith('image/')
                        ? `<img src="${dataUrl}" alt="${file.name}">`
                        : `<video src="${dataUrl}" controls></video>`;
                    const previewContainer = document.createElement('div');
                    previewContainer.innerHTML = previewElement;
                    mediaPreview.appendChild(previewContainer.firstChild);
                    console.log('Preview added for file:', file.name);
                };
                reader.readAsDataURL(file);
            });
            console.log('Files selected:', files.map(f => f.name));
        });

        // Upload media to Supabase
        async function uploadMedia(files) {
            const uploadedMedia = [];
            const storageApiUrl = `${SUPABASE_URL}/storage/v1/object/listing-media/Photos`;

            for (const fileObj of files) {
                const file = fileObj.file;
                const fileName = `${Date.now()}-${file.name.replace(/[^a-zA-Z0-9.-]/g, '_')}`;
                const filePath = fileName;

                const extension = file.name.split('.').pop().toLowerCase();
                let contentType;
                switch (extension) {
                    case 'jpg':
                    case 'jpeg':
                        contentType = 'image/jpeg';
                        break;
                    case 'png':
                        contentType = 'image/png';
                        break;
                    case 'mp4':
                        contentType = 'video/mp4';
                        break;
                    default:
                        contentType = 'application/octet-stream';
                }

                console.log('Processing file:', { name: file.name, detectedType: file.type, assignedType: contentType });

                if (contentType.startsWith('image/')) {
                    const reader = new FileReader();
                    await new Promise((resolve, reject) => {
                        reader.onload = (e) => {
                            const img = new Image();
                            img.onload = () => resolve();
                            img.onerror = () => reject(new Error('Invalid image file'));
                            img.src = e.target.result;
                        };
                        reader.readAsDataURL(file);
                    });
                }

                const formData = new FormData();
                formData.append('file', file);
                formData.append('cacheControl', '3600');
                formData.append('upsert', 'false');

                try {
                    const response = await fetch(`${storageApiUrl}/${filePath}`, {
                        method: 'POST',
                        headers: {
                            'Authorization': `Bearer ${SUPABASE_ANON_KEY}`,
                            'apikey': SUPABASE_ANON_KEY
                        },
                        body: formData
                    });

                    if (!response.ok) {
                        const errorText = await response.text();
                        throw new Error(`Upload failed: ${response.status} - ${errorText}`);
                    }

                    const publicUrl = `${SUPABASE_URL}/storage/v1/object/public/listing-media/Photos/${filePath}`;
                    let verifyResponse = await fetch(publicUrl, { method: 'HEAD' });
                    let serverContentType = verifyResponse.headers.get('Content-Type');
                    console.log('Server-reported content type:', { name: file.name, serverContentType });

                    if (serverContentType !== contentType) {
                        console.warn('MIME type mismatch detected. Server returned:', serverContentType, 'Expected:', contentType);
                        await fetch(`${storageApiUrl}/${filePath}`, {
                            method: 'DELETE',
                            headers: {
                            'Authorization': `Bearer ${SUPABASE_ANON_KEY}`,
                            'apikey': SUPABASE_ANON_KEY
                            }
                        });

                        const reUploadFormData = new FormData();
                        reUploadFormData.append('file', file);
                        reUploadFormData.append('cacheControl', '3600');
                        reUploadFormData.append('upsert', 'false');
                        reUploadFormData.append('contentType', contentType);

                        const reUploadResponse = await fetch(`${storageApiUrl}/${filePath}`, {
                            method: 'POST',
                            headers: {
                                'Authorization': `Bearer ${SUPABASE_ANON_KEY}`,
                                'apikey': SUPABASE_ANON_KEY
                            },
                            body: reUploadFormData
                        });

                        if (!reUploadResponse.ok) {
                            const errorText = await reUploadResponse.text();
                            throw new Error(`Re-upload failed: ${reUploadResponse.status} - ${errorText}`);
                        }

                        verifyResponse = await fetch(publicUrl, { method: 'HEAD' });
                        serverContentType = verifyResponse.headers.get('Content-Type');
                        console.log('After re-upload, server-reported content type:', { name: file.name, serverContentType });

                        if (serverContentType !== contentType) {
                            throw new Error(`Failed to set correct MIME type for ${file.name}. Server returned ${serverContentType}, expected ${contentType}.`);
                        }
                    }

                    console.log('Uploaded media:', { name: file.name, type: contentType, url: publicUrl });
                    uploadedMedia.push({
                        name: file.name,
                        type: contentType,
                        url: publicUrl,
                        data: fileObj.data
                    });
                } catch (err) {
                    console.error('Upload failed for', file.name, err);
                    throw err;
                }
            }
            return uploadedMedia;
        }

        // Fetch listings from Supabase
        // Enhanced listings cache and pagination
        let listingsCache = new Map();
        let currentPage = 0;
        const LISTINGS_PER_PAGE = 20;
        let isLoading = false;
        let hasMoreListings = true;
        let allListings = [];
        let filteredListings = [];
        let isFilterActive = false;

        // Optimized fetch with caching and pagination
        async function fetchListings(page = 0, forceRefresh = false) {
            const cacheKey = `listings_page_${page}`;
            
            // Return cached data if available and not forcing refresh
            if (!forceRefresh && listingsCache.has(cacheKey)) {
                console.log('📦 Returning cached listings for page', page);
                return listingsCache.get(cacheKey);
            }

            if (isLoading) {
                console.log('⏳ Already loading listings, skipping...');
                return [];
            }

            isLoading = true;
            console.log('🔄 Fetching listings from Supabase - Page', page);
            
            try {
                const startRange = page * LISTINGS_PER_PAGE;
                const endRange = startRange + LISTINGS_PER_PAGE - 1;
                
                const { data, error } = await supabase
                    .from('listings')
                    .select('*')
                    .order('created_at', { ascending: false })
                    .range(startRange, endRange);
                    
                console.log('📊 Fetch result:', { 
                    page, 
                    startRange, 
                    endRange, 
                    count: data?.length || 0, 
                    error 
                });
                
                if (error) throw error;
                
                const listings = data || [];
                
                // Update hasMoreListings flag
                hasMoreListings = listings.length === LISTINGS_PER_PAGE;
                
                // Cache the results
                listingsCache.set(cacheKey, listings);
                
                // Set cache expiration (5 minutes)
                setTimeout(() => {
                    listingsCache.delete(cacheKey);
                    console.log('🗑️ Expired cache for page', page);
                }, 5 * 60 * 1000);
                
                return listings;
            } catch (error) {
                console.error('❌ Error fetching listings:', error);
                if (page === 0) {
                    alert('Failed to load listings: ' + error.message);
                }
                return [];
            } finally {
                isLoading = false;
            }
        }

        // Load more listings with infinite scroll
        async function loadMoreListings() {
            if (isLoading || !hasMoreListings || isFilterActive) {
                return;
            }

            showLoadingIndicator();
            const nextPage = currentPage + 1;
            const newListings = await fetchListings(nextPage);
            
            if (newListings.length > 0) {
                currentPage = nextPage;
                allListings = [...allListings, ...newListings];
                await appendListingsToDOM(newListings);
                console.log('📈 Loaded page', nextPage, '- Total listings:', allListings.length);
                
                // Update map with new listings
                await updateMap(allListings);
                
                // Set up infinite scroll for new content
                setupInfiniteScroll();
            }
            
            hideLoadingIndicator();
        }

        // Refresh listings cache
        async function refreshListings() {
            console.log('🔄 Refreshing listings cache...');
            listingsCache.clear();
            currentPage = 0;
            allListings = [];
            filteredListings = [];
            isFilterActive = false;
            hasMoreListings = true;
            
            // Clear existing listings from DOM
            const listingsContainer = document.getElementById('listings');
            if (listingsContainer) {
                listingsContainer.innerHTML = '<div class="loading-spinner">Loading listings...</div>';
            }
            
            await displayListings();
        }

        // Display listings with pagination
        async function displayListings() {
            console.log('🔄 Starting displayListings function');
            
            // Reset pagination state
            currentPage = 0;
            isFilterActive = false;
            
            let listings = await fetchListings(0);
            console.log('📋 Fetched listings:', listings);
            
            const container = document.getElementById('listingsContainer');
            container.innerHTML = '';

            if (listings.length === 0) {
                container.innerHTML = '<p class="text-gray-600 text-center mb-4">No listings available in database.</p>';
                console.log('📝 No listings found in database');
                return;
            }

            // Store initial listings
            allListings = [...listings];
            
            // Render the listings
            await renderListingsToDOM(listings);
            
            // Update map with initial listings
            await updateMap(listings);
            
            // Set up infinite scroll
            setupInfiniteScroll();
            
            // Set up pull-to-refresh
            setupPullToRefresh();
            
            // Initialize GPS services
            initializeGPS();
        }

        // Render listings to DOM with optimization
        async function renderListingsToDOM(listings) {
            const container = document.getElementById('listingsContainer');
            
            // Use document fragment for better performance
            const fragment = document.createDocumentFragment();

            listings.forEach(listing => {
                const listingCard = createListingCard(listing);
                fragment.appendChild(listingCard);
            });

            container.appendChild(fragment);
            
            // Set up event listeners for all buttons
            setupListingEventListeners();
        }

        // Append new listings to existing DOM (for infinite scroll)
        async function appendListingsToDOM(listings) {
            const container = document.getElementById('listingsContainer');
            const fragment = document.createDocumentFragment();

            listings.forEach(listing => {
                const listingCard = createListingCard(listing);
                fragment.appendChild(listingCard);
            });

            container.appendChild(fragment);
            
            // Set up event listeners for new buttons
            setupListingEventListeners();
        }

        // Optimized listing card creation with lazy loading
        function createListingCard(listing) {
            const listingCard = document.createElement('div');
            listingCard.className = 'listing-card bg-white rounded-lg shadow-md overflow-hidden';
            
            // Process media
            let media = listing.media || [];
            if (!Array.isArray(media)) {
                media = [];
            }

            // Fix MIME types
            media = media.map(item => {
                if (item.type === 'application/json' || !item.type || item.type === 'application/octet-stream') {
                    const extension = item.name.split('.').pop().toLowerCase();
                    let correctedType;
                    switch (extension) {
                        case 'jpg':
                        case 'jpeg':
                            correctedType = 'image/jpeg';
                            break;
                        case 'png':
                            correctedType = 'image/png';
                            break;
                        case 'mp4':
                            correctedType = 'video/mp4';
                            break;
                        default:
                            correctedType = item.type || 'application/octet-stream';
                    }
                    return { ...item, type: correctedType };
                }
                return item;
            });

            const isImage = (file) => {
                const byType = file.type.startsWith('image/');
                const byExtension = file.name.match(/\.(jpg|jpeg|png)$/i);
                return byType || byExtension;
            };

            const primaryImage = media.length > 0 && isImage(media[0])
                ? media[0].url
                : 'data:image/svg+xml;base64,PHN2ZyB3aWR0aD0iMzAwIiBoZWlnaHQ9IjIwMCIgeG1sbnM9Imh0dHA6Ly93d3cudzMub3JnLzIwMDAvc3ZnIj48cmVjdCB3aWR0aD0iMTAwJSIgaGVpZ2h0PSIxMDAlIiBmaWxsPSIjZjNmNGY2Ii8+PHRleHQgeD0iNTAlIiB5PSI1MCUiIGZvbnQtZmFtaWx5PSJBcmlhbCIgZm9udC1zaXplPSIxOCIgZmlsbD0iIzY2NzI4MCIgdGV4dC1hbmNob3I9Im1pZGRsZSIgZHk9Ii4zZW0iPk5vIEltYWdlPC90ZXh0Pjwvc3ZnPg==';

            const hasOwner = !!listing.user_email;
            
            // Create optimized HTML structure
            listingCard.innerHTML = `
                <div class="listing-image-container">
                    <img src="${primaryImage}" alt="${listing.title}" class="listing-image lazy-load" loading="lazy" onerror="this.src='data:image/svg+xml;base64,PHN2ZyB3aWR0aD0iMzAwIiBoZWlnaHQ9IjIwMCIgeG1sbnM9Imh0dHA6Ly93d3cudzMub3JnLzIwMDAvc3ZnIj48cmVjdCB3aWR0aD0iMTAwJSIgaGVpZ2h0PSIxMDAlIiBmaWxsPSIjZmY2Njc3Ii8+PHRleHQgeD0iNTAlIiB5PSI1MCUiIGZvbnQtZmFtaWx5PSJBcmlhbCIgZm9udC1zaXplPSIxOCIgZmlsbD0iI2ZmZmZmZiIgdGV4dC1hbmNob3I9Im1pZGRsZSIgZHk9Ii4zZW0iPkltYWdlIE5vdCBBdmFpbGFibGU8L3RleHQ+PC9zdmc+'">
                </div>
                <div class="p-4">
                    <h3 class="text-lg font-semibold text-gray-800 truncate">${listing.title}</h3>
                    <p class="text-xl font-bold text-blue-600">$${listing.price.toLocaleString()}/mo</p>
                    <p class="text-gray-600 text-sm">${listing.street}, ${listing.city}, ${listing.postalCode}</p>
                    <div class="flex items-center space-x-2 text-sm text-gray-600 mt-2">
                        <span>${listing.bedrooms} Bed</span>
                        <span>•</span>
                        <span>${listing.house_type}</span>
                        <span>•</span>
                        <span>${listing.utilities}</span>
                    </div>
                    <p class="text-gray-600 text-sm mt-2 line-clamp-2">${listing.description || 'No description provided'}</p>
                    <div class="flex space-x-2 mt-4">
                        <button class="view-details-btn bg-blue-600 text-white px-3 py-2 rounded-lg hover:bg-blue-700 transition font-semibold shadow-md hover:shadow-lg flex-1" data-listing-id="${listing.id}">View Details</button>
                        <button class="chat-btn bg-green-600 text-white px-3 py-2 rounded-lg transition ${hasOwner ? 'hover:bg-green-700' : ''} font-semibold shadow-md hover:shadow-lg flex-1" data-listing-id="${listing.id}" ${hasOwner ? '' : 'disabled title="No owner specified for this listing"'}>Chat</button>
                        <button class="visit-btn bg-purple-600 text-white px-3 py-2 rounded-lg hover:bg-purple-700 transition font-semibold shadow-md hover:shadow-lg" data-listing-id="${listing.id}" title="Start property visit">
                            <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 9a2 2 0 012-2h.93a2 2 0 001.664-.89l.812-1.22A2 2 0 0110.07 4h3.86a2 2 0 011.664.89l.812 1.22A2 2 0 0018.07 7H19a2 2 0 012 2v9a2 2 0 01-2 2H5a2 2 0 01-2-2V9z"></path>
                                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 13a3 3 0 11-6 0 3 3 0 016 0z"></path>
                            </svg>
                        </button>
                    </div>
                </div>
            `;
            
            return listingCard;
        }

        // Centralized event listener setup
        function setupListingEventListeners() {
            // Use event delegation for better performance
            const container = document.getElementById('listingsContainer');
            
            // Remove existing listeners to avoid duplicates
            container.replaceWith(container.cloneNode(true));
            const newContainer = document.getElementById('listingsContainer');
            
            newContainer.addEventListener('click', (e) => {
                const button = e.target.closest('.view-details-btn, .chat-btn');
                if (!button) return;
                
                const listingId = button.dataset.listingId;
                const listing = allListings.find(l => l.id == listingId);
                
                if (!listing) {
                    console.error('Listing not found:', listingId);
                    return;
                }
                
                if (button.classList.contains('view-details-btn')) {
                    showListingModal(listing);
                } else if (button.classList.contains('chat-btn') && !button.disabled) {
                    try {
                        console.log('🎯 Chat button clicked:', listingId);
                        startConversation(listing);
                    } catch (error) {
                        console.error('❌ Error starting conversation:', error);
                        alert('Error opening chat. Please refresh the page and try again.');
                    }
                } else if (button.classList.contains('visit-btn')) {
                    try {
                        console.log('📍 Visit button clicked:', listingId);
                        startPropertyVisit(listing);
                    } catch (error) {
                        console.error('❌ Error starting property visit:', error);
                        alert('Error starting property visit. Please try again.');
                    }
                }
            });
        }

        // Set up infinite scroll
        function setupInfiniteScroll() {
            const container = document.getElementById('listingsContainer');
            
            const observer = new IntersectionObserver((entries) => {
                entries.forEach(entry => {
                    if (entry.isIntersecting) {
                        const lastCard = container.lastElementChild;
                        if (lastCard && entry.target === lastCard) {
                            console.log('📜 Reached bottom, loading more listings...');
                            loadMoreListings();
                        }
                    }
                });
            }, {
                root: null,
                rootMargin: '100px',
                threshold: 0.1
            });

            // Observe the last listing card
            const lastCard = container.lastElementChild;
            if (lastCard) {
                observer.observe(lastCard);
            }

            // Store observer for cleanup
            window.listingsObserver = observer;
        }

        // Add loading indicator
        function showLoadingIndicator() {
            const container = document.getElementById('listingsContainer');
            const loadingDiv = document.createElement('div');
            loadingDiv.id = 'loading-indicator';
            loadingDiv.className = 'text-center py-8';
            loadingDiv.innerHTML = `
                <div class="inline-flex items-center px-4 py-2 bg-blue-100 rounded-lg">
                    <svg class="animate-spin -ml-1 mr-3 h-5 w-5 text-blue-600" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
                        <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
                        <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
                    </svg>
                    <span class="text-blue-600 font-medium">Loading more listings...</span>
                </div>
            `;
            container.appendChild(loadingDiv);
        }

        function hideLoadingIndicator() {
            const loadingIndicator = document.getElementById('loading-indicator');
            if (loadingIndicator) {
                loadingIndicator.remove();
            }
        }
            console.log('✅ Listings display complete:', listings.length, 'listings processed');
        }

        // Modal handling for listings
        const modal = document.getElementById('listingModal');
        const closeButton = document.querySelector('.close-button');

        function showListingModal(listing) {
            document.getElementById('modalTitle').textContent = listing.title;
            document.getElementById('modalPrice').textContent = `$${listing.price.toLocaleString()}/mo`;
            document.getElementById('modalLocation').textContent = `${listing.street}, ${listing.city}, ${listing.postalCode}`;
            document.getElementById('modalDetails').innerHTML = `
                <span>${listing.bedrooms} Bed</span> • <span>${listing.house_type}</span> • <span>${listing.utilities}</span>
            `;
            document.getElementById('modalDescription').textContent = listing.description || 'No description provided';
            
            const modalImage = document.getElementById('modalImage');
            modalImage.src = listing.media && listing.media.length > 0 && listing.media[0].type.startsWith('image/')
                ? listing.media[0].url
                : 'data:image/svg+xml;base64,PHN2ZyB3aWR0aD0iMzAwIiBoZWlnaHQ9IjIwMCIgeG1sbnM9Imh0dHA6Ly93d3cudzMub3JnLzIwMDAvc3ZnIj48cmVjdCB3aWR0aD0iMTAwJSIgaGVpZ2h0PSIxMDAlIiBmaWxsPSIjZjNmNGY2Ii8+PHRleHQgeD0iNTAlIiB5PSI1MCUiIGZvbnQtZmFtaWx5PSJBcmlhbCIgZm9udC1zaXplPSIxOCIgZmlsbD0iIzY2NzI4MCIgdGV4dC1hbmNob3I9Im1pZGRsZSIgZHk9Ii4zZW0iPk5vIEltYWdlPC90ZXh0Pjwvc3ZnPg==';
            
            const modalMedia = document.getElementById('modalMedia');
            modalMedia.innerHTML = listing.media && listing.media.length > 0
                ? listing.media.map(file => 
                    file.type.startsWith('image/')
                        ? `<img src="${file.url}" alt="${file.name}">`
                        : `<video src="${file.url}" controls></video>`
                ).join('')
                : '';

            document.getElementById('modalViewDetails').href = `/listing_details?id=${listing.id}`;
            
            // modal.style.display = 'block';
            modal.classList.add('active'); // Use class for animation
            console.log('Modal shown for listing:', listing.title);
        }

        closeButton.addEventListener('click', () => {
            // modal.style.display = 'none';
            modal.classList.remove('active'); // Use class for animation
            console.log('Modal closed');
        });

        window.addEventListener('click', (event) => {
            if (event.target === modal) {
                // modal.style.display = 'none';
                modal.classList.remove('active'); // Use class for animation
                console.log('Modal closed by clicking outside');
            }
        });

        // Handle form submission
        document.getElementById('listingForm').addEventListener('submit', async (e) => {
            e.preventDefault();

            const currentUser = JSON.parse(localStorage.getItem('currentUser'));
            if (!currentUser) {
                alert('Please log in to add a listing.');
                window.location.href = '/login';
                return;
            }

            try {
                const media = uploadedFiles.length > 0 ? await uploadMedia(uploadedFiles) : [];

                // Log original input values for debugging
                const originalValues = {
                    city: document.getElementById('city').value,
                    country: document.getElementById('country').value,
                    street: document.getElementById('street').value,
                    postalCode: document.getElementById('postalCode').value
                };
                console.log('📝 Original address input:', originalValues);

                const listing = {
                    title: autocorrectInput(sanitizeInput(document.getElementById('title').value)),
                    price: parseInt(document.getElementById('price').value),
                    city: cleanAddressInput(document.getElementById('city').value),
                    country: sanitizeInput(document.getElementById('country').value), // Added country
                    street: cleanAddressInput(document.getElementById('street').value),
                    postalCode: document.getElementById('postalCode').value.trim().toUpperCase().replace(/\s+/g, ' '),
                    house_type: document.getElementById('houseType').value,
                    bedrooms: parseInt(document.getElementById('bedrooms').value),
                    utilities: document.getElementById('utilities').value,
                    description: autocorrectInput(sanitizeInput(document.getElementById('description').value)),
                    media: media,
                    user_email: currentUser.email,
                    created_at: new Date().toISOString()
                };

                console.log('✅ Processed address values:', {
                    city: listing.city,
                    street: listing.street,
                    postalCode: listing.postalCode
                });
                console.log('📋 Submitting listing:', listing);

                if (!listing.title || !listing.price || !listing.city || !listing.street || !listing.postalCode || !listing.house_type || !listing.bedrooms) {
                    alert('Please fill in all required fields.');
                    return;
                }

                const { data, error } = await supabase
                    .from('listings')
                    .insert([listing])
                    .select();

                if (error) {
                    console.error('Error inserting listing:', error);
                    alert('Failed to add listing: ' + error.message);
                    return;
                }

                const newListing = {
                    ...listing,
                    id: data[0].id,
                    media: media
                };
                currentUser.listings = currentUser.listings || [];
                currentUser.listings.push(newListing);
                let users = JSON.parse(localStorage.getItem('users')) || [];
                users = users.map(u => u.email === currentUser.email ? currentUser : u);
                localStorage.setItem('users', JSON.stringify(users));
                localStorage.setItem('currentUser', JSON.stringify(currentUser));
                console.log('Updated localStorage with new listing:', newListing);

                e.target.reset();
                mediaPreview.innerHTML = '';
                uploadedFiles = [];

                alert('Listing added successfully!');
                console.log('🔄 Refreshing listings and map after new listing added');
                await displayListings();
            } catch (err) {
                console.error('Submission failed:', err);
                alert('Failed to add listing: ' + (err.message || err));
            }
        });

        // Chat Functionality
        let currentConversationId = null;
        let currentListing = null;

        // Global chat system status tracking
        let chatSystemStatus = {
            isInitialized: false,
            elementsReady: false,
            supabaseConnected: false,
            lastHealthCheck: null,
            setupAttempts: 0,
            errors: [],
            databaseErrors: {
                constraintViolations: 0,
                connectionFailures: 0,
                lastConstraintError: null
            }
        };

        // Comprehensive chat health check function
        function performChatHealthCheck() {
            console.log('🔍 Performing chat health check...');
            const issues = [];
            
            // Check DOM elements
            const requiredElements = [
                { id: 'chatModal', element: document.getElementById('chatModal') },
                { id: 'chatMessages', element: document.getElementById('chatMessages') },
                { id: 'chatInput', element: document.getElementById('chatInput') },
                { id: 'chatSendBtn', element: document.getElementById('chatSendBtn') },
                { selector: '.chat-close-button', element: document.querySelector('.chat-close-button') }
            ];

            requiredElements.forEach(item => {
                if (!item.element) {
                    issues.push(`Missing DOM element: ${item.id || item.selector}`);
                }
            });

            // Check Supabase connection
            if (!supabase) {
                issues.push('Supabase client not initialized');
            } else {
                chatSystemStatus.supabaseConnected = true;
            }

            // Check authentication
            const currentUser = JSON.parse(localStorage.getItem('currentUser'));
            if (!currentUser) {
                issues.push('No authenticated user (warning only)');
            }

            const isHealthy = issues.filter(issue => !issue.includes('warning only')).length === 0;
            
            const result = {
                healthy: isHealthy,
                issues: issues,
                elementsFound: requiredElements.filter(item => !!item.element).length,
                totalElements: requiredElements.length,
                timestamp: new Date()
            };

            chatSystemStatus.lastHealthCheck = result;
            console.log('🏥 Health check result:', result);
            
            return result;
        }

        // Display chat system error to user
        function displayChatSystemError() {
            console.error('🚨 Displaying chat system error to user');
            
            // Try to find a place to show the error
            const errorContainer = document.getElementById('chatMessages') || document.body;
            
            const errorDiv = document.createElement('div');
            errorDiv.id = 'chat-system-error';
            errorDiv.style.cssText = `
                background: #fee2e2;
                border: 1px solid #fca5a5;
                border-radius: 8px;
                padding: 12px;
                margin: 10px;
                color: #dc2626;
                font-family: Arial, sans-serif;
                font-size: 14px;
                position: relative;
                z-index: 1000;
            `;
            
            errorDiv.innerHTML = `
                <strong>⚠️ Chat System Error</strong><br>
                The chat system couldn't initialize properly. 
                <button onclick="retryChatSetup()" style="
                    background: #dc2626; 
                    color: white; 
                    border: none; 
                    padding: 4px 8px; 
                    border-radius: 4px; 
                    cursor: pointer; 
                    margin-left: 8px;
                ">Retry</button>
                <button onclick="this.parentElement.remove()" style="
                    background: #6b7280; 
                    color: white; 
                    border: none; 
                    padding: 4px 8px; 
                    border-radius: 4px; 
                    cursor: pointer; 
                    margin-left: 4px;
                ">Dismiss</button>
            `;
            
            // Remove any existing error messages
            const existingError = document.getElementById('chat-system-error');
            if (existingError) {
                existingError.remove();
            }
            
            errorContainer.appendChild(errorDiv);
        }

        // Global function to retry chat setup (called from error button)
        window.retryChatSetup = function() {
            console.log('🔄 Manual chat system retry triggered');
            chatSystemStatus.setupAttempts = 0; // Reset attempt counter
            chatSystemStatus.errors = []; // Clear errors
            
            const errorDiv = document.getElementById('chat-system-error');
            if (errorDiv) {
                errorDiv.remove();
            }
            
            setupChat();
        };

        function setupChat() {
            console.log('🔧 Setting up chat system...');
            chatSystemStatus.setupAttempts++;
            
            // Perform comprehensive health check
            const healthCheck = performChatHealthCheck();
            if (!healthCheck.healthy) {
                console.error('❌ Chat health check failed:', healthCheck);
                chatSystemStatus.errors.push({
                    timestamp: new Date(),
                    error: 'Health check failed',
                    details: healthCheck.issues
                });

                // Attempt auto-recovery
                if (chatSystemStatus.setupAttempts <= 3) {
                    console.log(`🔄 Attempting chat auto-recovery (attempt ${chatSystemStatus.setupAttempts}/3)...`);
                    setTimeout(() => {
                        setupChat();
                    }, 2000);
                    return;
                } else {
                    console.error('💥 Chat system setup failed after 3 attempts');
                    displayChatSystemError();
                    return;
                }
            }

            const chatModal = document.getElementById('chatModal');
            const chatCloseButton = document.querySelector('.chat-close-button');
            const chatMessagesContainer = document.getElementById('chatMessages');
            const chatInput = document.getElementById('chatInput');
            const chatSendBtn = document.getElementById('chatSendBtn');

            console.log('✅ All chat elements found:', {
                chatModal: !!chatModal,
                chatCloseButton: !!chatCloseButton,
                chatMessagesContainer: !!chatMessagesContainer,
                chatInput: !!chatInput,
                chatSendBtn: !!chatSendBtn
            });

            chatSystemStatus.elementsReady = true;

            chatCloseButton.addEventListener('click', () => {
                // chatModal.style.display = 'none';
                chatModal.classList.remove('active'); // Use class for animation
                console.log('Chat modal closed');
            });

            window.addEventListener('click', (event) => {
                if (event.target === chatModal) {
                    // chatModal.style.display = 'none';
                    chatModal.classList.remove('active'); // Use class for animation
                    console.log('Chat modal closed by clicking outside');
                }
            });

            // Function to send message will be defined later with file support

            // Send button click
            chatSendBtn.addEventListener('click', sendMessage);

            // Enter key support for instant messaging
            chatInput.addEventListener('keydown', (e) => {
                if (e.key === 'Enter' && !e.shiftKey) {
                    e.preventDefault();
                    sendMessage();
                }
            });

            // File upload functionality - only for landlords
            let selectedFiles = [];
            let isCurrentUserLandlord = false;

            // Initialize file functionality
            function initializeFileUpload() {
                const fileInput = document.getElementById('fileInput');
                const selectedFilesContainer = document.getElementById('selectedFiles');
                const fileUploadBtn = document.getElementById('fileUploadBtn');

                if (!fileInput || !selectedFilesContainer || !fileUploadBtn) {
                    console.warn('File upload elements not found');
                    return;
                }

                fileInput.addEventListener('change', (e) => {
                    const files = Array.from(e.target.files);
                    selectedFiles = files;
                    displaySelectedFiles(files);
                });

                function displaySelectedFiles(files) {
                    if (files.length === 0) {
                        selectedFilesContainer.classList.add('hidden');
                        return;
                    }

                    selectedFilesContainer.classList.remove('hidden');
                    selectedFilesContainer.innerHTML = files.map((file, index) => `
                        <div class="flex items-center justify-between bg-gray-100 p-2 rounded">
                            <div class="flex items-center space-x-2">
                                <span class="text-sm">📎</span>
                                <span class="text-sm text-gray-700">${file.name}</span>
                                <span class="text-xs text-gray-500">(${formatFileSize(file.size)})</span>
                            </div>
                            <button onclick="window.removeFileFromChat(${index})" class="text-red-500 hover:text-red-700 text-sm">×</button>
                        </div>
                    `).join('');
                }

                // Global function for removing files
                window.removeFileFromChat = function(index) {
                    selectedFiles.splice(index, 1);
                    displaySelectedFiles(selectedFiles);
                    
                    // Update file input
                    const dt = new DataTransfer();
                    selectedFiles.forEach(file => dt.items.add(file));
                    fileInput.files = dt.files;
                };
            }

            // Enhanced send message function to handle both text and files
            async function sendMessage() {
                const messageContent = chatInput.value.trim();
                
                // Check if we have content or files to send
                if (!messageContent && (!selectedFiles || selectedFiles.length === 0)) {
                    console.warn('No message content or files to send');
                    return;
                }

                if (!currentConversationId) {
                    console.warn('No conversation ID');
                    return;
                }

                const currentUser = JSON.parse(localStorage.getItem('currentUser'));
                const timestamp = new Date().toISOString();

                try {
                    // Send text message if there's content
                    if (messageContent) {
                        await sendTextMessage(messageContent, currentUser, timestamp);
                        chatInput.value = '';
                    }

                    // Send files if any are selected and user is landlord
                    if (selectedFiles && selectedFiles.length > 0 && isCurrentUserLandlord) {
                        for (const file of selectedFiles) {
                            await sendFileMessage(file, currentUser, timestamp);
                        }
                        
                        // Clear selected files
                        selectedFiles = [];
                        const fileInput = document.getElementById('fileInput');
                        if (fileInput) fileInput.value = '';
                        const selectedFilesContainer = document.getElementById('selectedFiles');
                        if (selectedFilesContainer) selectedFilesContainer.classList.add('hidden');
                    }

                } catch (error) {
                    console.error('❌ Error sending message/files:', error);
                    alert('Failed to send message: ' + error.message);
                }
            }

            async function sendTextMessage(messageContent, currentUser, timestamp) {
                // Instant UI update
                const messageElement = document.createElement('div');
                messageElement.className = 'message sent';
                messageElement.innerHTML = `
                    <p>${sanitizeInput(messageContent)}</p>
                    <div class="message-timestamp">${new Date(timestamp).toLocaleTimeString()}</div>
                `;
                chatMessagesContainer.appendChild(messageElement);
                chatMessagesContainer.scrollTop = chatMessagesContainer.scrollHeight;
                
                // Send to database
                const { error } = await supabase
                    .from('messages')
                    .insert({
                        conversation_id: currentConversationId,
                        sender_email: currentUser.email,
                        content: messageContent,
                        message_type: 'text',
                        created_at: timestamp
                    });

                if (error) {
                    messageElement.remove();
                    chatInput.value = messageContent; // Restore message
                    throw error;
                }
            }

            async function sendFileMessage(file, currentUser, timestamp) {
                // Validate file size (5MB limit)
                if (file.size > 5 * 1024 * 1024) {
                    throw new Error(`File ${file.name} is too large. Maximum size is 5MB.`);
                }

                // Show uploading status
                const messageElement = document.createElement('div');
                messageElement.className = 'message sent';
                messageElement.innerHTML = `
                    <div class="file-message bg-blue-50 p-3 rounded">
                        <div class="flex items-center space-x-2">
                            <span class="text-lg">📎</span>
                            <div>
                                <p class="font-medium text-blue-900">${file.name}</p>
                                <p class="text-sm text-blue-600">Uploading... (${formatFileSize(file.size)})</p>
                            </div>
                        </div>
                    </div>
                    <div class="message-timestamp">${new Date(timestamp).toLocaleTimeString()}</div>
                `;
                chatMessagesContainer.appendChild(messageElement);
                chatMessagesContainer.scrollTop = chatMessagesContainer.scrollHeight;

                try {
                    // Upload file to Supabase storage
                    const fileName = `chat-${currentConversationId}-${Date.now()}-${file.name}`;
                    const filePath = `chat-files/${fileName}`;

                    const { data: uploadData, error: uploadError } = await supabase.storage
                        .from('chat-documents')
                        .upload(filePath, file, {
                            contentType: file.type,
                            upsert: false
                        });

                    if (uploadError) {
                        throw new Error('Failed to upload file: ' + uploadError.message);
                    }

                    // Get public URL
                    const { data: urlData } = supabase.storage
                        .from('chat-documents')
                        .getPublicUrl(filePath);

                    // Save message to database
                    const { error: dbError } = await supabase
                        .from('messages')
                        .insert({
                            conversation_id: currentConversationId,
                            sender_email: currentUser.email,
                            content: `Shared file: ${file.name}`,
                            message_type: 'file',
                            file_url: urlData.publicUrl,
                            file_name: file.name,
                            file_size: file.size,
                            file_type: file.type,
                            created_at: timestamp
                        });

                    if (dbError) {
                        throw new Error('Failed to save message: ' + dbError.message);
                    }

                    // Update UI with download link
                    messageElement.innerHTML = `
                        <div class="file-message bg-blue-50 p-3 rounded">
                            <div class="flex items-center space-x-2">
                                <span class="text-lg">📎</span>
                                <div>
                                    <p class="font-medium text-blue-900">${file.name}</p>
                                    <p class="text-sm text-blue-600">${formatFileSize(file.size)}</p>
                                    <a href="${urlData.publicUrl}" target="_blank" class="text-blue-800 hover:text-blue-900 text-sm font-medium">📥 Download</a>
                                </div>
                            </div>
                        </div>
                        <div class="message-timestamp">${new Date(timestamp).toLocaleTimeString()}</div>
                    `;

                    console.log('✅ File sent successfully:', file.name);

                } catch (error) {
                    messageElement.remove();
                    throw error;
                }
            }

            // Initialize file upload functionality
            initializeFileUpload();

            // SIMPLIFIED Real-time subscription with better debugging
            const messageChannel = supabase
                .channel('messages_realtime_' + Math.random())
                .on('postgres_changes', { 
                    event: 'INSERT', 
                    schema: 'public', 
                    table: 'messages' 
                }, (payload) => {
                    console.log('🔔 REALTIME EVENT RECEIVED:', payload);
                    console.log('Current conversation ID:', currentConversationId);
                    console.log('Message conversation ID:', payload.new.conversation_id);
                    
                    if (currentConversationId && currentConversationId === payload.new.conversation_id) {
                        console.log('✅ Message is for current conversation!');
                        
                        // Reload messages to ensure we get the latest
                        loadMessages(currentConversationId);
                        
                        // Also try instant append for better UX
                        const currentUser = JSON.parse(localStorage.getItem('currentUser'));
                        const chatMessagesContainer = document.getElementById('chatMessages');
                        
                        if (chatMessagesContainer && payload.new.sender_email !== currentUser.email) {
                            console.log('🚀 Adding message instantly to UI');
                        }
                    } else {
                        console.log('❌ Message not for current conversation');
                    }
                })
                .subscribe((status) => {
                    console.log('💬 REALTIME SUBSCRIPTION STATUS:', status);
                    if (status === 'SUBSCRIBED') {
                        console.log('✅ Successfully subscribed to messages!');
                    } else if (status === 'CHANNEL_ERROR') {
                        console.error('❌ Channel error - real-time not working');
                    } else if (status === 'TIMED_OUT') {
                        console.error('⏰ Subscription timed out');
                    }
                });

            // Mark chat system as successfully initialized
            chatSystemStatus.isInitialized = true;
            chatSystemStatus.lastHealthCheck = performChatHealthCheck();
            
            console.log('✅ Chat system setup completed successfully!', chatSystemStatus);
            
            // Remove any existing error messages since setup was successful
            const errorDiv = document.getElementById('chat-system-error');
            if (errorDiv) {
                errorDiv.remove();
            }
        }

        // Chat System Diagnostics and Status Dashboard
        function createChatDiagnosticsPanel() {
            // Check if panel already exists
            if (document.getElementById('chat-diagnostics-panel')) {
                return;
            }

            const panel = document.createElement('div');
            panel.id = 'chat-diagnostics-panel';
            panel.style.cssText = `
                position: fixed;
                top: 10px;
                right: 10px;
                width: 300px;
                background: rgba(0, 0, 0, 0.9);
                color: white;
                padding: 15px;
                border-radius: 8px;
                font-family: monospace;
                font-size: 12px;
                z-index: 10000;
                max-height: 400px;
                overflow-y: auto;
                border: 2px solid #4ade80;
            `;

            updateDiagnosticsContent();
            document.body.appendChild(panel);

            // Auto-update every 5 seconds
            setInterval(updateDiagnosticsContent, 5000);
        }

        function updateDiagnosticsContent() {
            const panel = document.getElementById('chat-diagnostics-panel');
            if (!panel) return;

            const currentUser = JSON.parse(localStorage.getItem('currentUser'));
            const now = new Date().toLocaleTimeString();

            panel.innerHTML = `
                <div style="border-bottom: 1px solid #4ade80; margin-bottom: 10px; padding-bottom: 8px;">
                    <strong>🔧 Chat System Status</strong>
                    <button onclick="toggleDiagnosticsPanel()" style="float: right; background: #dc2626; color: white; border: none; padding: 2px 6px; border-radius: 3px; cursor: pointer;">×</button>
                    <br><small>Last Update: ${now}</small>
                </div>

                <div style="margin-bottom: 8px;">
                    <strong>System Health:</strong>
                    <span style="color: ${chatSystemStatus.isInitialized ? '#4ade80' : '#ef4444'}">
                        ${chatSystemStatus.isInitialized ? '✅ Healthy' : '❌ Error'}
                    </span>
                </div>

                <div style="margin-bottom: 8px;">
                    <strong>Components:</strong><br>
                    • DOM Elements: <span style="color: ${chatSystemStatus.elementsReady ? '#4ade80' : '#ef4444'}">${chatSystemStatus.elementsReady ? 'Ready' : 'Missing'}</span><br>
                    • Supabase: <span style="color: ${chatSystemStatus.supabaseConnected ? '#4ade80' : '#ef4444'}">${chatSystemStatus.supabaseConnected ? 'Connected' : 'Disconnected'}</span><br>
                    • User Auth: <span style="color: ${currentUser ? '#4ade80' : '#fbbf24'}">${currentUser ? 'Logged In' : 'Anonymous'}</span>
                </div>

                <div style="margin-bottom: 8px;">
                    <strong>Setup Info:</strong><br>
                    • Attempts: ${chatSystemStatus.setupAttempts}<br>
                    • Errors: ${chatSystemStatus.errors.length}
                </div>

                ${chatSystemStatus.lastHealthCheck ? `
                <div style="margin-bottom: 8px;">
                    <strong>Last Health Check:</strong><br>
                    • Status: <span style="color: ${chatSystemStatus.lastHealthCheck.healthy ? '#4ade80' : '#ef4444'}">${chatSystemStatus.lastHealthCheck.healthy ? 'Pass' : 'Fail'}</span><br>
                    • Elements: ${chatSystemStatus.lastHealthCheck.elementsFound}/${chatSystemStatus.lastHealthCheck.totalElements}<br>
                    • Issues: ${chatSystemStatus.lastHealthCheck.issues.length}
                </div>
                ` : ''}

                <div style="margin-bottom: 8px;">
                    <strong>Database Stats:</strong><br>
                    • Constraint Violations: <span style="color: ${chatSystemStatus.databaseErrors.constraintViolations > 0 ? '#fbbf24' : '#4ade80'}">${chatSystemStatus.databaseErrors.constraintViolations}</span><br>
                    • Connection Failures: <span style="color: ${chatSystemStatus.databaseErrors.connectionFailures > 0 ? '#ef4444' : '#4ade80'}">${chatSystemStatus.databaseErrors.connectionFailures}</span><br>
                    ${chatSystemStatus.databaseErrors.lastConstraintError ? `• Last Constraint Error: ${chatSystemStatus.databaseErrors.lastConstraintError.toLocaleTimeString()}<br>` : ''}
                </div>

                ${chatSystemStatus.errors.length > 0 ? `
                <div style="margin-bottom: 8px; color: #ef4444;">
                    <strong>Recent Errors:</strong><br>
                    ${chatSystemStatus.errors.slice(-3).map(err => 
                        `• ${err.error} (${err.timestamp.toLocaleTimeString()})`
                    ).join('<br>')}
                </div>
                ` : ''}

                <div style="margin-top: 10px; text-align: center;">
                    <button onclick="runChatDiagnostics()" style="background: #3b82f6; color: white; border: none; padding: 4px 8px; border-radius: 4px; cursor: pointer; margin: 2px;">Run Test</button>
                    <button onclick="retryChatSetup()" style="background: #059669; color: white; border: none; padding: 4px 8px; border-radius: 4px; cursor: pointer; margin: 2px;">Retry Setup</button>
                </div>
            `;
        }

        // Global functions for diagnostics panel
        window.toggleDiagnosticsPanel = function() {
            const panel = document.getElementById('chat-diagnostics-panel');
            if (panel) {
                panel.remove();
            }
        };

        window.runChatDiagnostics = function() {
            console.log('🔍 Running comprehensive chat diagnostics...');
            
            const healthCheck = performChatHealthCheck();
            console.log('Health Check Result:', healthCheck);
            
            // Test Supabase connection
            if (supabase) {
                // Test basic connection
                supabase.from('conversations').select('count').limit(1)
                    .then(result => {
                        console.log('✅ Supabase connection test successful:', result);
                    })
                    .catch(error => {
                        console.error('❌ Supabase connection test failed:', error);
                    });

                // Test conversation_reads table specifically (common error source)
                const currentUser = JSON.parse(localStorage.getItem('currentUser'));
                if (currentUser) {
                    console.log('🔍 Testing conversation_reads table access...');
                    supabase.from('conversation_reads')
                        .select('*')
                        .eq('user_email', currentUser.email)
                        .limit(1)
                        .then(result => {
                            console.log('✅ conversation_reads table test successful:', result);
                        })
                        .catch(error => {
                            console.error('❌ conversation_reads table test failed:', error);
                            if (error.message.includes('duplicate key')) {
                                console.log('🔧 Detected duplicate key constraint issue - this has been handled with fallback logic');
                            }
                        });
                }
            }
            
            updateDiagnosticsContent();
            alert('Diagnostics completed. Check console for details.');
        };

        // Connection Monitoring and User Notifications
        let connectionMonitor = {
            isOnline: navigator.onLine,
            lastPingTime: null,
            pingInterval: null,
            reconnectAttempts: 0,
            maxReconnectAttempts: 5
        };

        function initializeConnectionMonitoring() {
            console.log('🌐 Initializing connection monitoring...');
            
            // Listen for online/offline events
            window.addEventListener('online', handleOnline);
            window.addEventListener('offline', handleOffline);
            
            // Start periodic ping to check Supabase connection
            connectionMonitor.pingInterval = setInterval(pingSupabase, 30000); // Every 30 seconds
            
            // Initial ping
            pingSupabase();
        }

        function handleOnline() {
            console.log('🌐 Connection restored');
            connectionMonitor.isOnline = true;
            connectionMonitor.reconnectAttempts = 0;
            showConnectionNotification('Connection restored! Chat is back online.', 'success');
            
            // Retry chat setup if it failed
            if (!chatSystemStatus.isInitialized) {
                setTimeout(() => {
                    setupChat();
                }, 1000);
            }
        }

        function handleOffline() {
            console.log('🌐 Connection lost');
            connectionMonitor.isOnline = false;
            showConnectionNotification('Connection lost. Chat may not work properly.', 'warning');
        }

        async function pingSupabase() {
            if (!supabase) return;

            try {
                const { data, error } = await supabase
                    .from('conversations')
                    .select('count')
                    .limit(1);

                if (error) throw error;

                connectionMonitor.lastPingTime = new Date();
                console.log('📡 Supabase ping successful');
                
                // Update diagnostics if panel is open
                updateDiagnosticsContent();
                
            } catch (error) {
                console.error('📡 Supabase ping failed:', error);
                handleSupabaseConnectionError(error);
            }
        }

        function handleSupabaseConnectionError(error) {
            connectionMonitor.reconnectAttempts++;
            
            if (connectionMonitor.reconnectAttempts <= connectionMonitor.maxReconnectAttempts) {
                console.log(`🔄 Attempting to reconnect to Supabase (${connectionMonitor.reconnectAttempts}/${connectionMonitor.maxReconnectAttempts})`);
                
                showConnectionNotification(
                    `Database connection issue. Retrying... (${connectionMonitor.reconnectAttempts}/${connectionMonitor.maxReconnectAttempts})`,
                    'warning'
                );
                
                // Exponential backoff
                const delay = Math.min(1000 * Math.pow(2, connectionMonitor.reconnectAttempts), 30000);
                setTimeout(pingSupabase, delay);
            } else {
                console.error('💥 Max reconnection attempts reached');
                showConnectionNotification(
                    'Database connection failed. Chat may not work properly. Please refresh the page.',
                    'error'
                );
            }
        }

        function showConnectionNotification(message, type = 'info') {
            // Remove existing notification
            const existing = document.getElementById('connection-notification');
            if (existing) {
                existing.remove();
            }

            const colors = {
                success: { bg: '#d1fae5', border: '#10b981', text: '#065f46' },
                warning: { bg: '#fef3c7', border: '#f59e0b', text: '#92400e' },
                error: { bg: '#fee2e2', border: '#ef4444', text: '#991b1b' },
                info: { bg: '#dbeafe', border: '#3b82f6', text: '#1e40af' }
            };

            const color = colors[type] || colors.info;

            const notification = document.createElement('div');
            notification.id = 'connection-notification';
            notification.style.cssText = `
                position: fixed;
                top: 70px;
                right: 20px;
                background: ${color.bg};
                border: 1px solid ${color.border};
                color: ${color.text};
                padding: 12px 16px;
                border-radius: 8px;
                font-family: Arial, sans-serif;
                font-size: 14px;
                max-width: 350px;
                z-index: 9999;
                box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);
                animation: slideInRight 0.3s ease-out;
            `;

            notification.innerHTML = `
                <div style="display: flex; align-items: center; justify-content: space-between;">
                    <span>${message}</span>
                    <button onclick="this.parentElement.parentElement.remove()" style="
                        background: none; 
                        border: none; 
                        color: ${color.text}; 
                        font-size: 18px; 
                        cursor: pointer;
                        margin-left: 10px;
                    ">×</button>
                </div>
            `;

            document.body.appendChild(notification);

            // Auto-remove after 5 seconds for success/info, 10 seconds for warnings/errors
            const autoRemoveDelay = (type === 'success' || type === 'info') ? 5000 : 10000;
            setTimeout(() => {
                if (notification.parentElement) {
                    notification.remove();
                }
            }, autoRemoveDelay);
        }

        // Add CSS animation for notifications
        const style = document.createElement('style');
        style.textContent = `
            @keyframes slideInRight {
                from { transform: translateX(100%); opacity: 0; }
                to { transform: translateX(0); opacity: 1; }
            }
        `;
        document.head.appendChild(style);

        // Function to refresh just the map
        async function refreshMapOnly() {
            console.log('🔄 Manual map refresh requested');
            const listings = await fetchListings();
            await updateMap(listings);
        }

        // Function to start conversation from map popup
        function startConversationFromMap(listing) {
            // Parse the listing if it's a string (from onclick)
            if (typeof listing === 'string') {
                try {
                    listing = JSON.parse(listing);
                } catch (e) {
                    console.error('Failed to parse listing data:', e);
                    return;
                }
            }
            startConversation(listing);
        }

        async function startConversation(listing) {
            try {
                console.log('🚀 Starting conversation for listing:', listing?.title || 'Unknown listing');
            
            // Verify authentication
            const currentUser = JSON.parse(localStorage.getItem('currentUser'));
            console.log('👤 Authentication check:', { 
                hasUser: !!currentUser, 
                userEmail: currentUser?.email,
                hasSupabase: !!supabase 
            });
            
            if (!currentUser) {
                console.error('❌ No authenticated user found');
                alert('Please log in to start a chat.');
                window.location.href = '/login';
                return;
            }

            // Verify Supabase connection
            if (!supabase) {
                console.error('❌ Supabase client not initialized');
                alert('Connection error. Please refresh the page and try again.');
                return;
            }

            if (!listing.user_email) {
                console.error('❌ Listing missing user_email:', listing);
                alert('Cannot start chat: Listing owner not specified.');
                return;
            }
            
            console.log('📧 Chat participants:', {
                sender: currentUser.email,
                receiver: listing.user_email,
                listingId: listing.id
            });

            // Verify both users are registered in profiles database
            console.log('🔍 Checking user profiles...');
            let currentUserProfile, listingOwnerProfile, currentUserError, listingOwnerError;
            
            try {
                const currentUserResult = await supabase
                    .from('profiles')
                    .select('email')
                    .eq('email', currentUser.email)
                    .single();
                currentUserProfile = currentUserResult.data;
                currentUserError = currentUserResult.error;
                
                console.log('👤 Current user profile check:', { 
                    found: !!currentUserProfile, 
                    error: currentUserError?.message 
                });
                
                const ownerResult = await supabase
                    .from('profiles')
                    .select('email')
                    .eq('email', listing.user_email)
                    .single();
                listingOwnerProfile = ownerResult.data;
                listingOwnerError = ownerResult.error;
                
                console.log('🏠 Listing owner profile check:', { 
                    found: !!listingOwnerProfile, 
                    error: listingOwnerError?.message 
                });
                
            } catch (profileError) {
                console.error('💥 Error checking profiles:', profileError);
                alert('Database connection error. Please try again.');
                return;
            }

            // Auto-create profile for current user if missing
            if (currentUserError || !currentUserProfile) {
                console.log('Creating missing profile for current user...');
                const { error: createCurrentUserError } = await supabase
                    .from('profiles')
                    .insert([{
                        email: currentUser.email,
                        first_name: currentUser.firstName || 'User',
                        last_name: currentUser.lastName || '',
                        created_at: new Date().toISOString()
                    }]);
                
                if (createCurrentUserError) {
                    console.error('Error creating current user profile:', createCurrentUserError);
                    alert('Error setting up your profile. Please try refreshing the page.');
                    return;
                }
                console.log('✅ Created profile for current user');
            }

            // Auto-create profile for listing owner if missing
            if (listingOwnerError || !listingOwnerProfile) {
                console.log('Creating missing profile for listing owner...');
                // Try to get the listing owner's info from local storage or use defaults
                const { error: createOwnerError } = await supabase
                    .from('profiles')
                    .insert([{
                        email: listing.user_email,
                        first_name: 'User',
                        last_name: '',
                        created_at: new Date().toISOString()
                    }]);
                
                if (createOwnerError) {
                    console.error('Error creating listing owner profile:', createOwnerError);
                    alert('Error setting up chat. Please try again.');
                    return;
                }
                console.log('✅ Created profile for listing owner');
            }

            // Verify chat title element exists
            const chatTitle = document.getElementById('chatTitle');
            if (!chatTitle) {
                console.error('❌ Chat title element not found');
                alert('Chat interface error. Please refresh the page.');
                return;
            }
            
            currentListing = listing;
            chatTitle.textContent = `Chat about ${listing.title}`;
            console.log('📝 Chat title set:', listing.title);

            // Check for existing conversations
            console.log('🔍 Checking for existing conversations...');
            let conversations, error;
            
            try {
                const result = await supabase
                    .from('conversations')
                    .select('*')
                    .eq('listing_id', listing.id)
                    .eq('sender_email', currentUser.email)
                    .eq('receiver_email', listing.user_email);
                    
                conversations = result.data;
                error = result.error;
                
                console.log('💬 Conversation query result:', { 
                    found: conversations?.length || 0, 
                    error: error?.message 
                });
                
            } catch (queryError) {
                console.error('💥 Error querying conversations:', queryError);
                alert('Database error while loading conversation. Please try again.');
                return;
            }

            if (error) {
                console.error('❌ Database error checking conversation:', error);
                alert('Failed to load conversation: ' + error.message);
                return;
            }

            let conversation;
            if (conversations && conversations.length > 0) {
                conversation = conversations[0];
                console.log('Existing conversation found:', conversation.id);
            } else {
                const { data, error: insertError } = await supabase
                    .from('conversations')
                    .insert({
                        listing_id: listing.id,
                        sender_email: currentUser.email,
                        receiver_email: listing.user_email,
                        created_at: new Date().toISOString()
                    })
                    .select()
                    .single();

                if (insertError) {
                    console.error('Error creating conversation:', insertError);
                    alert('Failed to start conversation: ' + insertError.message);
                    return;
                }
                conversation = data;
                console.log('New conversation created:', conversation.id);
            }

            currentConversationId = conversation.id;
            
            // Verify chat modal exists before proceeding
            const chatModal = document.getElementById('chatModal');
            if (!chatModal) {
                console.error('❌ Chat modal element not found');
                alert('Chat interface error. Please refresh the page.');
                return;
            }
            
            // Show loading state
            console.log('⏳ Loading messages...');
            const chatMessages = document.getElementById('chatMessages');
            if (chatMessages) {
                chatMessages.innerHTML = '<div style="text-align: center; padding: 20px; color: #6b7280;">Loading messages...</div>';
            }
            
            try {
                await loadMessages(conversation.id);
                
                // Show file upload button only for listing owners
                const fileUploadBtn = document.getElementById('fileUploadBtn');
                isCurrentUserLandlord = currentUser.email === listing.user_email;
                if (fileUploadBtn) {
                    if (isCurrentUserLandlord) {
                        fileUploadBtn.classList.remove('hidden');
                        console.log('📎 File upload enabled for listing owner (landlord)');
                    } else {
                        fileUploadBtn.classList.add('hidden');
                        console.log('📎 File upload disabled for non-owner (tenant)');
                    }
                }
                console.log('🏠 User role:', isCurrentUserLandlord ? 'Landlord' : 'Tenant');
                
                chatModal.classList.add('active');
                console.log('✅ Chat modal opened for conversation:', conversation.id);
            } catch (loadError) {
                console.error('❌ Error loading messages:', loadError);
                alert('Failed to load chat messages. Please try again.');
                if (chatMessages) {
                    chatMessages.innerHTML = '<div style="text-align: center; padding: 20px; color: #ef4444;">Failed to load messages</div>';
                }
            }
            } catch (error) {
                console.error('❌ Unexpected error in startConversation:', error);
                alert('An unexpected error occurred while opening the chat. Please refresh the page and try again.');
            }
        }

        // Debug function to help troubleshoot chat issues
        window.debugChatSystem = function() {
            console.log('🔍 Chat System Debug Information:');
            console.log('- Chat Modal Element:', !!document.getElementById('chatModal'));
            console.log('- Chat Close Button:', !!document.querySelector('.chat-close-button'));  
            console.log('- Chat Input:', !!document.getElementById('chatInput'));
            console.log('- Chat Send Button:', !!document.getElementById('chatSendBtn'));
            console.log('- Supabase Client:', !!supabase);
            console.log('- Current User:', !!localStorage.getItem('currentUser'));
            console.log('- Chat System Status:', chatSystemStatus);
            console.log('- Active Chat Buttons:', document.querySelectorAll('.chat-btn:not([disabled])').length);
            console.log('- Disabled Chat Buttons:', document.querySelectorAll('.chat-btn[disabled]').length);
        };

        async function loadMessages(conversationId) {
            console.log('🔄 Loading messages for conversation:', conversationId);
            console.log('📊 Supabase client status:', !!supabase);
            console.log('👤 Current user status:', !!localStorage.getItem('currentUser'));
            
            try {
                const { data: messages, error } = await supabase
                    .from('messages')
                    .select('*')
                    .eq('conversation_id', conversationId)
                    .order('created_at', { ascending: true });

                console.log('📨 Messages query result:', { messages, error, count: messages?.length });

                if (error) {
                    console.error('❌ Error loading messages:', error);
                    alert('Failed to load messages: ' + error.message);
                    return;
                }

                const chatMessagesContainer = document.getElementById('chatMessages');
                console.log('📋 Chat container element:', !!chatMessagesContainer);
                
                if (!chatMessagesContainer) {
                    console.error('❌ Chat messages container not found!');
                    return;
                }
                
                chatMessagesContainer.innerHTML = '';
                const currentUser = JSON.parse(localStorage.getItem('currentUser'));
                console.log('👤 Current user for message display:', currentUser?.email);

                messages.forEach((message, index) => {
                    console.log(`💬 Processing message ${index + 1}:`, {
                        sender: message.sender_email,
                        content: message.content?.substring(0, 50) + '...',
                        type: message.message_type,
                        timestamp: message.created_at
                    });
                    
                    const messageElement = document.createElement('div');
                    messageElement.className = `message ${message.sender_email === currentUser.email ? 'sent' : 'received'}`;
                    
                    // Handle different message types
                    let messageContent;
                    if (message.message_type === 'file' && message.file_url) {
                        const isOwner = message.sender_email === currentUser.email;
                        messageContent = `
                            <div class="file-message ${isOwner ? 'bg-blue-50' : 'bg-gray-50'} p-3 rounded">
                                <div class="flex items-center space-x-2">
                                    <span class="text-lg">📎</span>
                                    <div>
                                        <p class="font-medium ${isOwner ? 'text-blue-900' : 'text-gray-900'}">${sanitizeInput(message.file_name || 'File')}</p>
                                        <p class="text-sm ${isOwner ? 'text-blue-600' : 'text-gray-600'}">${message.file_size ? formatFileSize(message.file_size) : ''}</p>
                                        <a href="${message.file_url}" target="_blank" class="${isOwner ? 'text-blue-800 hover:text-blue-900' : 'text-gray-800 hover:text-gray-900'} text-sm font-medium">📥 Download</a>
                                    </div>
                                </div>
                            </div>
                        `;
                    } else {
                        messageContent = `<p>${sanitizeInput(message.content)}</p>`;
                    }
                    
                    messageElement.innerHTML = `
                        ${messageContent}
                        <div class="message-timestamp">${new Date(message.created_at).toLocaleTimeString()}</div>
                    `;
                    chatMessagesContainer.appendChild(messageElement);
                });

                chatMessagesContainer.scrollTop = chatMessagesContainer.scrollHeight;
                console.log('✅ Messages loaded successfully:', messages.length, 'messages displayed');
                
            } catch (error) {
                console.error('💥 Exception in loadMessages:', error);
                alert('Failed to load messages due to an error: ' + error.message);
            }
        }

        // Global helper function for file size formatting
        function formatFileSize(bytes) {
            if (bytes === 0) return '0 Bytes';
            const k = 1024;
            const sizes = ['Bytes', 'KB', 'MB', 'GB'];
            const i = Math.floor(Math.log(bytes) / Math.log(k));
            return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + ' ' + sizes[i];
        }

        // Global variables for messaging
        let globalUserConversations = [];
        let globalUnreadCount = 0;
        let locallyReadConversations = new Set(); // Track conversations marked as read locally

        // Setup Messaging Panel
        function setupMessagingPanel() {
            const messageToggleBtn = document.getElementById('messageToggleBtn');
            const messagePanel = document.getElementById('messagePanel');
            const profileNotificationBadge = document.getElementById('profileNotificationBadge');
            const messageNotificationBadge = document.getElementById('messageNotificationBadge');
            
            let isMessagingPanelOpen = false;

            // Toggle message panel
            messageToggleBtn.addEventListener('click', async () => {
                isMessagingPanelOpen = !isMessagingPanelOpen;
                if (isMessagingPanelOpen) {
                    messagePanel.classList.remove('hidden');
                    await loadUserConversations();
                } else {
                    messagePanel.classList.add('hidden');
                }
            });

            // Force hide notifications button
            document.getElementById('forceHideNotifications').addEventListener('click', () => {
                console.log('🔥 FORCE HIDING ALL NOTIFICATIONS');
                
                // Mark ALL conversations as locally read
                globalUserConversations.forEach(conv => {
                    locallyReadConversations.add(conv.id);
                    conv.unread_count = 0;
                });
                
                // Force update
                window.updateUnreadCount();
                
                // Also update the display
                displayConversations();
            });

            // Close panel when clicking outside
            document.addEventListener('click', (event) => {
                if (!event.target.closest('#messagingPanel')) {
                    messagePanel.classList.add('hidden');
                    isMessagingPanelOpen = false;
                }
            });

            // Load user's conversations
            async function loadUserConversations() {
                const currentUser = JSON.parse(localStorage.getItem('currentUser'));
                if (!currentUser) return;

                // First verify current user is registered in profiles
                const { data: currentProfile, error: profileError } = await supabase
                    .from('profiles')
                    .select('email')
                    .eq('email', currentUser.email)
                    .single();

                if (profileError || !currentProfile) {
                    console.error('Current user not found in profiles database:', profileError);
                    const conversationTabs = document.getElementById('conversationTabs');
                    conversationTabs.innerHTML = '<div class="p-4 text-red-500 text-center">Please register to access messaging</div>';
                    return;
                }

                const { data: conversations, error } = await supabase
                    .from('conversations')
                    .select(`
                        *,
                        listings (title, id)
                    `)
                    .or(`sender_email.eq.${currentUser.email},receiver_email.eq.${currentUser.email}`)
                    .order('created_at', { ascending: false });

                if (error) {
                    console.error('Error loading conversations:', error);
                    return;
                }

                // Get unread counts for each conversation
                const conversationsWithUnread = [];
                for (const conv of conversations || []) {
                    // Get last read time for this user
                    const { data: readData } = await supabase
                        .from('conversation_reads')
                        .select('last_read_at')
                        .eq('conversation_id', conv.id)
                        .eq('user_email', currentUser.email)
                        .maybeSingle();

                    const lastReadAt = readData?.last_read_at || '1970-01-01T00:00:00Z';

                    // Count unread messages
                    const { count: unreadCount } = await supabase
                        .from('messages')
                        .select('*', { count: 'exact', head: true })
                        .eq('conversation_id', conv.id)
                        .neq('sender_email', currentUser.email)
                        .gt('created_at', lastReadAt);

                    conv.unread_count = unreadCount || 0;
                    conversationsWithUnread.push(conv);
                }

                // Filter conversations to only include those between registered users
                const filteredConversations = [];
                for (const conv of conversationsWithUnread) {
                    // Check if both sender and receiver are in profiles database
                    const { data: senderProfile } = await supabase
                        .from('profiles')
                        .select('email')
                        .eq('email', conv.sender_email)
                        .single();
                    
                    const { data: receiverProfile } = await supabase
                        .from('profiles')
                        .select('email')
                        .eq('email', conv.receiver_email)
                        .single();

                    if (senderProfile && receiverProfile) {
                        // Apply local read status - if conversation was marked as read locally, keep it as 0
                        if (locallyReadConversations.has(conv.id)) {
                            console.log('🔒 Preserving local read status for conversation:', conv.id);
                            conv.unread_count = 0;
                        }
                        filteredConversations.push(conv);
                    }
                }

                globalUserConversations = filteredConversations;
                window.globalUserConversations = globalUserConversations; // Keep global reference updated
                displayConversations();
                await window.updateUnreadCount();
            }

            // Display conversations in tabs
            function displayConversations() {
                const conversationTabs = document.getElementById('conversationTabs');
                const currentUser = JSON.parse(localStorage.getItem('currentUser'));
                
                if (globalUserConversations.length === 0) {
                    conversationTabs.innerHTML = '<div id="noConversations" class="p-4 text-gray-500 text-center">No conversations yet</div>';
                    return;
                }

                conversationTabs.innerHTML = globalUserConversations.map(conv => {
                    const otherUserEmail = conv.sender_email === currentUser.email ? conv.receiver_email : conv.sender_email;
                    const listingTitle = conv.listings ? conv.listings.title : 'Unknown Listing';
                    
                    // Extract username from email (part before @)
                    const otherUserName = otherUserEmail.split('@')[0];
                    
                    // Check if conversation has unread messages
                    const hasUnread = conv.unread_count > 0;
                    const unreadBadge = hasUnread ? `<span class="bg-red-500 text-white rounded-full w-5 h-5 text-xs flex items-center justify-center ml-2">${conv.unread_count}</span>` : '';
                    
                    return `
                        <div class="border-b hover:bg-gray-50 cursor-pointer ${hasUnread ? 'bg-blue-50' : ''}" onclick="openConversationInModal('${conv.id}', '${listingTitle}', '${conv.listing_id}', '${otherUserEmail}')">
                            <div class="p-3">
                                <div class="flex justify-between items-start">
                                    <div class="flex-1">
                                        <div class="font-medium text-sm text-gray-900 flex items-center">
                                            ${otherUserName}
                                            ${unreadBadge}
                                        </div>
                                        <div class="text-xs text-gray-600">${listingTitle}</div>
                                        <div class="text-xs text-gray-400 mt-1">
                                            ${new Date(conv.created_at).toLocaleDateString()}
                                        </div>
                                    </div>
                                </div>
                            </div>
                        </div>
                    `;
                }).join('');
            }

            // Update unread message count (now accessible globally)
            window.updateUnreadCount = async function() {
                const messageNotificationBadge = document.getElementById('messageNotificationBadge');
                const profileNotificationBadge = document.getElementById('profileNotificationBadge');
                
                const currentUser = JSON.parse(localStorage.getItem('currentUser'));
                if (!currentUser) return;

                // Calculate total unread messages across all conversations
                let totalUnread = 0;
                const detailedLog = [];
                
                for (const conv of globalUserConversations) {
                    const isLocallyRead = locallyReadConversations.has(conv.id);
                    const unreadCount = isLocallyRead ? 0 : (conv.unread_count || 0);
                    
                    detailedLog.push({
                        id: conv.id,
                        originalCount: conv.unread_count,
                        isLocallyRead: isLocallyRead,
                        finalCount: unreadCount
                    });
                    
                    if (unreadCount > 0) {
                        totalUnread += unreadCount;
                    }
                }
                
                console.log('🔔 DETAILED UNREAD CALCULATION:', {
                    conversations: globalUserConversations.length,
                    locallyReadSet: Array.from(locallyReadConversations),
                    detailedLog: detailedLog,
                    totalUnread: totalUnread
                });
                
                // FORCE hide notifications if totalUnread is 0
                if (totalUnread === 0) {
                    messageNotificationBadge.classList.add('hidden');
                    profileNotificationBadge.classList.add('hidden');
                    console.log('🔥 FORCING notifications to hide - totalUnread is 0');
                } else {
                    messageNotificationBadge.textContent = totalUnread;
                    messageNotificationBadge.classList.remove('hidden');
                    profileNotificationBadge.textContent = totalUnread;
                    profileNotificationBadge.classList.remove('hidden');
                    console.log('✅ Showing notifications:', totalUnread);
                }
                
                globalUnreadCount = totalUnread;
            };

            // SIMPLIFIED Messaging panel real-time updates
            const panelChannel = supabase
                .channel('panel_realtime_' + Math.random())
                .on('postgres_changes', { 
                    event: 'INSERT', 
                    schema: 'public', 
                    table: 'messages' 
                }, (payload) => {
                    console.log('🔔 PANEL: New message event:', payload);
                    const currentUser = JSON.parse(localStorage.getItem('currentUser'));
                    
                    // If message is for current user (not sent by them), instantly update UI
                    if (payload.new.sender_email !== currentUser.email && window.globalUserConversations) {
                        const convIndex = window.globalUserConversations.findIndex(c => c.id === payload.new.conversation_id);
                        if (convIndex !== -1) {
                            // Only increment if this conversation hasn't been locally marked as read
                            if (!locallyReadConversations.has(payload.new.conversation_id)) {
                                console.log('⚡ INSTANTLY updating unread count for new message');
                                window.globalUserConversations[convIndex].unread_count = (window.globalUserConversations[convIndex].unread_count || 0) + 1;
                                if (window.updateUnreadCount) {
                                    window.updateUnreadCount();
                                }
                            } else {
                                console.log('🔒 Skipping increment - conversation locally marked as read');
                            }
                        }
                    }
                    
                    // Reduce frequency of database refreshes to prevent overwrites
                    // Only refresh every 5 seconds maximum
                    if (!window.lastRefreshTime || Date.now() - window.lastRefreshTime > 5000) {
                        window.lastRefreshTime = Date.now();
                        setTimeout(() => loadUserConversations(), 3000);
                    }
                })
                .on('postgres_changes', { 
                    event: 'INSERT', 
                    schema: 'public', 
                    table: 'conversations' 
                }, (payload) => {
                    console.log('💬 PANEL: New conversation event:', payload);
                    const currentUser = JSON.parse(localStorage.getItem('currentUser'));
                    
                    if (payload.new.sender_email === currentUser.email || payload.new.receiver_email === currentUser.email) {
                        console.log('🔄 Refreshing conversations panel for new conversation');
                        loadUserConversations();
                    }
                })
                .on('postgres_changes', { 
                    event: '*', 
                    schema: 'public', 
                    table: 'conversation_reads' 
                }, (payload) => {
                    console.log('👀 READ STATUS UPDATE:', payload);
                    const currentUser = JSON.parse(localStorage.getItem('currentUser'));
                    
                    // Only refresh if the read status is for current user and not locally initiated
                    if (payload.new?.user_email === currentUser.email) {
                        console.log('🔄 Refreshing conversations due to read status change');
                        setTimeout(() => loadUserConversations(), 1000);
                    }
                })
                .subscribe((status) => {
                    console.log('📱 PANEL SUBSCRIPTION STATUS:', status);
                });

            // Initialize
            loadUserConversations();
            
            // Expose function globally for external access
            window.refreshConversations = loadUserConversations;
            
            // Update global reference when conversations are loaded
            window.globalUserConversations = globalUserConversations;

            // FALLBACK: Polling for updates if real-time fails
            let pollingInterval;
            function startPolling() {
                console.log('🔄 Starting polling fallback (every 3 seconds)');
                pollingInterval = setInterval(() => {
                    if (currentConversationId) {
                        loadMessages(currentConversationId);
                    }
                    loadUserConversations();
                }, 3000);
            }

            // Start polling if real-time doesn't work after 10 seconds
            // Note: messageChannel is not in scope here, so we'll just start polling as fallback
            setTimeout(() => {
                console.log('⚠️ Starting fallback polling for messages');
                startPolling();
            }, 10000);
        }

        // Global function to open conversation in modal
        window.openConversationInModal = async function(conversationId, listingTitle, listingId, otherUserEmail) {
            // Close messaging panel
            document.getElementById('messagePanel').classList.add('hidden');
            
            // INSTANTLY clear notifications - don't wait for database
            console.log('⚡ INSTANTLY clearing notifications for conversation:', conversationId);
            
            // Mark conversation as read locally and persistently
            locallyReadConversations.add(conversationId);
            console.log('🔒 Added to locally read set:', conversationId);
            
            // Find and update the conversation in local array
            if (window.globalUserConversations) {
                const convIndex = window.globalUserConversations.findIndex(c => c.id === conversationId);
                if (convIndex !== -1) {
                    window.globalUserConversations[convIndex].unread_count = 0;
                    console.log('✅ Locally marked conversation as read');
                }
            }
            
            // Immediately update notification badges
            if (window.updateUnreadCount) {
                window.updateUnreadCount();
            }
            
            // Set up chat modal with existing conversation
            currentConversationId = conversationId;
            const otherUserName = otherUserEmail ? otherUserEmail.split('@')[0] : 'User';
            document.getElementById('chatTitle').textContent = `Chat with ${otherUserName} about ${listingTitle}`;
            
            await loadMessages(conversationId);
            document.getElementById('chatModal').classList.add('active');
            
            // Update database in background (don't wait)
            const currentUser = JSON.parse(localStorage.getItem('currentUser'));
            supabase
                .from('conversation_reads')
                .upsert({
                    conversation_id: conversationId,
                    user_email: currentUser.email,
                    last_read_at: new Date().toISOString()
                }, {
                    onConflict: 'conversation_id,user_email'
                })
                .then(({ error }) => {
                    if (error) {
                        console.error('❌ Background database update failed:', error);
                        
                        // Track constraint violations
                        if (error.message && error.message.includes('duplicate key')) {
                            chatSystemStatus.databaseErrors.constraintViolations++;
                            chatSystemStatus.databaseErrors.lastConstraintError = new Date();
                            console.log('📊 Constraint violation tracked. Total violations:', chatSystemStatus.databaseErrors.constraintViolations);
                        }
                        
                        console.log('🔄 Attempting fallback update method...');
                        
                        // Fallback: try update first, then insert if not exists
                        return supabase
                            .from('conversation_reads')
                            .update({ last_read_at: new Date().toISOString() })
                            .eq('conversation_id', conversationId)
                            .eq('user_email', currentUser.email)
                            .then(({ data: updateData, error: updateError }) => {
                                if (updateError || !updateData || updateData.length === 0) {
                                    console.log('🔄 Update failed or no rows, attempting insert...');
                                    // If update failed, try insert
                                    return supabase
                                        .from('conversation_reads')
                                        .insert({
                                            conversation_id: conversationId,
                                            user_email: currentUser.email,
                                            last_read_at: new Date().toISOString()
                                        })
                                        .then(({ error: insertError }) => {
                                            if (insertError && !insertError.message.includes('duplicate key')) {
                                                console.error('❌ Fallback insert failed:', insertError);
                                                locallyReadConversations.delete(conversationId);
                                            } else {
                                                console.log('✅ Fallback method successful');
                                            }
                                        });
                                } else {
                                    console.log('✅ Fallback update successful');
                                }
                            });
                    }
                })
                .catch((catchError) => {
                    console.error('💥 Unexpected error in conversation_reads update:', catchError);
                    locallyReadConversations.delete(conversationId);
                });
        };

        // Search and Filter Functions
        let originalListings = [];
        let filteredListings = [];

        // Quick filter presets
        const quickFilters = {
            'under-1000': { maxPrice: 1000, label: 'Under $1,000' },
            'under-1500': { maxPrice: 1500, label: 'Under $1,500' },
            '1-bed': { bedrooms: 1, label: '1 Bedroom' },
            '2-bed': { bedrooms: 2, label: '2+ Bedrooms' },
            'apartment': { roomType: 'Apartment', label: 'Apartments' },
            'house': { roomType: 'House', label: 'Houses' },
            'toronto': { location: 'toronto', label: 'Toronto' },
            'vancouver': { location: 'vancouver', label: 'Vancouver' }
        };

        // Apply quick filter
        function applyQuickFilter(filterId) {
            const filter = quickFilters[filterId];
            if (!filter) return;
            
            console.log('🚀 Applying quick filter:', filter.label);
            
            // Update form fields
            if (filter.maxPrice) {
                document.getElementById('searchMaxPrice').value = filter.maxPrice;
            }
            if (filter.bedrooms) {
                document.getElementById('searchBedrooms').value = filter.bedrooms;
            }
            if (filter.roomType) {
                document.getElementById('searchRoomType').value = filter.roomType;
            }
            if (filter.location) {
                document.getElementById('searchLocation').value = filter.location;
            }
            
            // Apply the search
            applySearchFilters();
        }

        // Enhanced search with caching and pagination
        async function applySearchFilters() {
            console.log('🔍 Applying search filters...');
            
            const location = document.getElementById('searchLocation').value.toLowerCase().trim();
            const maxPrice = parseInt(document.getElementById('searchMaxPrice').value);
            const roomType = document.getElementById('searchRoomType').value;
            const bedrooms = document.getElementById('searchBedrooms').value;
            
            console.log('Search criteria:', { location, maxPrice, roomType, bedrooms });
            
            // Clear existing observer
            if (window.listingsObserver) {
                window.listingsObserver.disconnect();
            }
            
            // Set filter active state
            const hasFilters = location || maxPrice || roomType || bedrooms;
            isFilterActive = hasFilters;
            
            // If no filters, show all listings
            if (!hasFilters) {
                console.log('🔄 No filters active, showing all listings');
                await displayListings();
                return;
            }
            
            // Show loading
            const container = document.getElementById('listingsContainer');
            container.innerHTML = '<div class="loading-spinner text-center py-8">Searching listings...</div>';
            
            // Build Supabase query with filters
            let query = supabase
                .from('listings')
                .select('*')
                .order('created_at', { ascending: false });
            
            // Apply location filter (city, street, or postal code)
            if (location) {
                query = query.or(`city.ilike.%${location}%,street.ilike.%${location}%,postal_code.ilike.%${location}%`);
            }
            
            // Apply price filter
            if (maxPrice && !isNaN(maxPrice)) {
                query = query.lte('price', maxPrice);
            }
            
            // Apply room type filter
            if (roomType) {
                query = query.eq('house_type', roomType);
            }
            
            // Apply bedroom filter
            if (bedrooms) {
                query = query.eq('bedrooms', parseInt(bedrooms));
            }
            
            try {
                const { data: filteredListings, error } = await query;
                
                if (error) {
                    console.error('Search error:', error);
                    alert('Search failed: ' + error.message);
                    return;
                }
                
                console.log(`✅ Found ${filteredListings.length} listings matching criteria`);
                
                // Store filtered results
                filteredListings = filteredListings || [];
                allListings = [...filteredListings];
                
                // Display filtered results
                container.innerHTML = '';

                if (filteredListings.length === 0) {
                    container.innerHTML = `
                        <div class="text-center py-8">
                            <p class="text-gray-600 mb-4">No listings match your search criteria.</p>
                            <button class="bg-blue-600 text-white px-4 py-2 rounded hover:bg-blue-700" onclick="clearFilters()">
                                Clear Filters
                            </button>
                        </div>
                    `;
                    // Clear map
                    if (markerClusterGroup) {
                        markerClusterGroup.clearLayers();
                    }
                    return;
                }

                // Render filtered listings
                await renderListingsToDOM(filteredListings);
                
                // Update map with filtered results
                await updateMap(filteredListings);
                
            } catch (error) {
                console.error('❌ Error applying filters:', error);
                container.innerHTML = `
                    <div class="text-center py-8">
                        <p class="text-red-600 mb-4">Error applying filters: ${error.message}</p>
                        <button class="bg-blue-600 text-white px-4 py-2 rounded hover:bg-blue-700" onclick="clearFilters()">
                            Clear Filters
                        </button>
                    </div>
                `;
            }
        }

        // Clear all filters
        function clearFilters() {
            console.log('🧹 Clearing all filters');
            
            // Clear form fields
            document.getElementById('searchLocation').value = '';
            document.getElementById('searchMaxPrice').value = '';
            document.getElementById('searchRoomType').value = '';
            document.getElementById('searchBedrooms').value = '';
            
            // Reset state
            isFilterActive = false;
            filteredListings = [];
            
            // Show all listings
            displayListings();
        }

        // Add debounced search for better performance
        let searchTimeout;
        function debounceSearch() {
            clearTimeout(searchTimeout);
            searchTimeout = setTimeout(() => {
                applySearchFilters();
            }, 300);
        }

        // Pull-to-refresh functionality
        function setupPullToRefresh() {
            let startY = 0;
            let pullDistance = 0;
            let isPulling = false;
            let refreshThreshold = 100;
            
            const container = document.getElementById('listingsContainer');
            
            container.addEventListener('touchstart', (e) => {
                if (window.scrollY === 0) {
                    startY = e.touches[0].clientY;
                    isPulling = true;
                }
            });
            
            container.addEventListener('touchmove', (e) => {
                if (!isPulling) return;
                
                const currentY = e.touches[0].clientY;
                pullDistance = currentY - startY;
                
                if (pullDistance > 0) {
                    e.preventDefault();
                    
                    // Visual feedback
                    if (pullDistance > refreshThreshold) {
                        container.style.transform = `translateY(${Math.min(pullDistance * 0.5, 50)}px)`;
                        container.style.opacity = '0.7';
                    }
                }
            });
            
            container.addEventListener('touchend', () => {
                if (isPulling && pullDistance > refreshThreshold) {
                    console.log('🔄 Pull to refresh triggered');
                    refreshListings();
                }
                
                // Reset
                container.style.transform = '';
                container.style.opacity = '';
                isPulling = false;
                pullDistance = 0;
            });
        }

        // GPS and Location Services
        let userLocation = null;
        let watchId = null;
        let locationAccuracy = null;

        // Initialize GPS services
        async function initializeGPS() {
            console.log('🛰️ Initializing GPS services...');
            
            if (!navigator.geolocation) {
                console.warn('Geolocation not supported by this browser');
                showLocationError('GPS not supported on this device');
                return false;
            }
            
            // Request location permission
            try {
                const position = await getCurrentLocation();
                userLocation = {
                    latitude: position.coords.latitude,
                    longitude: position.coords.longitude,
                    accuracy: position.coords.accuracy,
                    timestamp: position.timestamp
                };
                
                console.log('✅ GPS initialized:', userLocation);
                
                // Add user location marker to map
                addUserLocationToMap(userLocation);
                
                // Start watching location changes
                startLocationTracking();
                
                // Enable location-based features
                enableLocationFeatures();
                
                return true;
            } catch (error) {
                console.error('❌ GPS initialization failed:', error);
                handleLocationError(error);
                return false;
            }
        }

        // Get current location with promise
        function getCurrentLocation(options = {}) {
            return new Promise((resolve, reject) => {
                const defaultOptions = {
                    enableHighAccuracy: true,
                    timeout: 10000,
                    maximumAge: 60000
                };
                
                navigator.geolocation.getCurrentPosition(
                    resolve,
                    reject,
                    { ...defaultOptions, ...options }
                );
            });
        }

        // Start continuous location tracking
        function startLocationTracking() {
            if (watchId) {
                navigator.geolocation.clearWatch(watchId);
            }
            
            watchId = navigator.geolocation.watchPosition(
                (position) => {
                    userLocation = {
                        latitude: position.coords.latitude,
                        longitude: position.coords.longitude,
                        accuracy: position.coords.accuracy,
                        timestamp: position.timestamp
                    };
                    
                    console.log('📍 Location updated:', userLocation);
                    updateUserLocationOnMap(userLocation);
                },
                (error) => {
                    console.error('Location tracking error:', error);
                },
                {
                    enableHighAccuracy: true,
                    timeout: 30000,
                    maximumAge: 30000
                }
            );
            
            console.log('👁️ Started location tracking');
        }

        // Stop location tracking
        function stopLocationTracking() {
            if (watchId) {
                navigator.geolocation.clearWatch(watchId);
                watchId = null;
                console.log('⏹️ Stopped location tracking');
            }
        }

        // Add user location marker to map
        function addUserLocationToMap(location) {
            if (!map) return;
            
            // Create custom user location icon
            const userIcon = L.divIcon({
                className: 'user-location-marker',
                html: `<div class="user-location-dot">
                    <div class="user-location-pulse"></div>
                </div>`,
                iconSize: [20, 20],
                iconAnchor: [10, 10]
            });
            
            // Add user location marker
            const userMarker = L.marker([location.latitude, location.longitude], {
                icon: userIcon,
                zIndexOffset: 1000
            });
            
            userMarker.addTo(map);
            userMarker.bindPopup('📍 Your Location');
            
            // Store reference for updates
            window.userLocationMarker = userMarker;
            
            // Add accuracy circle
            if (location.accuracy) {
                const accuracyCircle = L.circle([location.latitude, location.longitude], {
                    radius: location.accuracy,
                    color: '#3b82f6',
                    fillColor: '#3b82f6',
                    fillOpacity: 0.1,
                    weight: 1
                });
                
                accuracyCircle.addTo(map);
                window.userAccuracyCircle = accuracyCircle;
            }
        }

        // Update user location on map
        function updateUserLocationOnMap(location) {
            if (window.userLocationMarker) {
                window.userLocationMarker.setLatLng([location.latitude, location.longitude]);
            }
            
            if (window.userAccuracyCircle && location.accuracy) {
                window.userAccuracyCircle.setLatLng([location.latitude, location.longitude]);
                window.userAccuracyCircle.setRadius(location.accuracy);
            }
        }

        // Enable location-based features
        function enableLocationFeatures() {
            // Add "Near Me" button
            addNearMeButton();
            
            // Add navigation buttons to listing cards
            addNavigationButtons();
            
            // Sort listings by distance
            addDistanceSorting();
        }

        // Add "Properties Near Me" button
        function addNearMeButton() {
            const searchContainer = document.querySelector('.search-controls') || document.querySelector('#searchForm');
            if (!searchContainer) return;
            
            const nearMeButton = document.createElement('button');
            nearMeButton.className = 'near-me-btn bg-green-600 text-white px-4 py-2 rounded-lg hover:bg-green-700 transition font-semibold flex items-center gap-2';
            nearMeButton.innerHTML = `
                <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17.657 16.657L13.414 20.9a1.998 1.998 0 01-2.827 0l-4.244-4.243a8 8 0 1111.314 0z"></path>
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 11a3 3 0 11-6 0 3 3 0 016 0z"></path>
                </svg>
                Near Me
            `;
            
            nearMeButton.addEventListener('click', showPropertiesNearMe);
            searchContainer.appendChild(nearMeButton);
        }

        // Show properties near user location
        async function showPropertiesNearMe() {
            if (!userLocation) {
                console.log('🛰️ Getting current location...');
                const button = document.querySelector('.near-me-btn');
                if (button) {
                    button.innerHTML = '📍 Getting location...';
                    button.disabled = true;
                }
                
                try {
                    const position = await getCurrentLocation();
                    userLocation = {
                        latitude: position.coords.latitude,
                        longitude: position.coords.longitude,
                        accuracy: position.coords.accuracy,
                        timestamp: position.timestamp
                    };
                    addUserLocationToMap(userLocation);
                } catch (error) {
                    handleLocationError(error);
                    return;
                } finally {
                    if (button) {
                        button.innerHTML = 'Near Me';
                        button.disabled = false;
                    }
                }
            }
            
            console.log('🔍 Finding properties near:', userLocation);
            
            // Calculate distances and sort listings
            const listingsWithDistance = allListings.map(listing => {
                const distance = calculateDistance(
                    userLocation.latitude,
                    userLocation.longitude,
                    listing.latitude || 0,
                    listing.longitude || 0
                );
                
                return {
                    ...listing,
                    distance: distance
                };
            }).sort((a, b) => a.distance - b.distance);
            
            // Filter to properties within reasonable distance (e.g., 50km)
            const nearbyProperties = listingsWithDistance.filter(listing => listing.distance <= 50);
            
            console.log(`📍 Found ${nearbyProperties.length} properties within 50km`);
            
            // Update UI
            const container = document.getElementById('listingsContainer');
            container.innerHTML = '';
            
            if (nearbyProperties.length === 0) {
                container.innerHTML = `
                    <div class="text-center py-8">
                        <p class="text-gray-600 mb-4">No properties found within 50km of your location.</p>
                        <button class="bg-blue-600 text-white px-4 py-2 rounded hover:bg-blue-700" onclick="displayListings()">
                            Show All Properties
                        </button>
                    </div>
                `;
                return;
            }
            
            // Render nearby properties with distance info
            await renderListingsWithDistance(nearbyProperties);
            
            // Update map to show nearby properties
            await updateMap(nearbyProperties);
            
            // Center map on user location
            if (map) {
                map.setView([userLocation.latitude, userLocation.longitude], 12);
            }
        }

        // Calculate distance between two coordinates (Haversine formula)
        function calculateDistance(lat1, lon1, lat2, lon2) {
            const R = 6371; // Earth's radius in kilometers
            const dLat = (lat2 - lat1) * Math.PI / 180;
            const dLon = (lon2 - lon1) * Math.PI / 180;
            const a = 
                Math.sin(dLat/2) * Math.sin(dLat/2) +
                Math.cos(lat1 * Math.PI / 180) * Math.cos(lat2 * Math.PI / 180) * 
                Math.sin(dLon/2) * Math.sin(dLon/2);
            const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1-a));
            return R * c; // Distance in kilometers
        }

        // Render listings with distance information
        async function renderListingsWithDistance(listings) {
            const container = document.getElementById('listingsContainer');
            const fragment = document.createDocumentFragment();

            listings.forEach(listing => {
                const listingCard = createListingCardWithDistance(listing);
                fragment.appendChild(listingCard);
            });

            container.appendChild(fragment);
            setupListingEventListeners();
        }

        // Create listing card with distance and navigation
        function createListingCardWithDistance(listing) {
            const listingCard = createListingCard(listing);
            
            // Add distance and navigation info
            const cardContent = listingCard.querySelector('.p-4');
            if (cardContent && listing.distance !== undefined) {
                const distanceInfo = document.createElement('div');
                distanceInfo.className = 'flex items-center justify-between text-sm text-gray-600 mt-2 pt-2 border-t border-gray-200';
                distanceInfo.innerHTML = `
                    <span class="flex items-center gap-1">
                        📍 ${listing.distance.toFixed(1)} km away
                    </span>
                    <button class="navigate-btn text-blue-600 hover:text-blue-800 font-medium flex items-center gap-1" data-listing-id="${listing.id}">
                        🧭 Navigate
                    </button>
                `;
                
                cardContent.appendChild(distanceInfo);
            }
            
            return listingCard;
        }

        // Add navigation functionality
        function addNavigationButtons() {
            document.addEventListener('click', (e) => {
                if (e.target.classList.contains('navigate-btn') || e.target.closest('.navigate-btn')) {
                    const button = e.target.closest('.navigate-btn') || e.target;
                    const listingId = button.dataset.listingId;
                    const listing = allListings.find(l => l.id == listingId);
                    
                    if (listing) {
                        navigateToProperty(listing);
                    }
                }
            });
        }

        // Navigate to property
        async function navigateToProperty(listing) {
            console.log('🧭 Navigating to property:', listing.title);
            
            const address = `${listing.street}, ${listing.city}, ${listing.postalCode}`;
            
            // Get property coordinates if not available
            let propertyCoords = null;
            if (listing.latitude && listing.longitude) {
                propertyCoords = { lat: listing.latitude, lon: listing.longitude };
            } else {
                try {
                    propertyCoords = await geocodeLocation(address);
                } catch (error) {
                    console.error('Failed to geocode property address:', error);
                    alert('Unable to get directions to this property. Address may be incomplete.');
                    return;
                }
            }
            
            // Open navigation options
            showNavigationOptions(listing, propertyCoords, address);
        }

        // Show navigation options modal
        function showNavigationOptions(listing, coordinates, address) {
            const modal = document.createElement('div');
            modal.className = 'navigation-modal fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-4';
            modal.innerHTML = `
                <div class="bg-white rounded-lg p-6 max-w-sm w-full">
                    <h3 class="text-lg font-semibold mb-4">Navigate to Property</h3>
                    <p class="text-gray-600 mb-4">${listing.title}</p>
                    <p class="text-sm text-gray-500 mb-6">${address}</p>
                    
                    <div class="space-y-3">
                        <button class="nav-option w-full bg-blue-600 text-white py-3 px-4 rounded-lg hover:bg-blue-700 flex items-center justify-center gap-2" data-type="google">
                            🗺️ Google Maps
                        </button>
                        <button class="nav-option w-full bg-green-600 text-white py-3 px-4 rounded-lg hover:bg-green-700 flex items-center justify-center gap-2" data-type="apple">
                            🧭 Apple Maps
                        </button>
                        <button class="nav-option w-full bg-orange-600 text-white py-3 px-4 rounded-lg hover:bg-orange-700 flex items-center justify-center gap-2" data-type="waze">
                            🚗 Waze
                        </button>
                        <button class="nav-option w-full bg-gray-600 text-white py-3 px-4 rounded-lg hover:bg-gray-700 flex items-center justify-center gap-2" data-type="browser">
                            🌐 Browser Maps
                        </button>
                    </div>
                    
                    <button class="close-modal w-full mt-4 bg-gray-200 text-gray-800 py-2 px-4 rounded-lg hover:bg-gray-300">
                        Cancel
                    </button>
                </div>
            `;
            
            document.body.appendChild(modal);
            
            // Handle navigation option clicks
            modal.addEventListener('click', (e) => {
                if (e.target.classList.contains('nav-option')) {
                    const type = e.target.dataset.type;
                    openNavigation(type, coordinates, address);
                    modal.remove();
                } else if (e.target.classList.contains('close-modal') || e.target === modal) {
                    modal.remove();
                }
            });
        }

        // Open navigation in selected app
        function openNavigation(type, coordinates, address) {
            const lat = coordinates.lat;
            const lon = coordinates.lon;
            const encodedAddress = encodeURIComponent(address);
            
            let url;
            
            switch (type) {
                case 'google':
                    url = `https://www.google.com/maps/dir/?api=1&destination=${lat},${lon}`;
                    break;
                case 'apple':
                    url = `http://maps.apple.com/?daddr=${lat},${lon}`;
                    break;
                case 'waze':
                    url = `https://waze.com/ul?ll=${lat},${lon}&navigate=yes`;
                    break;
                case 'browser':
                    url = `https://www.openstreetmap.org/directions?to=${lat},${lon}`;
                    break;
                default:
                    url = `https://www.google.com/maps/dir/?api=1&destination=${encodedAddress}`;
            }
            
            console.log('🚀 Opening navigation:', url);
            
            // Open in same window for mobile, new tab for desktop
            if (window.innerWidth <= 768) {
                window.location.href = url;
            } else {
                window.open(url, '_blank');
            }
        }

        // Handle location errors
        function handleLocationError(error) {
            let message;
            switch (error.code) {
                case error.PERMISSION_DENIED:
                    message = 'Location access denied. Please enable location services to use GPS features.';
                    break;
                case error.POSITION_UNAVAILABLE:
                    message = 'Location information unavailable.';
                    break;
                case error.TIMEOUT:
                    message = 'Location request timed out.';
                    break;
                default:
                    message = 'An unknown error occurred while retrieving location.';
            }
            
            console.error('Location error:', message);
            showLocationError(message);
        }

        // Show location error to user
        function showLocationError(message) {
            const errorDiv = document.createElement('div');
            errorDiv.className = 'location-error fixed top-4 left-4 right-4 bg-red-100 border border-red-400 text-red-700 px-4 py-3 rounded z-50';
            errorDiv.innerHTML = `
                <div class="flex items-center justify-between">
                    <span>${message}</span>
                    <button class="text-red-700 hover:text-red-900" onclick="this.parentElement.parentElement.remove()">
                        ✕
                    </button>
                </div>
            `;
            
            document.body.appendChild(errorDiv);
            
            // Auto-remove after 5 seconds
            setTimeout(() => {
                if (errorDiv.parentElement) {
                    errorDiv.remove();
                }
            }, 5000);
        }

        // Add distance sorting option
        function addDistanceSorting() {
            // This could be integrated into the existing filter system
            // For now, it's handled by the "Near Me" functionality
        }

        // Property visit functionality
        function startPropertyVisit(listing) {
            if (!window.propertyVisitTracker) {
                console.error('Property visit tracker not initialized');
                alert('Property visit feature not available. Please refresh the page.');
                return;
            }
            
            window.propertyVisitTracker.startVisit(listing.id, listing.title);
        }

        // Make functions globally available
        window.applyQuickFilter = applyQuickFilter;
        window.clearFilters = clearFilters;
        window.debounceSearch = debounceSearch;
        window.refreshListings = refreshListings;
        window.initializeGPS = initializeGPS;
        window.showPropertiesNearMe = showPropertiesNearMe;
        window.navigateToProperty = navigateToProperty;
        window.startPropertyVisit = startPropertyVisit;
                });
                
                // Update map with filtered results
                await updateMap(filteredListings);
                
            } catch (error) {
                console.error('Search error:', error);
                alert('Search failed: ' + error.message);
            }
        }

        function clearSearchFilters() {
            console.log('🧹 Clearing search filters...');
            
            // Clear input fields
            document.getElementById('searchLocation').value = '';
            document.getElementById('searchMaxPrice').value = '';
            document.getElementById('searchRoomType').value = '';
            document.getElementById('searchBedrooms').value = '';
            
            // Reset to show all listings
            filteredListings = [];
            displayListings();
        }
        
        function displayListingCard(listing, container) {
            let media = listing.media || [];
            if (!Array.isArray(media)) {
                media = [];
            }

            media = media.map(item => {
                if (item.type === 'application/json' || !item.type || item.type === 'application/octet-stream') {
                    const extension = item.name.split('.').pop().toLowerCase();
                    let correctedType;
                    switch (extension) {
                        case 'jpg':
                        case 'jpeg':
                            correctedType = 'image/jpeg';
                            break;
                        case 'png':
                            correctedType = 'image/png';
                            break;
                        case 'mp4':
                            correctedType = 'video/mp4';
                            break;
                        default:
                            correctedType = item.type || 'application/octet-stream';
                    }
                    return { ...item, type: correctedType };
                }
                return item;
            });

            const isImage = (file) => {
                const byType = file.type.startsWith('image/');
                const byExtension = file.name.match(/\.(jpg|jpeg|png)$/i);
                return byType || byExtension;
            };

            const primaryImage = media.length > 0 && isImage(media[0])
                ? media[0].url
                : 'data:image/svg+xml;base64,PHN2ZyB3aWR0aD0iMzAwIiBoZWlnaHQ9IjIwMCIgeG1sbnM9Imh0dHA6Ly93d3cudzMub3JnLzIwMDAvc3ZnIj48cmVjdCB3aWR0aD0iMTAwJSIgaGVpZ2h0PSIxMDAlIiBmaWxsPSIjZjNmNGY2Ii8+PHRleHQgeD0iNTAlIiB5PSI1MCUiIGZvbnQtZmFtaWx5PSJBcmlhbCIgZm9udC1zaXplPSIxOCIgZmlsbD0iIzY2NzI4MCIgdGV4dC1hbmNob3I9Im1pZGRsZSIgZHk9Ii4zZW0iPk5vIEltYWdlPC90ZXh0Pjwvc3ZnPg==';

            const perspectiveContainer = document.createElement('div'); // New perspective container
            perspectiveContainer.className = 'listing-card-perspective-container';

            const listingCard = document.createElement('div');
            // Tailwind classes like bg-white, rounded-lg, shadow-md, overflow-hidden are applied to listingCard
            listingCard.className = 'listing-card'; // Custom class for JS targeting and 3D effects

            const hasOwner = !!listing.user_email;
            listingCard.innerHTML = `
                <img src="${primaryImage}" alt="${listing.title}" class="listing-image" onerror="this.src='data:image/svg+xml;base64,PHN2ZyB3aWR0aD0iMzAwIiBoZWlnaHQ9IjIwMCIgeG1sbnM9Imh0dHA6Ly93d3cudzMub3JnLzIwMDAvc3ZnIj48cmVjdCB3aWR0aD0iMTAwJSIgaGVpZ2h0PSIxMDAlIiBmaWxsPSIjZmY2Njc3Ii8+PHRleHQgeD0iNTAlIiB5PSI1MCUiIGZvbnQtZmFtaWx5PSJBcmlhbCIgZm9udC1zaXplPSIxOCIgZmlsbD0iI2ZmZmZmZiIgdGV4dC1hbmNob3I9Im1pZGRsZSIgZHk9Ii4zZW0iPkltYWdlIE5vdCBBdmFpbGFibGU8L3RleHQ+PC9zdmc+'">
                <div class="p-4">
                    <h3 class="text-lg font-semibold text-gray-800 truncate">${listing.title}</h3>
                    <p class="text-xl font-bold text-blue-600">$${listing.price.toLocaleString()}/mo</p>
                    <p class="text-gray-600 text-sm">${listing.street}, ${listing.city}, ${listing.postalCode}</p>
                    <div class="flex items-center space-x-2 text-sm text-gray-600 mt-2">
                        <span>${listing.bedrooms} Bed</span>
                        <span>•</span>
                        <span>${listing.house_type}</span>
                        <span>•</span>
                        <span>${listing.utilities}</span>
                    </div>
                    <p class="text-gray-600 text-sm mt-2 line-clamp-2">${listing.description || 'No description provided'}</p>
                    <div class="flex space-x-2 mt-4">
                        <button class="view-details-btn w-1/2 bg-blue-600 text-white px-4 py-2 rounded-lg hover:bg-blue-700 transition font-semibold shadow-md hover:shadow-lg" data-listing='${JSON.stringify(listing)}'>View Details</button>
                        <button class="chat-btn w-1/2 bg-green-600 text-white px-4 py-2 rounded-lg transition ${hasOwner ? 'hover:bg-green-700' : ''} font-semibold shadow-md hover:shadow-lg" data-listing='${JSON.stringify(listing)}' ${hasOwner ? '' : 'disabled title="No owner specified for this listing"'}>Chat</button>
                    </div>
                </div>
            `;
            // Apply Tailwind classes directly here for simplicity, as .listing-card CSS focuses on 3D aspects
            listingCard.classList.add('bg-white', 'rounded-lg', 'shadow-md', 'overflow-hidden');


            perspectiveContainer.appendChild(listingCard); // Append card to perspective container
            container.appendChild(perspectiveContainer); // Append perspective container to main listings container

            // Add event listeners for this card
            const viewDetailsBtn = listingCard.querySelector('.view-details-btn');
            const chatBtn = listingCard.querySelector('.chat-btn');
            
            viewDetailsBtn.addEventListener('click', () => {
                const listing = JSON.parse(viewDetailsBtn.dataset.listing);
                showListingModal(listing);
            });

            if (!chatBtn.disabled) {
                chatBtn.addEventListener('click', () => {
                    try {
                        console.log('🎯 Chat button clicked for listing:', chatBtn.dataset.listing);
                        const listing = JSON.parse(chatBtn.dataset.listing);
                        console.log('📋 Parsed listing data:', listing);
                        startConversation(listing);
                    } catch (error) {
                        console.error('❌ Error parsing listing data or starting conversation:', error);
                        alert('Error opening chat. Please refresh the page and try again.');
                    }
                });
            } else {
                console.log('⚠️ Chat button is disabled for listing - no owner email specified');
            }
        }


        // Real-time subscription to listings
        if (typeof supabase !== 'undefined' && supabase) {
            supabase
                .channel('public:listings')
                .on('postgres_changes', { event: 'INSERT', schema: 'public', table: 'listings' }, (payload) => {
                    console.log('New listing added:', payload.new);
                    displayListings();
                })
                .subscribe((status) => {
                    console.log('Listings channel status:', status);
                });
        } else {
            console.warn('Supabase not initialized for real-time listings subscription');
        }
