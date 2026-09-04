/**
 * Single source of truth for which RoomFinderAI platforms are active.
 * Update this file when mobile apps reopen.
 */

const PLATFORM_STATUS = {
    updatedAt: '2026-09-04',
    message:
        'RoomFinderAI is available on the web and on Google Play, with the iOS app in preparation for the App Store.',
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
            // Live on Google Play since 4 September 2026 - production track,
            // 177 countries, release 3 (1.0.2). This said 'closed' with the
            // note "Not available on Google Play" for most of launch day,
            // which is the opposite of true and contradicts the Play links
            // going out to community groups.
            //
            // Held to the same rule the iOS entry below states for itself:
            // 'active' only once it is genuinely installable.
            status: 'active',
            path: 'RoomFinderAndroid/',
            url: 'https://play.google.com/store/apps/details?id=com.roomfinderai.android',
            note: 'Live on Google Play. Browse, message and post a room from the app.'
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
