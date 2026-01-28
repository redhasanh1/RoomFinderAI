// RoomPal - Simplified Roommate Matching
// Two paths: "I Have a Room" and "I Need a Room"

class RoomPalApp {
    constructor() {
        this.currentSection = 'landing';
        this.currentUser = null;
        this.api = null;
        this.allRooms = [];
        this.filteredRooms = [];
        this.allPeople = [];
        this.filteredPeople = [];
        this.uploadedPhoto = null;

        this.init();
    }

    async init() {
        // Initialize API service
        if (typeof RoommateAPIService !== 'undefined') {
            this.api = new RoommateAPIService();
        }

        // Load current user
        this.loadCurrentUser();
        this.updateHeader();

        // Setup event listeners
        this.setupEventListeners();

        console.log('RoomPal App initialized');
    }

    loadCurrentUser() {
        const stored = localStorage.getItem('currentUser');
        if (stored) {
            this.currentUser = JSON.parse(stored);
        }
    }

    updateHeader() {
        const desktopAuth = document.getElementById('desktopAuthSection');
        const mobileAuth = document.getElementById('mobileAuthLink');

        if (this.currentUser) {
            const userName = this.currentUser.firstName || this.currentUser.name || 'User';

            if (desktopAuth) {
                desktopAuth.innerHTML = `
                    <div class="flex items-center gap-3">
                        <span class="text-gray-700">Hi, ${userName}</span>
                        <a href="profile.html" class="btn-secondary">Profile</a>
                    </div>
                `;
            }

            if (mobileAuth) {
                mobileAuth.textContent = `Hi, ${userName}`;
                mobileAuth.href = 'profile.html';
            }
        }
    }

    setupEventListeners() {
        // Room form submission
        const roomForm = document.getElementById('roomForm');
        if (roomForm) {
            roomForm.addEventListener('submit', (e) => this.handleRoomFormSubmit(e));
        }

        // Contact form submission
        const contactForm = document.getElementById('contactForm');
        if (contactForm) {
            contactForm.addEventListener('submit', (e) => this.handleContactSubmit(e));
        }

        // Photo upload
        const roomPhoto = document.getElementById('roomPhoto');
        if (roomPhoto) {
            roomPhoto.addEventListener('change', (e) => this.handlePhotoUpload(e, 'roomPhotoPreview'));
        }
    }

    // ==================== SECTION NAVIGATION ====================

    showSection(section) {
        const sectionMap = {
            'landing': 'landingSection',
            'hasRoom': 'hasRoomSection',
            'needRoom': 'needRoomSection',
            'findPeople': 'findPeopleSection',
            'success': 'successSection'
        };

        // Hide all sections
        document.querySelectorAll('.section-view').forEach(el => {
            el.classList.remove('active');
        });

        // Show target section
        const targetId = sectionMap[section];
        if (targetId) {
            const targetEl = document.getElementById(targetId);
            if (targetEl) {
                targetEl.classList.add('active');
                this.currentSection = section;

                // Load data for sections
                if (section === 'needRoom') {
                    this.loadRooms();
                } else if (section === 'findPeople') {
                    this.loadPeople();
                }
            }
        }

        window.scrollTo({ top: 0, behavior: 'smooth' });
    }

    // ==================== LOAD ROOMS ====================

    async loadRooms() {
        const grid = document.getElementById('roomsGrid');
        const emptyState = document.getElementById('emptyState');
        const resultsCount = document.getElementById('resultsCount');

        if (!grid) return;

        // Show loading
        grid.innerHTML = '<p class="col-span-2 text-center text-gray-500 py-8">Loading rooms...</p>';

        try {
            // Get rooms from API
            const rooms = await this.getRooms();
            this.allRooms = rooms;
            this.filteredRooms = rooms;

            this.renderRooms();
        } catch (error) {
            console.error('Error loading rooms:', error);
            grid.innerHTML = '<p class="col-span-2 text-center text-red-500 py-8">Failed to load rooms</p>';
        }
    }

    async getRooms() {
        if (this.api && this.api.initialized) {
            try {
                const rooms = await this.api.getRoomPosts({ limit: 50 });
                if (rooms && rooms.length > 0) {
                    return rooms;
                }
            } catch (e) {
                console.log('API error, returning empty:', e);
            }
        }
        return [];
    }

    renderRooms() {
        const grid = document.getElementById('roomsGrid');
        const emptyState = document.getElementById('emptyState');
        const resultsCount = document.getElementById('resultsCount');

        if (this.filteredRooms.length === 0) {
            grid.classList.add('hidden');
            emptyState.classList.remove('hidden');
            resultsCount.textContent = 'No rooms found';
            return;
        }

        grid.classList.remove('hidden');
        emptyState.classList.add('hidden');
        resultsCount.textContent = `${this.filteredRooms.length} room${this.filteredRooms.length !== 1 ? 's' : ''} available`;

        grid.innerHTML = this.filteredRooms.map(room => this.createRoomCard(room)).join('');
    }

    createRoomCard(room) {
        const photoUrl = room.room_photos?.[0] || room.photo_url || 'https://images.unsplash.com/photo-1522708323590-d24dbb6b0267?w=400&h=300&fit=crop';
        const rent = room.room_rent || room.rent || 0;
        const location = room.room_location || room.location || 'Location not specified';
        const description = room.room_description || room.description || 'No description provided';
        const availableDate = room.room_available_date || room.available_date;
        const formattedDate = availableDate ? this.formatDate(availableDate) : 'Available Now';
        const hostName = room.name || 'Host';

        return `
            <div class="room-card">
                <img src="${photoUrl}" alt="Room photo" class="room-image" onerror="this.src='https://images.unsplash.com/photo-1522708323590-d24dbb6b0267?w=400&h=300&fit=crop'">
                <div class="p-5">
                    <div class="flex justify-between items-start mb-2">
                        <span class="room-price">$${rent}/mo</span>
                        <span class="text-sm text-gray-500">${formattedDate}</span>
                    </div>
                    <h3 class="room-location mb-2">${location}</h3>
                    <p class="room-description mb-4">${description}</p>
                    <button onclick="roomPalApp.openContact('${room.id}', '${hostName}')" class="btn-primary w-full">
                        Contact ${hostName}
                    </button>
                </div>
            </div>
        `;
    }

    // ==================== FILTERS ====================

    applyFilters() {
        const budgetFilter = document.getElementById('budgetFilter')?.value;

        this.filteredRooms = this.allRooms.filter(room => {
            const rent = room.room_rent || room.rent || 0;

            if (budgetFilter) {
                if (budgetFilter === '0-1000' && rent > 1000) return false;
                if (budgetFilter === '1000-1500' && (rent < 1000 || rent > 1500)) return false;
                if (budgetFilter === '1500-2000' && (rent < 1500 || rent > 2000)) return false;
                if (budgetFilter === '2000+' && rent < 2000) return false;
            }

            return true;
        });

        this.renderRooms();
    }

    // ==================== LOAD PEOPLE ====================

    async loadPeople() {
        const grid = document.getElementById('peopleGrid');
        const emptyState = document.getElementById('peopleEmptyState');
        const resultsCount = document.getElementById('peopleResultsCount');

        if (!grid) return;

        // Show loading
        grid.innerHTML = '<p class="col-span-full text-center text-gray-500 py-8">Loading people...</p>';

        try {
            // Get people from API
            const people = await this.getPeople();
            this.allPeople = people;
            this.filteredPeople = people;

            this.renderPeople();
        } catch (error) {
            console.error('Error loading people:', error);
            grid.innerHTML = '<p class="col-span-full text-center text-red-500 py-8">Failed to load people</p>';
        }
    }

    async getPeople() {
        if (this.api && this.api.initialized) {
            try {
                const people = await this.api.getSeekerProfiles({ limit: 50 });
                if (people && people.length > 0) {
                    return people;
                }
            } catch (e) {
                console.log('API error, returning empty:', e);
            }
        }
        return [];
    }

    renderPeople() {
        const grid = document.getElementById('peopleGrid');
        const emptyState = document.getElementById('peopleEmptyState');
        const resultsCount = document.getElementById('peopleResultsCount');

        if (this.filteredPeople.length === 0) {
            grid.classList.add('hidden');
            emptyState.classList.remove('hidden');
            resultsCount.textContent = 'No people found';
            return;
        }

        grid.classList.remove('hidden');
        emptyState.classList.add('hidden');
        resultsCount.textContent = `${this.filteredPeople.length} ${this.filteredPeople.length === 1 ? 'person' : 'people'} looking`;

        grid.innerHTML = this.filteredPeople.map(person => this.createPersonCard(person)).join('');
    }

    createPersonCard(person) {
        const avatarUrl = person.avatar_url || `https://ui-avatars.com/api/?name=${encodeURIComponent(person.name || 'User')}&background=6366f1&color=fff&size=160`;
        const name = person.name || 'Anonymous';
        const age = person.age ? `, ${person.age}` : '';
        const location = person.preferred_areas?.[0] || person.location || 'Location flexible';
        const budgetMin = person.budget_min || 0;
        const budgetMax = person.budget_max || 0;
        const budgetText = budgetMin && budgetMax ? `$${budgetMin} - $${budgetMax}/mo` : (budgetMax ? `Up to $${budgetMax}/mo` : 'Budget flexible');
        const bio = person.bio || 'Looking for a great roommate situation!';
        const truncatedBio = bio.length > 100 ? bio.substring(0, 100) + '...' : bio;
        const moveInDate = person.move_in_date ? this.formatDate(person.move_in_date) : 'Flexible';

        return `
            <div class="person-card">
                <div class="person-avatar-section">
                    <img src="${avatarUrl}" alt="${name}" class="person-avatar" onerror="this.src='https://ui-avatars.com/api/?name=${encodeURIComponent(name)}&background=6366f1&color=fff&size=160'">
                </div>
                <div class="person-info">
                    <h3 class="person-name">${name}${age}</h3>
                    <div class="person-details">
                        <span class="person-detail">
                            <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17.657 16.657L13.414 20.9a1.998 1.998 0 01-2.827 0l-4.244-4.243a8 8 0 1111.314 0z"/>
                                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 11a3 3 0 11-6 0 3 3 0 016 0z"/>
                            </svg>
                            ${location}
                        </span>
                        <span class="person-detail">
                            <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8c-1.657 0-3 .895-3 2s1.343 2 3 2 3 .895 3 2-1.343 2-3 2m0-8c1.11 0 2.08.402 2.599 1M12 8V7m0 1v8m0 0v1m0-1c-1.11 0-2.08-.402-2.599-1M21 12a9 9 0 11-18 0 9 9 0 0118 0z"/>
                            </svg>
                            ${budgetText}
                        </span>
                        <span class="person-detail">
                            <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z"/>
                            </svg>
                            ${moveInDate}
                        </span>
                    </div>
                    <p class="person-bio">${truncatedBio}</p>
                    <button onclick="roomPalApp.openPersonContact('${person.id}', '${name.replace(/'/g, "\\'")}')" class="btn-connect">
                        Connect
                    </button>
                </div>
            </div>
        `;
    }

    applyPeopleFilters() {
        const budgetFilter = document.getElementById('peopleBudgetFilter')?.value;

        this.filteredPeople = this.allPeople.filter(person => {
            const budgetMax = person.budget_max || 0;

            if (budgetFilter) {
                if (budgetFilter === '0-800' && budgetMax > 800) return false;
                if (budgetFilter === '800-1200' && (budgetMax < 800 || budgetMax > 1200)) return false;
                if (budgetFilter === '1200-1600' && (budgetMax < 1200 || budgetMax > 1600)) return false;
                if (budgetFilter === '1600+' && budgetMax < 1600) return false;
            }

            return true;
        });

        this.renderPeople();
    }

    openPersonContact(personId, personName) {
        if (!this.currentUser) {
            alert('Please log in to connect with people.');
            window.location.href = 'login.html';
            return;
        }

        this.contactRoomId = personId;
        this.contactHostName = personName;

        // Update modal title
        const modalTitle = document.getElementById('contactModalTitle');
        if (modalTitle) {
            modalTitle.textContent = `Connect with ${personName}`;
        }

        // Update placeholder
        const messageInput = document.getElementById('contactMessage');
        if (messageInput) {
            messageInput.placeholder = `Hi ${personName}! I have a room available that might interest you...`;
        }

        const recipientEl = document.getElementById('contactRecipient');
        if (recipientEl) {
            const person = this.allPeople.find(p => p.id === personId);
            const avatarUrl = person?.avatar_url || `https://ui-avatars.com/api/?name=${encodeURIComponent(personName)}&background=6366f1&color=fff&size=80`;

            recipientEl.innerHTML = `
                <img src="${avatarUrl}" alt="${personName}" class="w-12 h-12 rounded-full object-cover" onerror="this.src='https://ui-avatars.com/api/?name=${encodeURIComponent(personName)}&background=6366f1&color=fff&size=80'">
                <div>
                    <p class="font-medium text-gray-900">${personName}</p>
                    <p class="text-sm text-gray-500">Looking for a room</p>
                </div>
            `;
        }

        const modal = document.getElementById('contactModal');
        modal.classList.remove('hidden');
        modal.classList.add('flex');
    }

    // ==================== FORM HANDLERS ====================

    async handleRoomFormSubmit(e) {
        e.preventDefault();

        // Check login
        if (!this.currentUser) {
            alert('Please log in to post a room.');
            window.location.href = 'login.html';
            return;
        }

        const form = e.target;
        const formData = new FormData(form);

        const roomData = {
            room_location: formData.get('location'),
            room_rent: parseInt(formData.get('rent')),
            room_available_date: formData.get('available_date'),
            room_description: formData.get('description'),
            room_photos: this.uploadedPhoto ? [this.uploadedPhoto] : [],
            name: this.currentUser?.firstName || 'Host'
        };

        // Show loading
        const submitBtn = form.querySelector('button[type="submit"]');
        const originalText = submitBtn.textContent;
        submitBtn.textContent = 'Posting...';
        submitBtn.disabled = true;

        try {
            if (this.api && this.api.initialized) {
                const result = await this.api.saveRoomPost(roomData);
                if (!result.success) {
                    throw new Error(result.error || 'Failed to post room');
                }
            } else {
                // Save locally as fallback
                const localRooms = JSON.parse(localStorage.getItem('localRooms') || '[]');
                roomData.id = 'room_' + Date.now();
                roomData.created_at = new Date().toISOString();
                localRooms.push(roomData);
                localStorage.setItem('localRooms', JSON.stringify(localRooms));
            }

            // Show success
            form.reset();
            this.uploadedPhoto = null;
            document.getElementById('roomPhotoPreview').innerHTML = '';
            this.showSection('success');

        } catch (error) {
            console.error('Error posting room:', error);
            this.showToast('Failed to post room. Please try again.', 'error');
        } finally {
            submitBtn.textContent = originalText;
            submitBtn.disabled = false;
        }
    }

    handlePhotoUpload(e, previewId) {
        const files = e.target.files;
        if (!files.length) return;

        const file = files[0];
        const reader = new FileReader();
        reader.onload = (event) => {
            this.uploadedPhoto = event.target.result;
            const previewEl = document.getElementById(previewId);
            if (previewEl) {
                previewEl.innerHTML = `
                    <img src="${event.target.result}" class="w-32 h-24 object-cover rounded-lg">
                `;
            }
        };
        reader.readAsDataURL(file);
    }

    // ==================== CONTACT MODAL ====================

    openContact(roomId, hostName) {
        if (!this.currentUser) {
            alert('Please log in to contact hosts.');
            window.location.href = 'login.html';
            return;
        }

        this.contactRoomId = roomId;
        this.contactHostName = hostName;

        // Update modal title
        const modalTitle = document.getElementById('contactModalTitle');
        if (modalTitle) {
            modalTitle.textContent = 'Contact Host';
        }

        // Update placeholder
        const messageInput = document.getElementById('contactMessage');
        if (messageInput) {
            messageInput.placeholder = "Hi! I'm interested in your room...";
        }

        const recipientEl = document.getElementById('contactRecipient');
        if (recipientEl) {
            recipientEl.innerHTML = `
                <div class="w-10 h-10 bg-indigo-100 rounded-full flex items-center justify-center">
                    <svg class="w-5 h-5 text-indigo-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z"/>
                    </svg>
                </div>
                <div>
                    <p class="font-medium text-gray-900">${hostName}</p>
                    <p class="text-sm text-gray-500">Room host</p>
                </div>
            `;
        }

        const modal = document.getElementById('contactModal');
        modal.classList.remove('hidden');
        modal.classList.add('flex');
    }

    closeContactModal() {
        const modal = document.getElementById('contactModal');
        modal.classList.add('hidden');
        modal.classList.remove('flex');
    }

    async handleContactSubmit(e) {
        e.preventDefault();

        const form = e.target;
        const message = form.querySelector('textarea[name="message"]').value;

        const submitBtn = form.querySelector('button[type="submit"]');
        const originalText = submitBtn.textContent;
        submitBtn.textContent = 'Sending...';
        submitBtn.disabled = true;

        try {
            if (this.api && this.api.initialized) {
                await this.api.sendMessage(this.contactRoomId, message);
            }

            this.showToast('Message sent!', 'success');
            this.closeContactModal();
            form.reset();
        } catch (error) {
            console.error('Error sending message:', error);
            this.showToast('Failed to send message', 'error');
        } finally {
            submitBtn.textContent = originalText;
            submitBtn.disabled = false;
        }
    }

    // ==================== UTILITIES ====================

    formatDate(dateStr) {
        if (!dateStr) return 'Available Now';
        const date = new Date(dateStr);
        const now = new Date();
        const diffDays = Math.ceil((date - now) / (1000 * 60 * 60 * 24));

        if (diffDays <= 0) return 'Available Now';
        if (diffDays <= 7) return 'This Week';
        if (diffDays <= 14) return 'Next Week';

        return date.toLocaleDateString('en-US', { month: 'short', day: 'numeric' });
    }

    showToast(message, type = 'info') {
        const toast = document.createElement('div');
        toast.className = `fixed bottom-4 right-4 px-6 py-3 rounded-lg text-white z-50 ${
            type === 'success' ? 'bg-emerald-500' :
            type === 'error' ? 'bg-red-500' : 'bg-indigo-500'
        }`;
        toast.textContent = message;

        document.body.appendChild(toast);

        setTimeout(() => {
            toast.style.opacity = '0';
            toast.style.transform = 'translateY(10px)';
            setTimeout(() => toast.remove(), 300);
        }, 3000);
    }
}

// Global functions
function showSection(section) {
    if (window.roomPalApp) {
        window.roomPalApp.showSection(section);
    }
}

function closeContactModal() {
    if (window.roomPalApp) {
        window.roomPalApp.closeContactModal();
    }
}

// Initialize
document.addEventListener('DOMContentLoaded', () => {
    window.roomPalApp = new RoomPalApp();
});
