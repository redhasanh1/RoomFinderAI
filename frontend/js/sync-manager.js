// Cross-Device Synchronization Manager
class SyncManager {
    constructor(supabase) {
        this.supabase = supabase;
        this.currentUser = null;
        this.syncInterval = null;
        this.lastSyncTime = null;
        this.conflictResolver = null;
        
        // Data types to sync
        this.syncTypes = {
            PREFERENCES: 'preferences',
            SAVED_SEARCHES: 'saved_searches',
            SAVED_PROPERTIES: 'saved_properties',
            SEARCH_HISTORY: 'search_history',
            VISIT_HISTORY: 'visit_history',
            NOTIFICATION_SETTINGS: 'notification_settings'
        };
        
        console.log('🔄 Sync Manager initialized');
    }

    // Initialize sync for authenticated user
    async init(user) {
        this.currentUser = user;
        this.lastSyncTime = this.getLastSyncTime();
        
        try {
            // Initial sync from server
            await this.syncFromServer();
            
            // Set up real-time sync
            this.setupRealTimeSync();
            
            // Start periodic sync
            this.startPeriodicSync();
            
            console.log('✅ Cross-device sync initialized for user:', user.email);
            return true;
        } catch (error) {
            console.error('❌ Failed to initialize sync:', error);
            return false;
        }
    }

    // Stop sync (on logout)
    stop() {
        if (this.syncInterval) {
            clearInterval(this.syncInterval);
            this.syncInterval = null;
        }
        
        // Unsubscribe from real-time updates
        if (this.realtimeChannel) {
            this.realtimeChannel.unsubscribe();
        }
        
        this.currentUser = null;
        console.log('⏹️ Cross-device sync stopped');
    }

    // Sync all data from server to local
    async syncFromServer() {
        if (!this.currentUser) return;
        
        console.log('📥 Syncing data from server...');
        
        try {
            const { data, error } = await this.supabase
                .from('user_sync_data')
                .select('*')
                .eq('user_email', this.currentUser.email)
                .gt('updated_at', this.lastSyncTime || '1970-01-01');
            
            if (error) throw error;
            
            if (data && data.length > 0) {
                for (const syncRecord of data) {
                    await this.applyServerData(syncRecord);
                }
                
                console.log(`📥 Synced ${data.length} records from server`);
                this.updateLastSyncTime();
            }
            
        } catch (error) {
            console.error('Failed to sync from server:', error);
            throw error;
        }
    }

    // Sync local data to server
    async syncToServer(dataType, data, force = false) {
        if (!this.currentUser) return;
        
        try {
            const syncRecord = {
                user_email: this.currentUser.email,
                data_type: dataType,
                data: data,
                device_id: this.getDeviceId(),
                updated_at: new Date().toISOString()
            };
            
            // Check for conflicts if not forcing
            if (!force) {
                const conflict = await this.checkForConflicts(dataType, syncRecord.updated_at);
                if (conflict) {
                    const resolved = await this.resolveConflict(conflict, syncRecord);
                    if (!resolved) {
                        console.log('🔄 Sync cancelled due to unresolved conflict');
                        return false;
                    }
                }
            }
            
            const { error } = await this.supabase
                .from('user_sync_data')
                .upsert(syncRecord, {
                    onConflict: 'user_email,data_type'
                });
            
            if (error) throw error;
            
            console.log('📤 Synced to server:', dataType);
            return true;
            
        } catch (error) {
            console.error('Failed to sync to server:', error);
            // Store for retry later
            this.storeFailedSync(dataType, data);
            return false;
        }
    }

    // Apply server data to local storage
    async applyServerData(syncRecord) {
        const { data_type, data, device_id, updated_at } = syncRecord;
        
        // Don't apply data from the same device
        if (device_id === this.getDeviceId()) {
            return;
        }
        
        // Check if local data is newer
        const localTimestamp = this.getLocalDataTimestamp(data_type);
        if (localTimestamp && new Date(localTimestamp) > new Date(updated_at)) {
            console.log('📱 Local data is newer, skipping:', data_type);
            return;
        }
        
        switch (data_type) {
            case this.syncTypes.PREFERENCES:
                localStorage.setItem('userPreferences', JSON.stringify(data));
                break;
                
            case this.syncTypes.SAVED_SEARCHES:
                localStorage.setItem('savedSearches', JSON.stringify(data));
                break;
                
            case this.syncTypes.SAVED_PROPERTIES:
                localStorage.setItem('savedProperties', JSON.stringify(data));
                break;
                
            case this.syncTypes.SEARCH_HISTORY:
                localStorage.setItem('searchHistory', JSON.stringify(data));
                break;
                
            case this.syncTypes.VISIT_HISTORY:
                localStorage.setItem('visitHistory', JSON.stringify(data));
                break;
                
            case this.syncTypes.NOTIFICATION_SETTINGS:
                localStorage.setItem('notificationPreferences', JSON.stringify(data));
                if (window.notificationManager) {
                    window.notificationManager.preferences = data;
                }
                break;
        }
        
        // Update local timestamp
        this.setLocalDataTimestamp(data_type, updated_at);
        
        console.log('📱 Applied server data:', data_type);
        
        // Trigger UI updates
        this.triggerUIUpdate(data_type);
    }

    // Set up real-time synchronization
    setupRealTimeSync() {
        this.realtimeChannel = this.supabase
            .channel(`user_sync_${this.currentUser.email}`)
            .on('postgres_changes', {
                event: '*',
                schema: 'public',
                table: 'user_sync_data',
                filter: `user_email=eq.${this.currentUser.email}`
            }, (payload) => {
                console.log('🔄 Real-time sync update:', payload);
                
                if (payload.eventType === 'INSERT' || payload.eventType === 'UPDATE') {
                    // Don't sync our own changes
                    if (payload.new.device_id !== this.getDeviceId()) {
                        this.applyServerData(payload.new);
                    }
                }
            })
            .subscribe();
    }

    // Start periodic sync
    startPeriodicSync() {
        // Sync every 5 minutes
        this.syncInterval = setInterval(() => {
            this.performPeriodicSync();
        }, 5 * 60 * 1000);
        
        // Also sync when app becomes visible
        document.addEventListener('visibilitychange', () => {
            if (!document.hidden) {
                this.performPeriodicSync();
            }
        });
        
        // Sync when online
        window.addEventListener('online', () => {
            this.performPeriodicSync();
        });
    }

    // Perform periodic sync
    async performPeriodicSync() {
        if (!navigator.onLine || !this.currentUser) return;
        
        try {
            // Sync from server first
            await this.syncFromServer();
            
            // Then sync local changes to server
            await this.syncLocalChangesToServer();
            
        } catch (error) {
            console.error('Periodic sync failed:', error);
        }
    }

    // Sync local changes to server
    async syncLocalChangesToServer() {
        const localChanges = this.getLocalChanges();
        
        for (const change of localChanges) {
            await this.syncToServer(change.type, change.data);
        }
        
        // Clear local changes after successful sync
        this.clearLocalChanges();
    }

    // Check for sync conflicts
    async checkForConflicts(dataType, localTimestamp) {
        try {
            const { data, error } = await this.supabase
                .from('user_sync_data')
                .select('updated_at, device_id')
                .eq('user_email', this.currentUser.email)
                .eq('data_type', dataType)
                .single();
            
            if (error && error.code !== 'PGRST116') throw error;
            
            if (data && data.device_id !== this.getDeviceId()) {
                const serverTime = new Date(data.updated_at);
                const localTime = new Date(localTimestamp);
                
                if (serverTime > localTime) {
                    return {
                        serverTimestamp: data.updated_at,
                        localTimestamp: localTimestamp,
                        dataType: dataType
                    };
                }
            }
            
            return null;
        } catch (error) {
            console.error('Failed to check conflicts:', error);
            return null;
        }
    }

    // Resolve sync conflicts
    async resolveConflict(conflict, localData) {
        // For now, use a simple strategy: server wins for settings, merge for arrays
        const { dataType } = conflict;
        
        if (this.conflictResolver) {
            return await this.conflictResolver(conflict, localData);
        }
        
        // Default resolution strategy
        switch (dataType) {
            case this.syncTypes.SAVED_SEARCHES:
            case this.syncTypes.SAVED_PROPERTIES:
            case this.syncTypes.SEARCH_HISTORY:
                // Merge arrays and remove duplicates
                return await this.mergeArrayData(dataType, localData.data);
                
            default:
                // Server wins for preferences and settings
                console.log('🔄 Server wins conflict resolution for:', dataType);
                return true;
        }
    }

    // Merge array data (for searches, properties, etc.)
    async mergeArrayData(dataType, localArray) {
        try {
            const { data: serverRecord, error } = await this.supabase
                .from('user_sync_data')
                .select('data')
                .eq('user_email', this.currentUser.email)
                .eq('data_type', dataType)
                .single();
            
            if (error) throw error;
            
            const serverArray = serverRecord.data || [];
            const merged = this.mergeArrays(serverArray, localArray, this.getArrayMergeKey(dataType));
            
            // Update local storage with merged data
            this.updateLocalData(dataType, merged);
            
            // Sync merged data to server
            await this.syncToServer(dataType, merged, true);
            
            console.log('🔄 Merged array data for:', dataType);
            return true;
            
        } catch (error) {
            console.error('Failed to merge array data:', error);
            return false;
        }
    }

    // Merge two arrays with deduplication
    mergeArrays(array1, array2, keyField) {
        const combined = [...array1, ...array2];
        const unique = combined.filter((item, index, self) => 
            index === self.findIndex(t => t[keyField] === item[keyField])
        );
        
        // Sort by timestamp if available
        return unique.sort((a, b) => {
            const timeA = a.timestamp || a.created_at || 0;
            const timeB = b.timestamp || b.created_at || 0;
            return new Date(timeB) - new Date(timeA);
        });
    }

    // Get merge key for different data types
    getArrayMergeKey(dataType) {
        switch (dataType) {
            case this.syncTypes.SAVED_SEARCHES:
                return 'id';
            case this.syncTypes.SAVED_PROPERTIES:
                return 'id';
            case this.syncTypes.SEARCH_HISTORY:
                return 'query';
            default:
                return 'id';
        }
    }

    // Utility functions
    getDeviceId() {
        let deviceId = localStorage.getItem('deviceId');
        if (!deviceId) {
            deviceId = 'device_' + Date.now() + '_' + Math.random().toString(36).substr(2, 9);
            localStorage.setItem('deviceId', deviceId);
        }
        return deviceId;
    }

    getLastSyncTime() {
        return localStorage.getItem('lastSyncTime');
    }

    updateLastSyncTime() {
        const now = new Date().toISOString();
        localStorage.setItem('lastSyncTime', now);
        this.lastSyncTime = now;
    }

    getLocalDataTimestamp(dataType) {
        return localStorage.getItem(`${dataType}_timestamp`);
    }

    setLocalDataTimestamp(dataType, timestamp) {
        localStorage.setItem(`${dataType}_timestamp`, timestamp);
    }

    updateLocalData(dataType, data) {
        const key = this.getLocalStorageKey(dataType);
        localStorage.setItem(key, JSON.stringify(data));
        this.setLocalDataTimestamp(dataType, new Date().toISOString());
    }

    getLocalStorageKey(dataType) {
        switch (dataType) {
            case this.syncTypes.PREFERENCES:
                return 'userPreferences';
            case this.syncTypes.SAVED_SEARCHES:
                return 'savedSearches';
            case this.syncTypes.SAVED_PROPERTIES:
                return 'savedProperties';
            case this.syncTypes.SEARCH_HISTORY:
                return 'searchHistory';
            case this.syncTypes.VISIT_HISTORY:
                return 'visitHistory';
            case this.syncTypes.NOTIFICATION_SETTINGS:
                return 'notificationPreferences';
            default:
                return dataType;
        }
    }

    getLocalChanges() {
        const changes = JSON.parse(localStorage.getItem('pendingSyncChanges') || '[]');
        return changes;
    }

    addLocalChange(dataType, data) {
        const changes = this.getLocalChanges();
        const existingIndex = changes.findIndex(c => c.type === dataType);
        
        const change = {
            type: dataType,
            data: data,
            timestamp: new Date().toISOString()
        };
        
        if (existingIndex >= 0) {
            changes[existingIndex] = change;
        } else {
            changes.push(change);
        }
        
        localStorage.setItem('pendingSyncChanges', JSON.stringify(changes));
    }

    clearLocalChanges() {
        localStorage.removeItem('pendingSyncChanges');
    }

    storeFailedSync(dataType, data) {
        const failed = JSON.parse(localStorage.getItem('failedSyncs') || '[]');
        failed.push({
            type: dataType,
            data: data,
            timestamp: new Date().toISOString(),
            retries: 0
        });
        localStorage.setItem('failedSyncs', JSON.stringify(failed));
    }

    triggerUIUpdate(dataType) {
        // Dispatch custom events for UI updates
        const event = new CustomEvent('syncDataUpdated', {
            detail: { dataType, timestamp: new Date().toISOString() }
        });
        document.dispatchEvent(event);
    }

    // Public API methods
    async saveUserPreferences(preferences) {
        this.updateLocalData(this.syncTypes.PREFERENCES, preferences);
        this.addLocalChange(this.syncTypes.PREFERENCES, preferences);
        return await this.syncToServer(this.syncTypes.PREFERENCES, preferences);
    }

    async saveSavedSearch(search) {
        const saved = JSON.parse(localStorage.getItem('savedSearches') || '[]');
        search.id = search.id || Date.now().toString();
        search.timestamp = new Date().toISOString();
        
        const existingIndex = saved.findIndex(s => s.id === search.id);
        if (existingIndex >= 0) {
            saved[existingIndex] = search;
        } else {
            saved.push(search);
        }
        
        this.updateLocalData(this.syncTypes.SAVED_SEARCHES, saved);
        this.addLocalChange(this.syncTypes.SAVED_SEARCHES, saved);
        return await this.syncToServer(this.syncTypes.SAVED_SEARCHES, saved);
    }

    async saveProperty(propertyId) {
        const saved = JSON.parse(localStorage.getItem('savedProperties') || '[]');
        if (!saved.includes(propertyId)) {
            saved.push(propertyId);
            this.updateLocalData(this.syncTypes.SAVED_PROPERTIES, saved);
            this.addLocalChange(this.syncTypes.SAVED_PROPERTIES, saved);
            return await this.syncToServer(this.syncTypes.SAVED_PROPERTIES, saved);
        }
        return true;
    }

    async unsaveProperty(propertyId) {
        const saved = JSON.parse(localStorage.getItem('savedProperties') || '[]');
        const filtered = saved.filter(id => id !== propertyId);
        
        if (filtered.length !== saved.length) {
            this.updateLocalData(this.syncTypes.SAVED_PROPERTIES, filtered);
            this.addLocalChange(this.syncTypes.SAVED_PROPERTIES, filtered);
            return await this.syncToServer(this.syncTypes.SAVED_PROPERTIES, filtered);
        }
        return true;
    }

    // Set custom conflict resolver
    setConflictResolver(resolver) {
        this.conflictResolver = resolver;
    }

    // Get sync status
    getSyncStatus() {
        return {
            isOnline: navigator.onLine,
            lastSyncTime: this.lastSyncTime,
            pendingChanges: this.getLocalChanges().length,
            currentUser: this.currentUser?.email
        };
    }
}

// Initialize sync manager - use supabaseClient if available, fallback to supabase
if (typeof window !== 'undefined') {
    const supabaseInstance = window.supabaseClient || window.supabase;
    if (supabaseInstance) {
        window.syncManager = new SyncManager(supabaseInstance);
    } else {
        console.warn('⚠️ Supabase not available, SyncManager not initialized');
    }
}