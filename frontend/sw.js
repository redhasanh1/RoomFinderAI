// Service Worker for Push Notifications
const CACHE_NAME = 'roomfinder-v1';
const urlsToCache = [
    '/',
    '/listings.html',
    '/css/mobile-android.css',
    '/js/notification-manager.js',
    '/icons/icon-192x192.png'
];

// Install event - cache resources
self.addEventListener('install', (event) => {
    console.log('📱 Service Worker installing...');
    
    event.waitUntil(
        caches.open(CACHE_NAME)
            .then((cache) => {
                console.log('📦 Caching resources');
                // Try to cache each URL individually to handle failures gracefully
                return Promise.all(
                    urlsToCache.map(url => {
                        return cache.add(url).catch(err => {
                            console.warn(`Failed to cache ${url}:`, err);
                            // Continue even if some resources fail to cache
                        });
                    })
                );
            })
            .then(() => {
                console.log('✅ Service Worker installed');
                return self.skipWaiting();
            })
            .catch(err => {
                console.error('Service Worker installation failed:', err);
                // Still skip waiting even if caching fails
                return self.skipWaiting();
            })
    );
});

// Activate event - clean up old caches
self.addEventListener('activate', (event) => {
    console.log('🔄 Service Worker activating...');
    
    event.waitUntil(
        caches.keys().then((cacheNames) => {
            return Promise.all(
                cacheNames.map((cacheName) => {
                    if (cacheName !== CACHE_NAME) {
                        console.log('🗑️ Deleting old cache:', cacheName);
                        return caches.delete(cacheName);
                    }
                })
            );
        }).then(() => {
            console.log('✅ Service Worker activated');
            return self.clients.claim();
        })
    );
});

// Fetch event - serve from cache when offline
self.addEventListener('fetch', (event) => {
    event.respondWith(
        caches.match(event.request)
            .then((response) => {
                // Return cached version or fetch from network
                return response || fetch(event.request);
            })
            .catch(() => {
                // Return offline page for HTML requests
                if (event.request.destination === 'document') {
                    return caches.match('/offline.html');
                }
            })
    );
});

// Push event - handle incoming push notifications
self.addEventListener('push', (event) => {
    console.log('🔔 Push notification received:', event);
    
    let notificationData = {
        title: 'RoomFinderAI',
        body: 'You have a new notification',
        icon: '/icons/icon-192x192.png',
        badge: '/icons/badge-72x72.png',
        tag: 'default',
        data: {}
    };
    
    // Parse push data if available
    if (event.data) {
        try {
            const data = event.data.json();
            notificationData = { ...notificationData, ...data };
        } catch (error) {
            console.error('Error parsing push data:', error);
            notificationData.body = event.data.text();
        }
    }
    
    // Customize notification based on type
    if (notificationData.type) {
        switch (notificationData.type) {
            case 'new_listing':
                notificationData.title = '🏠 New Property Available';
                notificationData.tag = 'new_listing';
                notificationData.actions = [
                    { action: 'view', title: 'View Property' },
                    { action: 'dismiss', title: 'Dismiss' }
                ];
                break;
                
            case 'price_change':
                notificationData.title = '💰 Price Drop Alert';
                notificationData.tag = 'price_change';
                notificationData.actions = [
                    { action: 'view', title: 'View Property' },
                    { action: 'dismiss', title: 'Dismiss' }
                ];
                break;
                
            case 'message':
                notificationData.title = '💬 New Message';
                notificationData.tag = 'message';
                notificationData.actions = [
                    { action: 'reply', title: 'Reply' },
                    { action: 'view', title: 'View Chat' }
                ];
                break;
                
            case 'visit_reminder':
                notificationData.title = '📅 Property Visit Reminder';
                notificationData.tag = 'visit_reminder';
                notificationData.actions = [
                    { action: 'navigate', title: 'Get Directions' },
                    { action: 'reschedule', title: 'Reschedule' }
                ];
                break;
                
            case 'property_update':
                notificationData.title = '🔄 Property Updated';
                notificationData.tag = 'property_update';
                break;
        }
    }
    
    // Show notification
    event.waitUntil(
        self.registration.showNotification(notificationData.title, {
            body: notificationData.body,
            icon: notificationData.icon,
            badge: notificationData.badge,
            tag: notificationData.tag,
            data: notificationData.data,
            actions: notificationData.actions || [],
            requireInteraction: notificationData.requireInteraction || false,
            silent: false,
            vibrate: [200, 100, 200]
        })
    );
});

// Notification click event
self.addEventListener('notificationclick', (event) => {
    console.log('🖱️ Notification clicked:', event);
    
    event.notification.close();
    
    const action = event.action;
    const data = event.notification.data || {};
    
    let urlToOpen = '/listings.html';
    
    // Handle different actions
    switch (action) {
        case 'view':
            if (data.propertyId) {
                urlToOpen = `/listing_details?id=${data.propertyId}`;
            } else if (data.url) {
                urlToOpen = data.url;
            }
            break;
            
        case 'reply':
        case 'view_chat':
            if (data.conversationId) {
                urlToOpen = `/listings.html?chat=${data.conversationId}`;
            }
            break;
            
        case 'navigate':
            if (data.address) {
                urlToOpen = `https://www.google.com/maps/dir/?api=1&destination=${encodeURIComponent(data.address)}`;
            }
            break;
            
        case 'reschedule':
            urlToOpen = `/listings.html?reschedule=${data.propertyId}`;
            break;
            
        default:
            // Default click - open main app
            if (data.propertyId) {
                urlToOpen = `/listing_details?id=${data.propertyId}`;
            }
    }
    
    // Focus or open window
    event.waitUntil(
        clients.matchAll({ type: 'window' })
            .then((clientList) => {
                // Check if app is already open
                for (const client of clientList) {
                    if (client.url.includes(new URL(urlToOpen, self.location.origin).pathname) && 'focus' in client) {
                        return client.focus();
                    }
                }
                
                // Open new window
                if (clients.openWindow) {
                    return clients.openWindow(urlToOpen);
                }
            })
    );
});

// Notification close event
self.addEventListener('notificationclose', (event) => {
    console.log('🔕 Notification closed:', event.notification.tag);
    
    // Track notification dismissals for analytics
    const data = event.notification.data || {};
    if (data.trackDismissal) {
        fetch('/api/analytics/notification-dismissed', {
            method: 'POST',
            body: JSON.stringify({
                tag: event.notification.tag,
                timestamp: new Date().toISOString()
            })
        }).catch(() => {
            // Ignore analytics errors
        });
    }
});

// Background sync for offline actions
self.addEventListener('sync', (event) => {
    console.log('🔄 Background sync:', event.tag);
    
    if (event.tag === 'background-sync') {
        event.waitUntil(doBackgroundSync());
    }
});

async function doBackgroundSync() {
    console.log('📡 Performing background sync...');
    
    try {
        // Sync pending push subscriptions
        const pendingSubscription = await getFromIndexedDB('pendingPushSubscription');
        if (pendingSubscription) {
            await syncPushSubscription(pendingSubscription);
            await deleteFromIndexedDB('pendingPushSubscription');
        }
        
        // Sync pending property visits
        const pendingVisits = await getFromIndexedDB('pendingPropertyVisits');
        if (pendingVisits && pendingVisits.length > 0) {
            await syncPropertyVisits(pendingVisits);
            await deleteFromIndexedDB('pendingPropertyVisits');
        }
        
        console.log('✅ Background sync completed');
    } catch (error) {
        console.error('❌ Background sync failed:', error);
    }
}

// IndexedDB helpers
function getFromIndexedDB(key) {
    return new Promise((resolve, reject) => {
        const request = indexedDB.open('RoomFinderDB', 1);
        
        request.onerror = () => reject(request.error);
        request.onsuccess = () => {
            const db = request.result;
            const transaction = db.transaction(['data'], 'readonly');
            const store = transaction.objectStore('data');
            const getRequest = store.get(key);
            
            getRequest.onsuccess = () => resolve(getRequest.result?.value);
            getRequest.onerror = () => reject(getRequest.error);
        };
        
        request.onupgradeneeded = () => {
            const db = request.result;
            if (!db.objectStoreNames.contains('data')) {
                db.createObjectStore('data', { keyPath: 'key' });
            }
        };
    });
}

function deleteFromIndexedDB(key) {
    return new Promise((resolve, reject) => {
        const request = indexedDB.open('RoomFinderDB', 1);
        
        request.onerror = () => reject(request.error);
        request.onsuccess = () => {
            const db = request.result;
            const transaction = db.transaction(['data'], 'readwrite');
            const store = transaction.objectStore('data');
            const deleteRequest = store.delete(key);
            
            deleteRequest.onsuccess = () => resolve();
            deleteRequest.onerror = () => reject(deleteRequest.error);
        };
    });
}

async function syncPushSubscription(subscription) {
    const response = await fetch('/api/push-subscription', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(subscription)
    });
    
    if (!response.ok) {
        throw new Error('Failed to sync push subscription');
    }
}

async function syncPropertyVisits(visits) {
    for (const visit of visits) {
        const response = await fetch('/api/property-visits', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(visit)
        });
        
        if (!response.ok) {
            console.error('Failed to sync visit:', visit.id);
        }
    }
}