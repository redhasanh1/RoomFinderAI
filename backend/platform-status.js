/**
 * Single source of truth for which RoomFinderAI platforms are active.
 * Update this file when mobile apps reopen.
 */

const PLATFORM_STATUS = {
    updatedAt: '2026-08-16',
    message:
        'RoomFinderAI is available on the web, with the iOS app in preparation for the App Store. The Android app remains closed.',
    platforms: {
        web: {
            id: 'web',
            name: 'Web',
            status: 'active',
            url: 'https://www.roomfinderai.com',
            note: 'Primary platform — listings, AI negotiator, RoomPal, and account features.'
        },
        android: {
            id: 'android',
            name: 'Android',
            status: 'closed',
            path: 'RoomFinderAndroid-CLOSED/',
            note: 'Temporarily closed. Not available on Google Play or as a downloadable APK.'
        },
        ios: {
            id: 'ios',
            // Not 'active' until it is actually on sale — saying otherwise
            // sends people to an App Store page that does not exist yet.
            status: 'preparing',
            name: 'iOS',
            path: 'ios/',
            note: 'In preparation for App Store submission. Every web feature is available in the app.'
        }
    },
    documentation: '/DOCUMENTATION.md',
    statusPage: '/platform-status.html'
};

function getActivePlatforms() {
    return Object.values(PLATFORM_STATUS.platforms).filter((p) => p.status === 'active');
}

function getClosedPlatforms() {
    return Object.values(PLATFORM_STATUS.platforms).filter((p) => p.status === 'closed');
}

function isMobileClosed() {
    return (
        PLATFORM_STATUS.platforms.android.status === 'closed' &&
        PLATFORM_STATUS.platforms.ios.status === 'closed'
    );
}

function getPreparingPlatforms() {
    return Object.values(PLATFORM_STATUS.platforms).filter((p) => p.status === 'preparing');
}

module.exports = {
    PLATFORM_STATUS,
    getActivePlatforms,
    getClosedPlatforms,
    getPreparingPlatforms,
    isMobileClosed
};
