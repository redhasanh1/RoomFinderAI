// Form Manager - Handles form submission and media upload
class FormManager {
    constructor(listingsManager) {
        this.listingsManager = listingsManager;
        this.supabase = null;
        this.uploadedFiles = [];
        this.cities = [];
        this.typo = null;
        this.SUPABASE_URL = null;
        this.SUPABASE_ANON_KEY = null;
    }

    // Initialize with configuration
    initialize(supabaseClient, config) {
        this.supabase = supabaseClient;
        this.SUPABASE_URL = config.SUPABASE_URL;
        this.SUPABASE_ANON_KEY = config.SUPABASE_ANON_KEY;
        this.initializeTypo();
        this.loadCities();
        this.setupFormEventListeners();
        this.setupAutocomplete();
        console.log('✅ FormManager initialized');
    }

    // Initialize Typo.js for autocorrect
    initializeTypo() {
        try {
            this.typo = new Typo('en_US', false, false, {
                dictionaryPath: 'https://unpkg.com/typo-js@1.2.3/dictionaries'
            });
            this.typo.dictionary['roomfinder'] = 1;
            this.typo.dictionary['wifi'] = 1;
            this.typo.dictionary['appartment'] = 1;
            this.typo.dictionary['condo'] = 1;
            this.typo.dictionary['sublease'] = 1;
            this.typo.dictionary['negoitator'] = 1;
            console.log('✅ Typo.js initialized');
        } catch (error) {
            console.warn('⚠️ Failed to initialize Typo.js:', error);
        }
    }

    // Load cities for autocomplete
    async loadCities() {
        try {
            const response = await fetch('https://unpkg.com/cities.json@1.1.0/cities.json');
            const data = await response.json();
            this.cities = data;
            console.log('Cities loaded:', this.cities.length);
        } catch (error) {
            console.error('Error loading cities:', error);
            alert('Failed to load city data. Please enter city manually.');
            const cityInput = document.getElementById('city');
            if (cityInput) {
                cityInput.placeholder = 'Enter city manually (e.g., Toronto)';
            }
        }
    }

    // Smart Autocorrect - preserves addresses, numbers, and proper nouns
    autocorrectInput(input) {
        if (typeof input !== 'string' || !input || !this.typo) return input;
        
        const words = input.split(' ');
        const correctedWords = words.map(word => {
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
            if (this.typo.check(word)) {
                return word;
            }
            
            // 5. Only correct if word is clearly misspelled and suggestion is confident
            const suggestions = this.typo.suggest(word);
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
    cleanAddressInput(input) {
        if (typeof input !== 'string') return '';
        return input.trim()
            .replace(/\s+/g, ' ')  // Multiple spaces to single
            .replace(/[^\w\s\-.,#]/g, ''); // Remove special chars except basic ones
    }

    sanitizeInput(input) {
        if (typeof input !== 'string') return '';
        return input.replace(/[^a-zA-Z0-9\s,.-]/g, '').trim();
    }

    // Setup autocomplete for city input
    setupAutocomplete() {
        const cityInput = document.getElementById('city');
        const cityDropdown = document.getElementById('city-autocomplete-dropdown');
        
        if (!cityInput || !cityDropdown) return;

        let debounceTimeout;

        const showCitySuggestions = (input) => {
            cityDropdown.innerHTML = '';
            cityDropdown.classList.add('hidden');
            if (!input || this.cities.length === 0) return;

            const filtered = this.cities
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
        };

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
    }

    // Setup form event listeners
    setupFormEventListeners() {
        // File upload and preview
        const mediaInput = document.getElementById('media');
        const mediaPreview = document.getElementById('mediaPreview');
        
        if (mediaInput && mediaPreview) {
            mediaInput.addEventListener('change', () => {
                this.handleFileUpload(mediaInput, mediaPreview);
            });
        }

        // Form submission
        const listingForm = document.getElementById('listingForm');
        if (listingForm) {
            listingForm.addEventListener('submit', (e) => {
                this.handleFormSubmission(e);
            });
        }
    }

    // Handle file upload and preview
    handleFileUpload(mediaInput, mediaPreview) {
        mediaPreview.innerHTML = '';
        this.uploadedFiles = [];
        const files = Array.from(mediaInput.files);
        let totalSize = 0;

        files.forEach(file => {
            totalSize += file.size;
            if (totalSize > 10 * 1024 * 1024) {
                alert('Total file size exceeds 10MB limit.');
                mediaInput.value = '';
                mediaPreview.innerHTML = '';
                this.uploadedFiles = [];
                return;
            }

            const reader = new FileReader();
            reader.onload = (e) => {
                const dataUrl = e.target.result;
                this.uploadedFiles.push({ name: file.name, type: file.type, data: dataUrl, file: file });
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
    }

    // Upload media to Supabase
    async uploadMedia(files) {
        const uploadedMedia = [];
        const storageApiUrl = this.SUPABASE_URL + '/storage/v1/object/listing-media/Photos';

        for (const fileObj of files) {
            const file = fileObj.file;
            const fileName = Date.now() + '-' + file.name.replace(/[^a-zA-Z0-9.-]/g, '_');
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
                        'Authorization': `Bearer ${this.SUPABASE_ANON_KEY}`,
                        'apikey': this.SUPABASE_ANON_KEY
                    },
                    body: formData
                });

                if (!response.ok) {
                    const errorText = await response.text();
                    throw new Error('Upload failed: ' + response.status + ' - ' + errorText);
                }

                const publicUrl = this.SUPABASE_URL + '/storage/v1/object/public/listing-media/Photos/' + filePath;
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

    // Handle form submission
    async handleFormSubmission(e) {
        e.preventDefault();

        const currentUser = JSON.parse(localStorage.getItem('currentUser'));
        if (!currentUser) {
            alert('Please log in to add a listing.');
            window.location.href = '/login';
            return;
        }

        try {
            const media = this.uploadedFiles.length > 0 ? await this.uploadMedia(this.uploadedFiles) : [];

            // Log original input values for debugging
            const originalValues = {
                city: document.getElementById('city').value,
                street: document.getElementById('street').value,
                postalCode: document.getElementById('postalCode').value
            };
            console.log('📝 Original address input:', originalValues);

            const listing = {
                title: this.autocorrectInput(this.sanitizeInput(document.getElementById('title').value)),
                price: parseInt(document.getElementById('price').value),
                city: this.cleanAddressInput(document.getElementById('city').value),
                street: this.cleanAddressInput(document.getElementById('street').value),
                postalCode: document.getElementById('postalCode').value.trim().toUpperCase().replace(/\s+/g, ' '),
                house_type: document.getElementById('houseType').value,
                bedrooms: parseInt(document.getElementById('bedrooms').value),
                utilities: document.getElementById('utilities').value,
                description: this.autocorrectInput(this.sanitizeInput(document.getElementById('description').value)),
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

            const { data, error } = await this.supabase
                .from('listings')
                .insert([listing])
                .select();

            if (error) {
                console.error('Error inserting listing:', error);
                alert('Failed to add listing: ' + error.message);
                return;
            }

            const newListing = Object.assign({}, listing, {
                id: data[0].id,
                media: media
            });
            currentUser.listings = currentUser.listings || [];
            currentUser.listings.push(newListing);
            let users = JSON.parse(localStorage.getItem('users')) || [];
            users = users.map(u => u.email === currentUser.email ? currentUser : u);
            localStorage.setItem('users', JSON.stringify(users));
            localStorage.setItem('currentUser', JSON.stringify(currentUser));
            console.log('Updated localStorage with new listing:', newListing);

            e.target.reset();
            const mediaPreview = document.getElementById('mediaPreview');
            if (mediaPreview) mediaPreview.innerHTML = '';
            this.uploadedFiles = [];

            alert('Listing added successfully!');
            console.log('🔄 Refreshing listings and map after new listing added');
            if (this.listingsManager) {
                await this.listingsManager.displayListings();
            }
        } catch (err) {
            console.error('Submission failed:', err);
            alert('Failed to add listing: ' + (err.message || err));
        }
    }
}

// Export for global use
window.FormManager = FormManager;