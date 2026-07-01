/**
 * Single source of truth for which RoomFinderAI platforms are active.
 * Update this file when mobile apps reopen.
 */

const PLATFORM_STATUS = {
    updatedAt: '2026-07-01',
    message:
        'RoomFinderAI is currently available on the web only. Native Android and iOS apps are temporarily closed while we improve stability and feature parity.',
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
            name: 'iOS',
            status: 'closed',
            path: 'RoomFinderAI-IOS-CLOSED/',
            note: 'Temporarily closed. Not available on the App Store or TestFlight.'
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

module.exports = {
    PLATFORM_STATUS,
    getActivePlatforms,
    getClosedPlatforms,
    isMobileClosed
};
