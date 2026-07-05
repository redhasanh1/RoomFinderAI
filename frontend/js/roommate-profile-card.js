/**
 * Shared roommate profile summary card, rendered identically on both
 * roommate-matching.html (RoomPal) and profile.html so there is one visual
 * source of truth for "your roommate profile" instead of two hand-maintained
 * copies drifting apart.
 *
 * @param {object} profile - a roommate_profiles row (as returned by
 *   RoommateAPIService.getMySeekerProfile()).
 * @param {object} [opts]
 * @param {string} [opts.editLabel] - text for the edit action.
 * @param {function|string} [opts.onEdit] - either an onclick JS expression
 *   (string, e.g. "window.roomPalApp.startEditProfile()") or a URL to link to.
 */
function renderRoommateProfileCard(profile, opts) {
    opts = opts || {};
    const editLabel = opts.editLabel || 'Edit Profile';
    const avatar = profile.avatar_url || '';
    const areas = Array.isArray(profile.preferred_areas)
        ? profile.preferred_areas.join(', ')
        : (profile.preferred_areas || '');

    let editAction = '';
    if (opts.onEdit) {
        editAction = opts.onEdit.startsWith('http') || opts.onEdit.endsWith('.html') || opts.onEdit.includes('.html?')
            ? `<a href="${opts.onEdit}" class="mt-3 inline-block text-sm font-medium text-indigo-600 hover:text-indigo-700 hover:underline">${editLabel}</a>`
            : `<button type="button" onclick="${opts.onEdit}" class="mt-3 text-sm font-medium text-indigo-600 hover:text-indigo-700 hover:underline">${editLabel}</button>`;
    }

    return `
        <div class="flex items-start gap-4 p-4 bg-green-50 border border-green-200 rounded-xl">
            ${avatar
                ? `<img src="${avatar}" alt="Your photo" class="w-20 h-20 rounded-full object-cover border-2 border-white shadow">`
                : `<div class="w-20 h-20 rounded-full bg-indigo-100 flex items-center justify-center text-indigo-600 font-bold text-xl">${(profile.name || 'U').charAt(0)}</div>`}
            <div class="flex-1 min-w-0">
                <h3 class="text-lg font-bold text-gray-900">${profile.name || 'Your Profile'}</h3>
                <p class="text-sm text-gray-600 mt-1">$${profile.budget_min || '?'} – $${profile.budget_max || '?'}/mo · ${areas}</p>
                <p class="text-sm text-gray-700 mt-2">${profile.bio || ''}</p>
                <p class="text-xs text-green-700 mt-2 font-medium">Profile active — browse seekers on RoomPal</p>
                ${editAction}
            </div>
        </div>
    `;
}

window.renderRoommateProfileCard = renderRoommateProfileCard;
