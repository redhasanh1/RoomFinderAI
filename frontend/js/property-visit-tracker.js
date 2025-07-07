// Property Visit Tracker - Photo sharing and note-taking functionality
class PropertyVisitTracker {
    constructor(supabase) {
        this.supabase = supabase;
        this.currentVisit = null;
        this.photos = [];
        this.notes = [];
        this.voiceNotes = [];
        this.mediaRecorder = null;
        this.audioChunks = [];
    }

    // Initialize visit tracking for a property
    async startVisit(propertyId, propertyTitle) {
        console.log('📍 Starting property visit:', propertyTitle);
        
        const currentUser = JSON.parse(localStorage.getItem('currentUser'));
        if (!currentUser) {
            alert('Please login to track property visits');
            return false;
        }
        
        this.currentVisit = {
            id: `visit_${Date.now()}`,
            property_id: propertyId,
            property_title: propertyTitle,
            user_email: currentUser.email,
            start_time: new Date().toISOString(),
            end_time: null,
            photos: [],
            notes: [],
            voice_notes: [],
            location: await this.getCurrentLocation(),
            created_at: new Date().toISOString()
        };
        
        // Save to local storage for offline support
        this.saveVisitLocally();
        
        // Show visit UI
        this.showVisitUI();
        
        return true;
    }

    // Get current location
    async getCurrentLocation() {
        try {
            const position = await new Promise((resolve, reject) => {
                navigator.geolocation.getCurrentPosition(resolve, reject, {
                    enableHighAccuracy: true,
                    timeout: 5000
                });
            });
            
            return {
                latitude: position.coords.latitude,
                longitude: position.coords.longitude,
                accuracy: position.coords.accuracy
            };
        } catch (error) {
            console.error('Failed to get location:', error);
            return null;
        }
    }

    // Show visit tracking UI
    showVisitUI() {
        const visitModal = document.createElement('div');
        visitModal.id = 'property-visit-modal';
        visitModal.className = 'fixed inset-0 bg-black bg-opacity-50 z-50 flex items-end';
        visitModal.innerHTML = `
            <div class="bg-white w-full rounded-t-2xl max-h-[80vh] overflow-hidden animate-slide-up">
                <div class="sticky top-0 bg-white border-b border-gray-200 p-4">
                    <div class="flex items-center justify-between">
                        <div>
                            <h3 class="text-lg font-semibold">Property Visit</h3>
                            <p class="text-sm text-gray-600">${this.currentVisit.property_title}</p>
                        </div>
                        <button class="close-visit text-gray-500 hover:text-gray-700 text-2xl" onclick="propertyVisitTracker.endVisit()">
                            ×
                        </button>
                    </div>
                </div>
                
                <div class="p-4 space-y-4 overflow-y-auto max-h-[60vh]">
                    <!-- Quick Actions -->
                    <div class="grid grid-cols-3 gap-3">
                        <button class="action-btn take-photo bg-blue-100 text-blue-700 p-4 rounded-lg text-center hover:bg-blue-200 transition">
                            <svg class="w-6 h-6 mx-auto mb-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 9a2 2 0 012-2h.93a2 2 0 001.664-.89l.812-1.22A2 2 0 0110.07 4h3.86a2 2 0 011.664.89l.812 1.22A2 2 0 0018.07 7H19a2 2 0 012 2v9a2 2 0 01-2 2H5a2 2 0 01-2-2V9z"></path>
                                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 13a3 3 0 11-6 0 3 3 0 016 0z"></path>
                            </svg>
                            <span class="text-xs">Take Photo</span>
                        </button>
                        
                        <button class="action-btn add-note bg-green-100 text-green-700 p-4 rounded-lg text-center hover:bg-green-200 transition">
                            <svg class="w-6 h-6 mx-auto mb-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z"></path>
                            </svg>
                            <span class="text-xs">Add Note</span>
                        </button>
                        
                        <button class="action-btn record-voice bg-purple-100 text-purple-700 p-4 rounded-lg text-center hover:bg-purple-200 transition">
                            <svg class="w-6 h-6 mx-auto mb-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 11a7 7 0 01-7 7m0 0a7 7 0 01-7-7m7 7v4m0 0H8m4 0h4m-4-8a3 3 0 01-3-3V5a3 3 0 116 0v6a3 3 0 01-3 3z"></path>
                            </svg>
                            <span class="text-xs">Voice Note</span>
                        </button>
                    </div>
                    
                    <!-- Photos Section -->
                    <div class="photos-section">
                        <h4 class="font-medium mb-2">Photos</h4>
                        <div id="visit-photos" class="grid grid-cols-3 gap-2">
                            <!-- Photos will be added here -->
                        </div>
                    </div>
                    
                    <!-- Notes Section -->
                    <div class="notes-section">
                        <h4 class="font-medium mb-2">Notes</h4>
                        <div id="visit-notes" class="space-y-2">
                            <!-- Notes will be added here -->
                        </div>
                    </div>
                    
                    <!-- Voice Notes Section -->
                    <div class="voice-notes-section">
                        <h4 class="font-medium mb-2">Voice Notes</h4>
                        <div id="visit-voice-notes" class="space-y-2">
                            <!-- Voice notes will be added here -->
                        </div>
                    </div>
                </div>
                
                <div class="sticky bottom-0 bg-white border-t border-gray-200 p-4">
                    <button class="w-full bg-blue-600 text-white py-3 rounded-lg hover:bg-blue-700 transition font-medium" onclick="propertyVisitTracker.saveVisit()">
                        Save Visit Details
                    </button>
                </div>
            </div>
        `;
        
        document.body.appendChild(visitModal);
        
        // Add event listeners
        this.setupEventListeners();
    }

    // Setup event listeners
    setupEventListeners() {
        // Photo capture
        document.querySelector('.take-photo').addEventListener('click', () => this.capturePhoto());
        
        // Note adding
        document.querySelector('.add-note').addEventListener('click', () => this.addNote());
        
        // Voice recording
        document.querySelector('.record-voice').addEventListener('click', () => this.toggleVoiceRecording());
        
        // Close modal on backdrop click
        document.getElementById('property-visit-modal').addEventListener('click', (e) => {
            if (e.target.id === 'property-visit-modal') {
                this.endVisit();
            }
        });
    }

    // Capture photo using device camera
    async capturePhoto() {
        const input = document.createElement('input');
        input.type = 'file';
        input.accept = 'image/*';
        input.capture = 'environment'; // Use rear camera
        
        input.addEventListener('change', async (e) => {
            const file = e.target.files[0];
            if (file) {
                // Compress and process the image
                const compressedImage = await this.compressImage(file);
                
                const photo = {
                    id: `photo_${Date.now()}`,
                    file: compressedImage,
                    timestamp: new Date().toISOString(),
                    location: await this.getCurrentLocation(),
                    notes: ''
                };
                
                this.photos.push(photo);
                this.displayPhoto(photo);
                this.saveVisitLocally();
            }
        });
        
        input.click();
    }

    // Compress image for efficient storage
    async compressImage(file) {
        return new Promise((resolve) => {
            const reader = new FileReader();
            reader.onload = (e) => {
                const img = new Image();
                img.onload = () => {
                    const canvas = document.createElement('canvas');
                    const ctx = canvas.getContext('2d');
                    
                    // Calculate new dimensions (max 1200px)
                    let width = img.width;
                    let height = img.height;
                    const maxSize = 1200;
                    
                    if (width > height && width > maxSize) {
                        height = (height / width) * maxSize;
                        width = maxSize;
                    } else if (height > maxSize) {
                        width = (width / height) * maxSize;
                        height = maxSize;
                    }
                    
                    canvas.width = width;
                    canvas.height = height;
                    
                    // Draw and compress
                    ctx.drawImage(img, 0, 0, width, height);
                    
                    canvas.toBlob((blob) => {
                        resolve({
                            blob: blob,
                            dataUrl: canvas.toDataURL('image/jpeg', 0.8),
                            name: file.name,
                            size: blob.size,
                            type: 'image/jpeg'
                        });
                    }, 'image/jpeg', 0.8);
                };
                img.src = e.target.result;
            };
            reader.readAsDataURL(file);
        });
    }

    // Display photo in UI
    displayPhoto(photo) {
        const photosContainer = document.getElementById('visit-photos');
        const photoElement = document.createElement('div');
        photoElement.className = 'relative group';
        photoElement.innerHTML = `
            <img src="${photo.file.dataUrl}" alt="Property photo" class="w-full h-24 object-cover rounded-lg">
            <button class="absolute top-1 right-1 bg-red-500 text-white rounded-full p-1 opacity-0 group-hover:opacity-100 transition" onclick="propertyVisitTracker.removePhoto('${photo.id}')">
                <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"></path>
                </svg>
            </button>
        `;
        photosContainer.appendChild(photoElement);
    }

    // Add text note
    addNote() {
        const noteModal = document.createElement('div');
        noteModal.className = 'fixed inset-0 bg-black bg-opacity-50 z-[60] flex items-center justify-center p-4';
        noteModal.innerHTML = `
            <div class="bg-white rounded-lg p-6 max-w-md w-full">
                <h3 class="text-lg font-semibold mb-4">Add Note</h3>
                <textarea id="note-input" class="w-full border border-gray-300 rounded-lg p-3 h-32 resize-none" placeholder="Enter your note about this property..."></textarea>
                <div class="flex justify-end gap-3 mt-4">
                    <button class="px-4 py-2 text-gray-600 hover:text-gray-800" onclick="this.closest('.fixed').remove()">
                        Cancel
                    </button>
                    <button class="px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700" onclick="propertyVisitTracker.saveNote(this)">
                        Save Note
                    </button>
                </div>
            </div>
        `;
        document.body.appendChild(noteModal);
        document.getElementById('note-input').focus();
    }

    // Save note
    saveNote(button) {
        const noteInput = document.getElementById('note-input');
        const noteText = noteInput.value.trim();
        
        if (noteText) {
            const note = {
                id: `note_${Date.now()}`,
                text: noteText,
                timestamp: new Date().toISOString()
            };
            
            this.notes.push(note);
            this.displayNote(note);
            this.saveVisitLocally();
        }
        
        button.closest('.fixed').remove();
    }

    // Display note in UI
    displayNote(note) {
        const notesContainer = document.getElementById('visit-notes');
        const noteElement = document.createElement('div');
        noteElement.className = 'bg-gray-50 p-3 rounded-lg relative group';
        noteElement.innerHTML = `
            <p class="text-sm text-gray-700">${note.text}</p>
            <p class="text-xs text-gray-500 mt-1">${new Date(note.timestamp).toLocaleTimeString()}</p>
            <button class="absolute top-2 right-2 text-red-500 opacity-0 group-hover:opacity-100 transition" onclick="propertyVisitTracker.removeNote('${note.id}')">
                <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"></path>
                </svg>
            </button>
        `;
        notesContainer.appendChild(noteElement);
    }

    // Toggle voice recording
    async toggleVoiceRecording() {
        const button = document.querySelector('.record-voice');
        
        if (!this.mediaRecorder || this.mediaRecorder.state === 'inactive') {
            // Start recording
            try {
                const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
                this.mediaRecorder = new MediaRecorder(stream);
                this.audioChunks = [];
                
                this.mediaRecorder.ondataavailable = (event) => {
                    this.audioChunks.push(event.data);
                };
                
                this.mediaRecorder.onstop = () => {
                    const audioBlob = new Blob(this.audioChunks, { type: 'audio/webm' });
                    this.saveVoiceNote(audioBlob);
                    stream.getTracks().forEach(track => track.stop());
                };
                
                this.mediaRecorder.start();
                
                // Update UI
                button.classList.add('bg-red-100', 'text-red-700', 'animate-pulse');
                button.classList.remove('bg-purple-100', 'text-purple-700');
                button.querySelector('span').textContent = 'Recording...';
                
            } catch (error) {
                console.error('Failed to start recording:', error);
                alert('Unable to access microphone. Please check permissions.');
            }
        } else {
            // Stop recording
            this.mediaRecorder.stop();
            
            // Update UI
            button.classList.remove('bg-red-100', 'text-red-700', 'animate-pulse');
            button.classList.add('bg-purple-100', 'text-purple-700');
            button.querySelector('span').textContent = 'Voice Note';
        }
    }

    // Save voice note
    saveVoiceNote(audioBlob) {
        const voiceNote = {
            id: `voice_${Date.now()}`,
            blob: audioBlob,
            url: URL.createObjectURL(audioBlob),
            duration: 0, // Could calculate this
            timestamp: new Date().toISOString()
        };
        
        this.voiceNotes.push(voiceNote);
        this.displayVoiceNote(voiceNote);
        this.saveVisitLocally();
    }

    // Display voice note in UI
    displayVoiceNote(voiceNote) {
        const voiceNotesContainer = document.getElementById('visit-voice-notes');
        const voiceNoteElement = document.createElement('div');
        voiceNoteElement.className = 'bg-purple-50 p-3 rounded-lg flex items-center justify-between group';
        voiceNoteElement.innerHTML = `
            <div class="flex items-center gap-3">
                <button class="play-pause bg-purple-600 text-white p-2 rounded-full hover:bg-purple-700" onclick="propertyVisitTracker.playVoiceNote('${voiceNote.id}')">
                    <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M14.752 11.168l-3.197-2.132A1 1 0 0010 9.87v4.263a1 1 0 001.555.832l3.197-2.132a1 1 0 000-1.664z"></path>
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 12a9 9 0 11-18 0 9 9 0 0118 0z"></path>
                    </svg>
                </button>
                <div>
                    <p class="text-sm font-medium">Voice Note</p>
                    <p class="text-xs text-gray-500">${new Date(voiceNote.timestamp).toLocaleTimeString()}</p>
                </div>
            </div>
            <button class="text-red-500 opacity-0 group-hover:opacity-100 transition" onclick="propertyVisitTracker.removeVoiceNote('${voiceNote.id}')">
                <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"></path>
                </svg>
            </button>
        `;
        voiceNotesContainer.appendChild(voiceNoteElement);
    }

    // Play voice note
    playVoiceNote(id) {
        const voiceNote = this.voiceNotes.find(vn => vn.id === id);
        if (voiceNote) {
            const audio = new Audio(voiceNote.url);
            audio.play();
        }
    }

    // Remove items
    removePhoto(id) {
        this.photos = this.photos.filter(p => p.id !== id);
        this.updatePhotosDisplay();
        this.saveVisitLocally();
    }

    removeNote(id) {
        this.notes = this.notes.filter(n => n.id !== id);
        this.updateNotesDisplay();
        this.saveVisitLocally();
    }

    removeVoiceNote(id) {
        this.voiceNotes = this.voiceNotes.filter(vn => vn.id !== id);
        this.updateVoiceNotesDisplay();
        this.saveVisitLocally();
    }

    // Update displays
    updatePhotosDisplay() {
        const container = document.getElementById('visit-photos');
        container.innerHTML = '';
        this.photos.forEach(photo => this.displayPhoto(photo));
    }

    updateNotesDisplay() {
        const container = document.getElementById('visit-notes');
        container.innerHTML = '';
        this.notes.forEach(note => this.displayNote(note));
    }

    updateVoiceNotesDisplay() {
        const container = document.getElementById('visit-voice-notes');
        container.innerHTML = '';
        this.voiceNotes.forEach(voiceNote => this.displayVoiceNote(voiceNote));
    }

    // Save visit locally
    saveVisitLocally() {
        if (this.currentVisit) {
            this.currentVisit.photos = this.photos;
            this.currentVisit.notes = this.notes;
            this.currentVisit.voice_notes = this.voiceNotes;
            
            localStorage.setItem(`visit_${this.currentVisit.id}`, JSON.stringify(this.currentVisit));
        }
    }

    // Save visit to database
    async saveVisit() {
        if (!this.currentVisit) return;
        
        this.currentVisit.end_time = new Date().toISOString();
        
        try {
            // Upload photos to Supabase storage
            const uploadedPhotos = await this.uploadPhotos();
            
            // Upload voice notes
            const uploadedVoiceNotes = await this.uploadVoiceNotes();
            
            // Save visit record
            const { data, error } = await this.supabase
                .from('property_visits')
                .insert({
                    property_id: this.currentVisit.property_id,
                    user_email: this.currentVisit.user_email,
                    start_time: this.currentVisit.start_time,
                    end_time: this.currentVisit.end_time,
                    photos: uploadedPhotos,
                    notes: this.notes,
                    voice_notes: uploadedVoiceNotes,
                    location: this.currentVisit.location
                });
            
            if (error) throw error;
            
            console.log('✅ Visit saved successfully');
            alert('Property visit saved successfully!');
            
            // Clear local storage
            localStorage.removeItem(`visit_${this.currentVisit.id}`);
            
            // Close modal
            this.endVisit();
            
        } catch (error) {
            console.error('Failed to save visit:', error);
            alert('Failed to save visit. It will be saved locally and synced later.');
        }
    }

    // Upload photos to storage
    async uploadPhotos() {
        const uploadedPhotos = [];
        
        for (const photo of this.photos) {
            try {
                const fileName = `visits/${this.currentVisit.property_id}/${photo.id}.jpg`;
                
                const { data, error } = await this.supabase.storage
                    .from('property-photos')
                    .upload(fileName, photo.file.blob);
                
                if (error) throw error;
                
                const { publicURL } = this.supabase.storage
                    .from('property-photos')
                    .getPublicUrl(fileName);
                
                uploadedPhotos.push({
                    id: photo.id,
                    url: publicURL,
                    timestamp: photo.timestamp,
                    location: photo.location,
                    notes: photo.notes
                });
            } catch (error) {
                console.error('Failed to upload photo:', error);
            }
        }
        
        return uploadedPhotos;
    }

    // Upload voice notes
    async uploadVoiceNotes() {
        const uploadedVoiceNotes = [];
        
        for (const voiceNote of this.voiceNotes) {
            try {
                const fileName = `visits/${this.currentVisit.property_id}/${voiceNote.id}.webm`;
                
                const { data, error } = await this.supabase.storage
                    .from('voice-notes')
                    .upload(fileName, voiceNote.blob);
                
                if (error) throw error;
                
                const { publicURL } = this.supabase.storage
                    .from('voice-notes')
                    .getPublicUrl(fileName);
                
                uploadedVoiceNotes.push({
                    id: voiceNote.id,
                    url: publicURL,
                    duration: voiceNote.duration,
                    timestamp: voiceNote.timestamp
                });
            } catch (error) {
                console.error('Failed to upload voice note:', error);
            }
        }
        
        return uploadedVoiceNotes;
    }

    // End visit
    endVisit() {
        const modal = document.getElementById('property-visit-modal');
        if (modal) {
            modal.remove();
        }
        
        // Stop any ongoing recordings
        if (this.mediaRecorder && this.mediaRecorder.state !== 'inactive') {
            this.mediaRecorder.stop();
        }
        
        // Reset state
        this.currentVisit = null;
        this.photos = [];
        this.notes = [];
        this.voiceNotes = [];
    }

    // Load previous visits
    async loadVisits(propertyId) {
        try {
            const { data, error } = await this.supabase
                .from('property_visits')
                .select('*')
                .eq('property_id', propertyId)
                .order('created_at', { ascending: false });
            
            if (error) throw error;
            
            return data || [];
        } catch (error) {
            console.error('Failed to load visits:', error);
            return [];
        }
    }
}

// Initialize globally
window.propertyVisitTracker = new PropertyVisitTracker(window.supabase);