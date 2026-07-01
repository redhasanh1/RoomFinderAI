/**
 * Client-side dispute tracking (localStorage) + optional email notification via /api/contact.
 */
(function (global) {
    const STORAGE_KEY = 'roomfinder_disputes';

    function readAll() {
        try {
            return JSON.parse(localStorage.getItem(STORAGE_KEY) || '[]');
        } catch {
            return [];
        }
    }

    function writeAll(disputes) {
        localStorage.setItem(STORAGE_KEY, JSON.stringify(disputes));
    }

    function generateId() {
        return `DSP-${Date.now()}-${Math.random().toString(36).slice(2, 8).toUpperCase()}`;
    }

    function getDisputes() {
        return readAll().sort((a, b) => new Date(b.createdAt) - new Date(a.createdAt));
    }

    function getDispute(id) {
        return readAll().find((d) => d.id === id) || null;
    }

    function saveDispute(data) {
        const dispute = {
            id: generateId(),
            status: 'submitted',
            createdAt: new Date().toISOString(),
            updatedAt: new Date().toISOString(),
            ...data
        };
        const all = readAll();
        all.push(dispute);
        writeAll(all);
        return dispute;
    }

    function updateDispute(id, updates) {
        const all = readAll();
        const idx = all.findIndex((d) => d.id === id);
        if (idx === -1) return null;
        all[idx] = { ...all[idx], ...updates, updatedAt: new Date().toISOString() };
        writeAll(all);
        return all[idx];
    }

    async function notifyTeam(dispute) {
        const nameParts = (dispute.reporterName || 'User').trim().split(/\s+/);
        const firstName = nameParts[0] || 'User';
        const lastName = nameParts.slice(1).join(' ') || 'Dispute';
        const message = [
            `DISPUTE FILING — ${dispute.id}`,
            `Category: ${dispute.category}`,
            `Against: ${dispute.respondentName || 'N/A'} (${dispute.respondentEmail || 'no email'})`,
            `Listing/Property: ${dispute.propertyRef || 'N/A'}`,
            `Desired outcome: ${dispute.desiredOutcome || 'N/A'}`,
            '',
            'Description:',
            dispute.description || '',
            '',
            dispute.evidenceNotes ? `Evidence notes: ${dispute.evidenceNotes}` : ''
        ].join('\n');

        const response = await fetch('/api/contact', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                firstName,
                lastName,
                email: dispute.reporterEmail,
                message: message.slice(0, 5000)
            })
        });

        if (!response.ok) {
            const err = await response.json().catch(() => ({}));
            throw new Error(err.error || 'Failed to notify support team');
        }
        return true;
    }

    global.DisputeStore = {
        getDisputes,
        getDispute,
        saveDispute,
        updateDispute,
        notifyTeam
    };
})(typeof window !== 'undefined' ? window : global);
