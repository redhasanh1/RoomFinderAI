// RoomPal - Simple Roommate Matching App
// Simplified, no-hassle platform to find roommates quickly

class RoomPalApp {
    constructor() {
        this.currentSection = 'selector';
        this.currentUser = null;
        this.userProfile = null;
        this.userGroup = null;
        this.api = null;

        this.init();
    }

    async init() {
        // Initialize API service
        if (typeof RoommateAPIService !== 'undefined') {
            this.api = new RoommateAPIService();
        }

        // Load current user from localStorage
        this.loadCurrentUser();

        // Setup event listeners
        this.setupEventListeners();

        // Load initial data
        await this.loadPreviewData();

        console.log('RoomPal App initialized');
    }

    loadCurrentUser() {
        const stored = localStorage.getItem('currentUser');
        if (stored) {
            this.currentUser = JSON.parse(stored);
        }

        const storedProfile = localStorage.getItem('roommateProfile');
        if (storedProfile) {
            this.userProfile = JSON.parse(storedProfile);
        }

        const storedGroup = localStorage.getItem('roommateGroup');
        if (storedGroup) {
            this.userGroup = JSON.parse(storedGroup);
        }
    }

    setupEventListeners() {
        // Tab switching
        document.querySelectorAll('.tab-btn').forEach(btn => {
            btn.addEventListener('click', (e) => this.handleTabClick(e));
        });

        // Filter pills
        document.querySelectorAll('.filter-pill').forEach(pill => {
            pill.addEventListener('click', (e) => this.handleFilterClick(e));
        });

        // Room form submission
        const roomForm = document.getElementById('roomForm');
        if (roomForm) {
            roomForm.addEventListener('submit', (e) => this.handleRoomFormSubmit(e));
        }

        // Seeker form submission
        const seekerForm = document.getElementById('seekerForm');
        if (seekerForm) {
            seekerForm.addEventListener('submit', (e) => this.handleSeekerFormSubmit(e));
        }

        // Compatibility form submission
        const compatibilityForm = document.getElementById('compatibilityForm');
        if (compatibilityForm) {
            compatibilityForm.addEventListener('submit', (e) => this.handleCompatibilitySubmit(e));
        }

        // Message form submission
        const messageForm = document.getElementById('messageForm');
        if (messageForm) {
            messageForm.addEventListener('submit', (e) => this.handleMessageSubmit(e));
        }

        // Photo upload handlers
        const roomPhotos = document.getElementById('roomPhotos');
        if (roomPhotos) {
            roomPhotos.addEventListener('change', (e) => this.handlePhotoUpload(e, 'room'));
        }

        const profilePhoto = document.getElementById('profilePhoto');
        if (profilePhoto) {
            profilePhoto.addEventListener('change', (e) => this.handlePhotoUpload(e, 'profile'));
        }
    }

    // ==================== SECTION NAVIGATION ====================

    showSection(section) {
        // Map section names to element IDs
        const sectionMap = {
            'selector': 'sectionSelector',
            'hasRoom': 'hasRoomSection',
            'seeking': 'seekingSection',
            'browseRooms': 'browseRoomsSection',
            'browseSeekers': 'browseSeekersSection'
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

                // Load section-specific data
                this.loadSectionData(section);
            }
        }

        // Scroll to top
        window.scrollTo({ top: 0, behavior: 'smooth' });
    }

    async loadSectionData(section) {
        switch (section) {
            case 'browseRooms':
                await this.loadRoomsGrid('roomsGrid');
                break;
            case 'browseSeekers':
                await this.loadSeekersGrid('allSeekersGrid');
                break;
            case 'seeking':
                await this.loadSeekersGrid('seekersGrid');
                this.updateGroupDashboard();
                break;
        }
    }

    // ==================== TAB HANDLING ====================

    handleTabClick(e) {
        const tabBtn = e.target;
        const tabName = tabBtn.dataset.tab;
        const tabContainer = tabBtn.closest('.section-view');

        // Update tab buttons
        tabContainer.querySelectorAll('.tab-btn').forEach(btn => {
            btn.classList.remove('active');
        });
        tabBtn.classList.add('active');

        // Show/hide tab content based on section
        if (tabContainer.id === 'hasRoomSection') {
            this.showHasRoomTab(tabName);
        } else if (tabContainer.id === 'seekingSection') {
            this.showSeekingTab(tabName);
        }
    }

    showHasRoomTab(tabName) {
        document.getElementById('postRoomTab').classList.toggle('hidden', tabName !== 'postRoom');
        document.getElementById('myRoomsTab').classList.toggle('hidden', tabName !== 'myRooms');

        if (tabName === 'myRooms') {
            this.loadMyRooms();
        }
    }

    showSeekingTab(tabName) {
        document.getElementById('createProfileTab').classList.toggle('hidden', tabName !== 'createProfile');
        document.getElementById('browsePeopleTab').classList.toggle('hidden', tabName !== 'browsePeople');
        document.getElementById('myGroupTab').classList.toggle('hidden', tabName !== 'myGroup');

        if (tabName === 'browsePeople') {
            this.loadSeekersGrid('seekersGrid');
        } else if (tabName === 'myGroup') {
            this.updateGroupDashboard();
        }
    }

    // ==================== FILTER HANDLING ====================

    handleFilterClick(e) {
        const pill = e.target;
        const container = pill.closest('.section-view') || pill.closest('div');

        // Update active state
        container.querySelectorAll('.filter-pill').forEach(p => {
            p.classList.remove('active');
        });
        pill.classList.add('active');

        // Apply filter
        const filterValue = pill.textContent.trim();
        this.applyFilter(filterValue);
    }

    applyFilter(filterValue) {
        // Filter logic would go here
        console.log('Applying filter:', filterValue);
    }

    // ==================== DATA LOADING ====================

    async loadPreviewData() {
        await Promise.all([
            this.loadRoomsGrid('previewRoomsGrid', 3),
            this.loadSeekersGrid('previewSeekersGrid', 3)
        ]);
    }

    async loadRoomsGrid(containerId, limit = 12) {
        const container = document.getElementById(containerId);
        if (!container) return;

        // Get rooms from API or use mock data
        const rooms = await this.getRooms(limit);

        container.innerHTML = rooms.map(room => this.createRoomCard(room)).join('');
    }

    async loadSeekersGrid(containerId, limit = 12) {
        const container = document.getElementById(containerId);
        if (!container) return;

        // Get seekers from API or use mock data
        const seekers = await this.getSeekers(limit);

        container.innerHTML = seekers.map(seeker => this.createSeekerCard(seeker)).join('');
    }

    async getRooms(limit = 12) {
        // Try to get from API
        if (this.api) {
            try {
                const rooms = await this.api.getRoomPosts({ limit });
                if (rooms && rooms.length > 0) return rooms;
            } catch (e) {
                console.log('Using mock room data');
            }
        }

        // Return mock data
        return this.getMockRooms().slice(0, limit);
    }

    async getSeekers(limit = 12) {
        // Try to get from API
        if (this.api) {
            try {
                const seekers = await this.api.getSeekerProfiles({ limit });
                if (seekers && seekers.length > 0) return seekers;
            } catch (e) {
                console.log('Using mock seeker data');
            }
        }

        // Return mock data
        return this.getMockSeekers().slice(0, limit);
    }

    // ==================== CARD TEMPLATES ====================

    createRoomCard(room) {
        const photoUrl = room.room_photos?.[0]?.url || room.photos?.[0] || 'https://images.unsplash.com/photo-1522708323590-d24dbb6b0267?w=400&h=300&fit=crop';
        const verified = room.is_verified ? '<span class="verified-badge">Verified</span>' : '';
        const formattedDate = room.room_available_date ? this.formatDate(room.room_available_date) : 'Available Now';
        const roomTypeLabel = this.formatRoomType(room.room_type);

        return `
            <div class="card overflow-hidden cursor-pointer" onclick="roomPalApp.viewRoom('${room.id}')">
                <img src="${photoUrl}" alt="Room" class="room-image">
                <div class="p-4">
                    <div class="flex justify-between items-start mb-2">
                        <span class="text-xl font-bold text-indigo-600">$${room.room_rent}/mo</span>
                        ${verified}
                    </div>
                    <p class="text-gray-900 font-medium mb-1">${room.room_location || 'Location'}</p>
                    <div class="flex items-center gap-2 text-sm text-gray-500 mb-3">
                        <span>${roomTypeLabel}</span>
                        <span>-</span>
                        <span>${formattedDate}</span>
                    </div>
                    <p class="text-sm text-gray-600 line-clamp-2 mb-4">${room.room_description || 'Great room available!'}</p>
                    <button onclick="event.stopPropagation(); roomPalApp.openMessage('room', '${room.id}', '${room.name || 'Host'}')" class="btn-message w-full">
                        Message
                    </button>
                </div>
            </div>
        `;
    }

    createSeekerCard(seeker) {
        const avatarUrl = seeker.avatar_url || seeker.avatar?.photos?.[0]?.url || `https://ui-avatars.com/api/?name=${encodeURIComponent(seeker.name || 'User')}&background=6366f1&color=fff&size=160`;
        const verified = seeker.is_verified ? '<span class="verified-badge">Verified</span>' : '';
        const budgetRange = seeker.budget_min && seeker.budget_max ? `$${seeker.budget_min} - $${seeker.budget_max}` : 'Budget flexible';
        const moveDate = seeker.move_in_date ? this.formatDate(seeker.move_in_date) : 'Flexible';
        const areas = Array.isArray(seeker.preferred_areas) ? seeker.preferred_areas.join(', ') : (seeker.preferred_areas || 'Any area');
        const compatibility = seeker.compatibility_score ? `<span class="text-emerald-600 font-medium">${seeker.compatibility_score}% match</span>` : '';

        return `
            <div class="card p-6 text-center cursor-pointer" onclick="roomPalApp.viewSeeker('${seeker.id}')">
                <img src="${avatarUrl}" alt="${seeker.name}" class="seeker-avatar mx-auto mb-4">
                <div class="flex items-center justify-center gap-2 mb-2">
                    <h3 class="font-bold text-gray-900">${seeker.name || 'Anonymous'}</h3>
                    ${verified}
                </div>
                ${compatibility}
                <p class="text-indigo-600 font-medium mb-1">${budgetRange}</p>
                <p class="text-sm text-gray-500 mb-1">${areas}</p>
                <p class="text-sm text-gray-400 mb-4">Moving: ${moveDate}</p>
                <p class="text-sm text-gray-600 line-clamp-2 mb-4">${seeker.bio || 'Looking for roommates!'}</p>
                <div class="flex gap-2">
                    <button onclick="event.stopPropagation(); roomPalApp.inviteToGroup('${seeker.id}')" class="btn-secondary flex-1 text-sm py-2">
                        Invite
                    </button>
                    <button onclick="event.stopPropagation(); roomPalApp.openMessage('seeker', '${seeker.id}', '${seeker.name || 'User'}')" class="btn-message flex-1">
                        Connect
                    </button>
                </div>
            </div>
        `;
    }

    // ==================== FORM HANDLERS ====================

    async handleRoomFormSubmit(e) {
        e.preventDefault();

        const form = e.target;
        const formData = new FormData(form);

        const roomData = {
            user_type: 'has_spot',
            room_rent: parseInt(formData.get('room_rent')),
            room_location: formData.get('room_location'),
            room_type: formData.get('room_type'),
            room_available_date: formData.get('room_available_date'),
            room_description: formData.get('room_description'),
            room_photos: this.uploadedPhotos || []
        };

        // Show loading state
        const submitBtn = form.querySelector('button[type="submit"]');
        const originalText = submitBtn.textContent;
        submitBtn.textContent = 'Posting...';
        submitBtn.disabled = true;

        try {
            // Save to API or localStorage
            if (this.api && this.api.initialized) {
                await this.api.saveRoomPost(roomData);
            } else {
                // Save locally
                const rooms = JSON.parse(localStorage.getItem('myRooms') || '[]');
                roomData.id = 'room_' + Date.now();
                roomData.created_at = new Date().toISOString();
                rooms.push(roomData);
                localStorage.setItem('myRooms', JSON.stringify(rooms));
            }

            // Show success
            this.showToast('Room posted successfully!', 'success');
            form.reset();
            this.uploadedPhotos = [];
            document.getElementById('photoPreview').innerHTML = '';

        } catch (error) {
            console.error('Error posting room:', error);
            this.showToast('Failed to post room. Please try again.', 'error');
        } finally {
            submitBtn.textContent = originalText;
            submitBtn.disabled = false;
        }
    }

    async handleSeekerFormSubmit(e) {
        e.preventDefault();

        const form = e.target;
        const formData = new FormData(form);

        const areas = formData.get('preferred_areas').split(',').map(a => a.trim()).filter(a => a);

        const profileData = {
            user_type: 'seeking',
            budget_min: parseInt(formData.get('budget_min')),
            budget_max: parseInt(formData.get('budget_max')),
            preferred_areas: areas,
            move_in_date: formData.get('move_in_date'),
            bio: formData.get('bio'),
            avatar_url: this.uploadedAvatar || null,
            name: this.currentUser?.firstName || 'Anonymous'
        };

        // Show loading state
        const submitBtn = form.querySelector('button[type="submit"]');
        const originalText = submitBtn.textContent;
        submitBtn.textContent = 'Creating...';
        submitBtn.disabled = true;

        try {
            // Save to API or localStorage
            if (this.api && this.api.initialized) {
                await this.api.saveSeekerProfile(profileData);
            } else {
                // Save locally
                profileData.id = 'seeker_' + Date.now();
                profileData.created_at = new Date().toISOString();
                localStorage.setItem('roommateProfile', JSON.stringify(profileData));
                this.userProfile = profileData;
            }

            // Show success
            this.showToast('Profile created successfully!', 'success');

        } catch (error) {
            console.error('Error creating profile:', error);
            this.showToast('Failed to create profile. Please try again.', 'error');
        } finally {
            submitBtn.textContent = originalText;
            submitBtn.disabled = false;
        }
    }

    handleCompatibilitySubmit(e) {
        e.preventDefault();

        const form = e.target;
        const formData = new FormData(form);

        const compatibilityData = {
            sleepSchedule: formData.get('sleepSchedule'),
            cleanliness: formData.get('cleanliness'),
            socialLevel: formData.get('socialLevel'),
            smoking: formData.get('smoking'),
            pets: formData.get('pets')
        };

        // Save compatibility preferences
        const profile = this.userProfile || {};
        profile.compatibility_scores = compatibilityData;
        localStorage.setItem('roommateProfile', JSON.stringify(profile));
        this.userProfile = profile;

        // Close modal
        this.closeCompatibilityModal();
        this.showToast('Preferences saved!', 'success');
    }

    handleMessageSubmit(e) {
        e.preventDefault();

        const form = e.target;
        const message = form.querySelector('textarea[name="message"]').value;

        // In a real app, this would send through the API
        console.log('Sending message:', message, 'to:', this.messageRecipient);

        this.showToast('Message sent!', 'success');
        this.closeMessageModal();
        form.reset();
    }

    handlePhotoUpload(e, type) {
        const files = e.target.files;
        if (!files.length) return;

        if (type === 'room') {
            this.uploadedPhotos = this.uploadedPhotos || [];
            const previewContainer = document.getElementById('photoPreview');

            Array.from(files).forEach(file => {
                const reader = new FileReader();
                reader.onload = (event) => {
                    this.uploadedPhotos.push({ url: event.target.result, name: file.name });
                    previewContainer.innerHTML += `
                        <div class="relative">
                            <img src="${event.target.result}" class="w-20 h-20 object-cover rounded-lg">
                            <button type="button" onclick="roomPalApp.removePhoto(${this.uploadedPhotos.length - 1})"
                                class="absolute -top-2 -right-2 w-5 h-5 bg-red-500 text-white rounded-full text-xs">x</button>
                        </div>
                    `;
                };
                reader.readAsDataURL(file);
            });
        } else if (type === 'profile') {
            const file = files[0];
            const reader = new FileReader();
            reader.onload = (event) => {
                this.uploadedAvatar = event.target.result;
                document.getElementById('avatarPreview').innerHTML = `
                    <img src="${event.target.result}" class="w-24 h-24 rounded-full object-cover mx-auto">
                `;
            };
            reader.readAsDataURL(file);
        }
    }

    removePhoto(index) {
        this.uploadedPhotos.splice(index, 1);
        // Re-render preview
        const previewContainer = document.getElementById('photoPreview');
        previewContainer.innerHTML = this.uploadedPhotos.map((photo, i) => `
            <div class="relative">
                <img src="${photo.url}" class="w-20 h-20 object-cover rounded-lg">
                <button type="button" onclick="roomPalApp.removePhoto(${i})"
                    class="absolute -top-2 -right-2 w-5 h-5 bg-red-500 text-white rounded-full text-xs">x</button>
            </div>
        `).join('');
    }

    // ==================== GROUP MANAGEMENT ====================

    createGroup() {
        const groupName = prompt('Enter a name for your group:') || 'Our Roommate Group';

        this.userGroup = {
            id: 'group_' + Date.now(),
            name: groupName,
            creator_id: this.currentUser?.id || 'user_' + Date.now(),
            members: [{
                user_id: this.currentUser?.id || 'user_' + Date.now(),
                name: this.currentUser?.firstName || this.userProfile?.name || 'You',
                avatar: this.userProfile?.avatar_url,
                budget_min: this.userProfile?.budget_min || 800,
                budget_max: this.userProfile?.budget_max || 1500,
                role: 'creator',
                status: 'accepted'
            }],
            status: 'forming',
            created_at: new Date().toISOString()
        };

        localStorage.setItem('roommateGroup', JSON.stringify(this.userGroup));
        this.updateGroupDashboard();
        this.showToast('Group created!', 'success');
    }

    inviteToGroup(seekerId) {
        if (!this.userGroup) {
            if (confirm('You need to create a group first. Create one now?')) {
                this.createGroup();
            }
            return;
        }

        // In a real app, this would send an invitation through the API
        this.showToast('Invitation sent!', 'success');
    }

    updateGroupDashboard() {
        const noGroupView = document.getElementById('noGroupView');
        const groupDashboard = document.getElementById('groupDashboard');

        if (!noGroupView || !groupDashboard) return;

        if (this.userGroup) {
            noGroupView.classList.add('hidden');
            groupDashboard.classList.remove('hidden');

            // Update group name
            document.getElementById('groupName').textContent = this.userGroup.name;

            // Update members list
            const membersList = document.getElementById('groupMembersList');
            membersList.innerHTML = this.userGroup.members.map(member => `
                <div class="group-member">
                    <img src="${member.avatar || `https://ui-avatars.com/api/?name=${encodeURIComponent(member.name)}&background=6366f1&color=fff`}"
                         class="w-10 h-10 rounded-full">
                    <div class="flex-1">
                        <p class="font-medium text-gray-900">${member.name}</p>
                        <p class="text-sm text-gray-500">$${member.budget_min} - $${member.budget_max}/mo</p>
                    </div>
                    ${member.role === 'creator' ? '<span class="text-xs text-indigo-600">Creator</span>' : ''}
                </div>
            `).join('');

            // Calculate combined budget
            const totalMin = this.userGroup.members.reduce((sum, m) => sum + (m.budget_min || 0), 0);
            const totalMax = this.userGroup.members.reduce((sum, m) => sum + (m.budget_max || 0), 0);
            document.getElementById('combinedBudget').textContent = `$${totalMin.toLocaleString()} - $${totalMax.toLocaleString()}`;

        } else {
            noGroupView.classList.remove('hidden');
            groupDashboard.classList.add('hidden');
        }
    }

    // ==================== MY ROOMS ====================

    loadMyRooms() {
        const container = document.getElementById('myRoomsTab');
        if (!container) return;

        const myRooms = JSON.parse(localStorage.getItem('myRooms') || '[]');

        if (myRooms.length === 0) {
            container.innerHTML = `
                <div class="card p-8 text-center text-gray-500">
                    <p>You haven't posted any rooms yet.</p>
                </div>
            `;
        } else {
            container.innerHTML = `
                <div class="grid md:grid-cols-2 lg:grid-cols-3 gap-6">
                    ${myRooms.map(room => this.createRoomCard(room)).join('')}
                </div>
            `;
        }
    }

    // ==================== MODALS ====================

    openMessage(type, id, name) {
        this.messageRecipient = { type, id, name };

        const recipientEl = document.getElementById('messageRecipient');
        recipientEl.innerHTML = `
            <div class="w-10 h-10 bg-indigo-100 rounded-full flex items-center justify-center">
                <svg class="w-5 h-5 text-indigo-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z"/>
                </svg>
            </div>
            <div>
                <p class="font-medium text-gray-900">${name}</p>
                <p class="text-sm text-gray-500">${type === 'room' ? 'Room host' : 'Room seeker'}</p>
            </div>
        `;

        const modal = document.getElementById('messageModal');
        modal.classList.remove('hidden');
        modal.classList.add('flex');
    }

    closeMessageModal() {
        const modal = document.getElementById('messageModal');
        modal.classList.add('hidden');
        modal.classList.remove('flex');
    }

    showCompatibilityQuestions() {
        const modal = document.getElementById('compatibilityModal');
        modal.classList.remove('hidden');
        modal.classList.add('flex');
    }

    closeCompatibilityModal() {
        const modal = document.getElementById('compatibilityModal');
        modal.classList.add('hidden');
        modal.classList.remove('flex');
    }

    viewRoom(roomId) {
        console.log('Viewing room:', roomId);
        // In a real app, this would open a detailed room view
    }

    viewSeeker(seekerId) {
        console.log('Viewing seeker:', seekerId);
        // In a real app, this would open a detailed seeker profile
    }

    // ==================== UTILITIES ====================

    formatDate(dateStr) {
        if (!dateStr) return 'Flexible';
        const date = new Date(dateStr);
        const now = new Date();
        const diffDays = Math.ceil((date - now) / (1000 * 60 * 60 * 24));

        if (diffDays <= 0) return 'Available Now';
        if (diffDays <= 7) return 'This Week';
        if (diffDays <= 14) return 'Next Week';
        if (diffDays <= 30) return 'This Month';

        return date.toLocaleDateString('en-US', { month: 'short', day: 'numeric' });
    }

    formatRoomType(type) {
        const types = {
            'private': 'Private Room',
            'shared': 'Shared Room',
            'studio': 'Studio',
            'other': 'Other'
        };
        return types[type] || type || 'Room';
    }

    showToast(message, type = 'info') {
        // Create toast element
        const toast = document.createElement('div');
        toast.className = `fixed bottom-4 right-4 px-6 py-3 rounded-lg text-white z-50 transition-all transform translate-y-0 opacity-100 ${
            type === 'success' ? 'bg-emerald-500' :
            type === 'error' ? 'bg-red-500' : 'bg-indigo-500'
        }`;
        toast.textContent = message;

        document.body.appendChild(toast);

        // Remove after 3 seconds
        setTimeout(() => {
            toast.classList.add('opacity-0', 'translate-y-2');
            setTimeout(() => toast.remove(), 300);
        }, 3000);
    }

    // ==================== MOCK DATA ====================

    getMockRooms() {
        return [
            {
                id: 'room_1',
                room_rent: 1200,
                room_location: 'Downtown Seattle, WA',
                room_type: 'private',
                room_available_date: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000).toISOString(),
                room_description: 'Bright, spacious private room in a modern apartment. Great natural light, in-unit laundry, and close to public transit.',
                room_photos: [{ url: 'https://images.unsplash.com/photo-1522708323590-d24dbb6b0267?w=400&h=300&fit=crop' }],
                is_verified: true,
                name: 'Alex'
            },
            {
                id: 'room_2',
                room_rent: 950,
                room_location: 'Capitol Hill, Seattle',
                room_type: 'private',
                room_available_date: new Date(Date.now() + 14 * 24 * 60 * 60 * 1000).toISOString(),
                room_description: 'Cozy room in a friendly household. Walking distance to restaurants and bars. Pet-friendly!',
                room_photos: [{ url: 'https://images.unsplash.com/photo-1502672260266-1c1ef2d93688?w=400&h=300&fit=crop' }],
                is_verified: true,
                name: 'Jordan'
            },
            {
                id: 'room_3',
                room_rent: 800,
                room_location: 'University District, Seattle',
                room_type: 'shared',
                room_available_date: new Date().toISOString(),
                room_description: 'Affordable shared room near UW campus. Great for students! Utilities included.',
                room_photos: [{ url: 'https://images.unsplash.com/photo-1493809842364-78817add7ffb?w=400&h=300&fit=crop' }],
                is_verified: false,
                name: 'Taylor'
            },
            {
                id: 'room_4',
                room_rent: 1500,
                room_location: 'Ballard, Seattle',
                room_type: 'studio',
                room_available_date: new Date(Date.now() + 30 * 24 * 60 * 60 * 1000).toISOString(),
                room_description: 'Beautiful studio apartment with modern amenities. Quiet neighborhood with great cafes nearby.',
                room_photos: [{ url: 'https://images.unsplash.com/photo-1536376072261-38c75010e6c9?w=400&h=300&fit=crop' }],
                is_verified: true,
                name: 'Morgan'
            },
            {
                id: 'room_5',
                room_rent: 1100,
                room_location: 'Fremont, Seattle',
                room_type: 'private',
                room_available_date: new Date(Date.now() + 21 * 24 * 60 * 60 * 1000).toISOString(),
                room_description: 'Charming room in a vintage home. Creative neighborhood with art galleries and unique shops.',
                room_photos: [{ url: 'https://images.unsplash.com/photo-1484154218962-a197022b5858?w=400&h=300&fit=crop' }],
                is_verified: false,
                name: 'Casey'
            },
            {
                id: 'room_6',
                room_rent: 1350,
                room_location: 'South Lake Union, Seattle',
                room_type: 'private',
                room_available_date: new Date(Date.now() + 10 * 24 * 60 * 60 * 1000).toISOString(),
                room_description: 'Modern high-rise apartment with amazing city views. Gym and rooftop access included.',
                room_photos: [{ url: 'https://images.unsplash.com/photo-1560448204-e02f11c3d0e2?w=400&h=300&fit=crop' }],
                is_verified: true,
                name: 'Jamie'
            }
        ];
    }

    getMockSeekers() {
        return [
            {
                id: 'seeker_1',
                name: 'Sarah',
                budget_min: 800,
                budget_max: 1200,
                preferred_areas: ['Capitol Hill', 'Downtown', 'Fremont'],
                move_in_date: new Date(Date.now() + 14 * 24 * 60 * 60 * 1000).toISOString(),
                bio: 'Software developer looking for a quiet, clean household. Love cooking and weekend hikes!',
                avatar_url: 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=200&h=200&fit=crop&crop=face',
                is_verified: true,
                compatibility_score: 92
            },
            {
                id: 'seeker_2',
                name: 'Marcus',
                budget_min: 900,
                budget_max: 1400,
                preferred_areas: ['Ballard', 'Fremont', 'Wallingford'],
                move_in_date: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000).toISOString(),
                bio: 'Graduate student at UW. Quiet, respectful, and enjoy good conversations. Night owl but respectful of quiet hours.',
                avatar_url: 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=200&h=200&fit=crop&crop=face',
                is_verified: true,
                compatibility_score: 87
            },
            {
                id: 'seeker_3',
                name: 'Emily',
                budget_min: 700,
                budget_max: 1000,
                preferred_areas: ['University District', 'Ravenna'],
                move_in_date: new Date(Date.now() + 30 * 24 * 60 * 60 * 1000).toISOString(),
                bio: 'Medical student looking for roommates! Clean and organized. Usually studying but love movie nights.',
                avatar_url: 'https://images.unsplash.com/photo-1438761681033-6461ffad8d80?w=200&h=200&fit=crop&crop=face',
                is_verified: false,
                compatibility_score: 78
            },
            {
                id: 'seeker_4',
                name: 'David',
                budget_min: 1000,
                budget_max: 1500,
                preferred_areas: ['Downtown', 'South Lake Union', 'Capitol Hill'],
                move_in_date: new Date().toISOString(),
                bio: 'Remote worker in tech. Looking for a social household with professionals. Love board games and cooking!',
                avatar_url: 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=200&h=200&fit=crop&crop=face',
                is_verified: true,
                compatibility_score: 85
            },
            {
                id: 'seeker_5',
                name: 'Lisa',
                budget_min: 850,
                budget_max: 1200,
                preferred_areas: ['Queen Anne', 'Magnolia', 'Ballard'],
                move_in_date: new Date(Date.now() + 21 * 24 * 60 * 60 * 1000).toISOString(),
                bio: 'Artist and part-time barista. Creative, easy-going, and love plants. Looking for a chill environment.',
                avatar_url: 'https://images.unsplash.com/photo-1544005313-94ddf0286df2?w=200&h=200&fit=crop&crop=face',
                is_verified: false,
                compatibility_score: 81
            },
            {
                id: 'seeker_6',
                name: 'Kevin',
                budget_min: 750,
                budget_max: 1100,
                preferred_areas: ['Beacon Hill', 'Columbia City', 'Georgetown'],
                move_in_date: new Date(Date.now() + 45 * 24 * 60 * 60 * 1000).toISOString(),
                bio: 'Teacher at local high school. Active and social but respect quiet time. Love outdoor activities!',
                avatar_url: 'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=200&h=200&fit=crop&crop=face',
                is_verified: true,
                compatibility_score: 89
            }
        ];
    }
}

// Global functions for onclick handlers
function showSection(section) {
    if (window.roomPalApp) {
        window.roomPalApp.showSection(section);
    }
}

function showCompatibilityQuestions() {
    if (window.roomPalApp) {
        window.roomPalApp.showCompatibilityQuestions();
    }
}

function closeCompatibilityModal() {
    if (window.roomPalApp) {
        window.roomPalApp.closeCompatibilityModal();
    }
}

function closeMessageModal() {
    if (window.roomPalApp) {
        window.roomPalApp.closeMessageModal();
    }
}

function createGroup() {
    if (window.roomPalApp) {
        window.roomPalApp.createGroup();
    }
}

// Initialize app when DOM is ready
document.addEventListener('DOMContentLoaded', () => {
    window.roomPalApp = new RoomPalApp();
});
