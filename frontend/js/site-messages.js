/**
 * Messages, from anywhere on the site.
 *
 * Replying to a landlord used to mean leaving whatever you were doing, going to
 * the messages page, finding the thread, and losing the room you were looking
 * at. A conversation is a thing you dip into, so it lives in a drawer: an
 * envelope in the header with the unread count on it, and a panel that slides
 * up over the page you are already on.
 *
 * Self-contained on purpose. listings.html has its own messaging panel wired
 * into that page's own chat code, and pulling that apart to share it would risk
 * the one place messaging already works. Every id here is namespaced `rf-msg-`
 * so the two cannot collide, and the older panel is hidden where this loads.
 */
(function () {
    'use strict';

    /**
     * Where a thread came from, and the colour it wears.
     *
     * An inbox mixing a landlord, a sublease and a roommate is three identical
     * rows otherwise: same avatar, same name shape, no way to tell which part
     * of the site you were in when it started. `context` is set on the
     * conversation when it is created, and the server hands it back here.
     */
    var SOURCES = {
        listing:  { label: 'Listings', color: '#667eea' },
        sublease: { label: 'Sublease', color: '#0ea5e9' },
        roommate: { label: 'RoomPal',  color: '#10b981' }
    };

    function sourceOf(conversation) {
        return SOURCES[conversation && conversation.context] || SOURCES.listing;
    }

    var POLL_MS = 15000;       // how often the unread count refreshes
    var THREAD_POLL_MS = 5000; // faster while a thread is actually open

    var state = {
        email: null,
        open: false,
        conversations: [],
        activeId: null,
        unread: 0,
        pollTimer: null,
        threadTimer: null,
        lastMessageIds: new Set()
    };

    // ---------------------------------------------------------------- helpers

    function esc(value) {
        return String(value == null ? '' : value).replace(/[&<>"']/g, function (c) {
            return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c];
        });
    }

    /** Who is signed in, read the same way the rest of the site reads it. */
    function currentEmail() {
        try {
            var raw = localStorage.getItem('currentUser');
            if (!raw) return null;
            var user = JSON.parse(raw);
            return (user && (user.email || user.userEmail)) || null;
        } catch (e) {
            return null;
        }
    }

    function timeAgo(iso) {
        if (!iso) return '';
        var seconds = Math.floor((Date.now() - new Date(iso).getTime()) / 1000);
        if (seconds < 60) return 'just now';
        if (seconds < 3600) return Math.floor(seconds / 60) + 'm';
        if (seconds < 86400) return Math.floor(seconds / 3600) + 'h';
        if (seconds < 604800) return Math.floor(seconds / 86400) + 'd';
        return new Date(iso).toLocaleDateString();
    }

    // ------------------------------------------------------------------ chrome

    function injectStyles() {
        if (document.getElementById('rf-msg-styles')) return;
        var style = document.createElement('style');
        style.id = 'rf-msg-styles';
        style.textContent = [
            '#rf-msg-btn{position:relative;display:inline-flex;align-items:center;justify-content:center;',
            '  width:38px;height:38px;border-radius:999px;border:none;background:transparent;cursor:pointer;color:#4b5563}',
            '#rf-msg-btn:hover{background:rgba(99,102,241,.10);color:#4f46e5}',
            '#rf-msg-count{position:absolute;top:2px;right:2px;min-width:17px;height:17px;padding:0 4px;',
            '  border-radius:999px;background:#ef4444;color:#fff;font-size:10px;font-weight:700;line-height:17px;',
            '  text-align:center;box-shadow:0 0 0 2px #fff}',
            '#rf-msg-count[hidden]{display:none}',
            /* The drawer. Bottom-anchored on every screen size: it is a thing you
               pull up over the page, not a page of its own. */
            '#rf-msg-drawer{position:fixed;right:16px;bottom:0;width:380px;max-width:calc(100vw - 32px);',
            '  height:min(560px,72vh);background:#fff;border-radius:16px 16px 0 0;display:flex;flex-direction:column;',
            '  box-shadow:0 -8px 40px rgba(15,23,42,.22);z-index:100000;overflow:hidden;',
            '  transform:translateY(100%);transition:transform .22s ease}',
            '#rf-msg-drawer.rf-open{transform:translateY(0)}',
            '@media (max-width:640px){#rf-msg-drawer{right:0;left:0;width:auto;max-width:none;border-radius:16px 16px 0 0}}',
            '@media (prefers-reduced-motion:reduce){#rf-msg-drawer{transition:none}}',
            '#rf-msg-head{display:flex;align-items:center;gap:8px;padding:12px 14px;color:#fff;',
            '  background:linear-gradient(135deg,#6366f1,#8b5cf6)}',
            '#rf-msg-head h4{margin:0;font-size:14px;font-weight:600;flex:1}',
            '.rf-msg-icobtn{background:transparent;border:none;color:#fff;cursor:pointer;padding:4px;border-radius:6px;line-height:0}',
            '.rf-msg-icobtn:hover{background:rgba(255,255,255,.18)}',
            '#rf-msg-body{flex:1;overflow-y:auto;background:#f8fafc}',
            '.rf-msg-row{display:flex;gap:10px;padding:11px 14px;border-bottom:1px solid #eef1f6;cursor:pointer;background:#fff}',
            '.rf-msg-row:hover{background:#f5f7ff}',
            '.rf-msg-av{width:36px;height:36px;border-radius:999px;background:#eef0fb;color:#4f46e5;',
            '  display:flex;align-items:center;justify-content:center;font-weight:700;font-size:13px;flex:none}',
            '.rf-msg-who{font-size:13px;font-weight:600;color:#111827;display:flex;justify-content:space-between;gap:8px}',
            '.rf-msg-when{font-size:11px;color:#9ca3af;font-weight:400;flex:none}',
            '.rf-msg-tag{display:inline-block;font-size:10px;font-weight:700;letter-spacing:.02em;padding:2px 7px;border-radius:999px;margin:2px 0 3px}',
            '.rf-msg-sub{font-size:11px;color:#6b7280;margin-top:1px}',
            '.rf-msg-last{font-size:12px;color:#4b5563;margin-top:2px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}',
            '.rf-msg-dot{width:8px;height:8px;border-radius:999px;background:#6366f1;flex:none;align-self:center}',
            '.rf-msg-empty{padding:36px 20px;text-align:center;color:#6b7280;font-size:13px}',
            /* thread */
            '.rf-msg-bubble{max-width:78%;padding:8px 11px;border-radius:14px;font-size:13px;line-height:1.4;',
            '  margin:6px 14px;word-wrap:break-word;white-space:pre-wrap}',
            '.rf-msg-mine{margin-left:auto;background:#6366f1;color:#fff;border-bottom-right-radius:4px}',
            '.rf-msg-theirs{background:#fff;color:#111827;border:1px solid #e5e7eb;border-bottom-left-radius:4px}',
            '#rf-msg-compose{display:flex;gap:8px;padding:10px;border-top:1px solid #e5e7eb;background:#fff}',
            /* display:flex beats the hidden attribute, so the composer stayed
               on screen over the conversation list - a box you could type into
               that sent nowhere, because there is no thread selected yet. */
            '#rf-msg-compose[hidden]{display:none}',
            '#rf-msg-input{flex:1;border:1px solid #d1d5db;border-radius:999px;padding:9px 13px;font:inherit;font-size:13px;outline:none}',
            '#rf-msg-input:focus{border-color:#6366f1;box-shadow:0 0 0 3px rgba(99,102,241,.15)}',
            '#rf-msg-send{border:none;background:#6366f1;color:#fff;border-radius:999px;width:38px;height:38px;',
            '  cursor:pointer;flex:none;font-size:15px}',
            '#rf-msg-send:disabled{opacity:.45;cursor:not-allowed}',
            /* The launcher. Always on screen, on every page, because the
               header button kept being wiped out: site-nav.js rebuilds the nav
               after this script inserts into it, so on listings.html there was
               no way into messages at all. This one hangs off <body>, which
               nothing else rewrites. */
            '#rf-msg-launcher{position:fixed;right:20px;bottom:20px;width:54px;height:54px;border-radius:999px;',
            '  border:none;cursor:pointer;background:linear-gradient(135deg,#6366f1,#8b5cf6);color:#fff;',
            '  box-shadow:0 6px 22px rgba(79,70,229,.42);z-index:99998;display:flex;align-items:center;',
            '  justify-content:center;transition:transform .15s ease,box-shadow .15s ease}',
            '#rf-msg-launcher:hover{transform:scale(1.07);box-shadow:0 8px 28px rgba(79,70,229,.55)}',
            '#rf-msg-launcher-count{position:absolute;top:-2px;right:-2px;min-width:20px;height:20px;padding:0 5px;',
            '  border-radius:999px;background:#ef4444;color:#fff;font-size:11px;font-weight:700;line-height:20px;',
            '  text-align:center;box-shadow:0 0 0 2px #fff}',
            '#rf-msg-launcher-count[hidden]{display:none}',
            /* Out of the way while the drawer it opens is on screen. */
            'body.rf-drawer-open #rf-msg-launcher{opacity:0;pointer-events:none}',
            '@media (max-width:640px){#rf-msg-launcher{right:16px;bottom:16px;width:50px;height:50px}}',
            /* Notifications popover under the bell. */
            '#rf-note-pop{position:fixed;z-index:99999;background:#fff;border:1px solid #e5e7eb;',
            '  border-radius:14px;box-shadow:0 18px 44px rgba(15,23,42,.18);overflow:hidden}',
            '#rf-note-pop[hidden]{display:none}',
            '#rf-note-head{padding:11px 14px;font-size:13px;font-weight:700;color:#111827;',
            '  border-bottom:1px solid #f3f4f6}',
            '#rf-note-body{max-height:min(60vh,380px);overflow-y:auto}',
            '.rf-note-empty{padding:22px 16px;text-align:center;font-size:13px;color:#6b7280}',
            '.rf-note-row{display:flex;gap:10px;width:100%;text-align:left;background:none;border:none;',
            '  padding:11px 14px;cursor:pointer;border-bottom:1px solid #f9fafb;font:inherit}',
            '.rf-note-row:hover{background:#f9fafb}',
            '.rf-note-pip{width:8px;height:8px;border-radius:999px;flex:none;margin-top:5px}',
            '.rf-note-main{display:flex;flex-direction:column;gap:3px;min-width:0;flex:1}',
            '.rf-note-title{font-size:13px;font-weight:600;color:#111827}',
            '.rf-note-meta{display:flex;align-items:center;gap:7px}',
            '.rf-note-when{font-size:11px;color:#9ca3af}',
            '.rf-note-preview{font-size:12px;color:#6b7280;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}',
            '#rf-note-all{width:100%;border:none;border-top:1px solid #f3f4f6;background:#fff;color:#4f46e5;',
            '  font:inherit;font-size:12px;font-weight:600;padding:10px;cursor:pointer}',
            '#rf-note-all:hover{background:#f5f3ff}'
        ].join('\n');
        document.head.appendChild(style);
    }

    /** The envelope, placed beside whatever the header already shows. */
    function injectButton() {
        if (document.getElementById('rf-msg-btn')) return true;

        // Next to the profile link or the login button, which is where someone
        // looks for anything to do with their own account. Several pages build
        // their header at runtime, so this is retried until one appears.
        var anchor = document.querySelector('#navProfileLink')
            || document.querySelector('.login-register-btn')
            || document.querySelector('.auth-link');

        if (anchor && anchor.parentNode) {
            anchor.parentNode.insertBefore(buildButton(), anchor);
            return true;
        }

        // Some headers are written into the page by hand and have none of the
        // above. Rather than leave no way in at all, hang it off the end of the
        // header's own nav.
        var nav = document.querySelector('header nav, #header nav, .premium-header nav');
        if (nav) {
            nav.appendChild(buildButton());
            return true;
        }
        return false;
    }

    /**
     * The permanent way in, bottom right of every page.
     *
     * Appended to <body> rather than the header on purpose: the header button
     * is inserted into a nav that site-nav.js rebuilds a moment later, which
     * silently removed it and left listings.html with no entry point at all.
     */
    function injectLauncher() {
        if (document.getElementById('rf-msg-launcher')) return;
        var b = document.createElement('button');
        b.id = 'rf-msg-launcher';
        b.type = 'button';
        b.title = 'Messages';
        b.setAttribute('aria-label', 'Messages');
        b.innerHTML =
            '<svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor"' +
            ' stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">' +
            '<path d="M21 11.5a8.38 8.38 0 0 1-.9 3.8 8.5 8.5 0 0 1-7.6 4.7 8.38 8.38 0 0 1-3.8-.9L3 21l1.9-5.7a8.38 8.38 0 0 1-.9-3.8 8.5 8.5 0 0 1 4.7-7.6 8.38 8.38 0 0 1 3.8-.9h.5a8.48 8.48 0 0 1 8 8v.5z"/></svg>' +
            '<span id="rf-msg-launcher-count" hidden>0</span>';
        b.addEventListener('click', toggle);
        document.body.appendChild(b);
    }

    /**
     * The bell in the header.
     *
     * A bell, not an envelope: this is the place people look for "has anything
     * happened", and what appears under it is a list of things that happened -
     * new messages today, more later - not a mailbox. The mailbox is the drawer
     * at the bottom right.
     */
    function buildButton() {

        var btn = document.createElement('button');
        btn.id = 'rf-msg-btn';
        btn.type = 'button';
        btn.title = 'Notifications';
        btn.setAttribute('aria-label', 'Notifications');
        btn.innerHTML =
            '<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor"' +
            ' stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">' +
            '<path d="M18 8a6 6 0 1 0-12 0c0 7-3 9-3 9h18s-3-2-3-9"/>' +
            '<path d="M13.73 21a2 2 0 0 1-3.46 0"/></svg>' +
            '<span id="rf-msg-count" hidden>0</span>';
        btn.addEventListener('click', toggleNotifications);
        return btn;
    }

    /* ---------------------------------------------------------------
       Notifications
       ---------------------------------------------------------------
       The bell answers "has anything happened while I was away". Right
       now the only thing that happens is a message arriving, so each
       unread thread becomes one notification line, tagged with the part
       of the site it came from. Tapping one opens that thread in the
       drawer, which is where replying lives.
    */

    function unreadThreads() {
        return state.conversations.filter(function (c) { return c.unreadCount > 0; });
    }

    function injectNotifications() {
        if (document.getElementById('rf-note-pop')) return;
        var pop = document.createElement('div');
        pop.id = 'rf-note-pop';
        pop.setAttribute('role', 'dialog');
        pop.setAttribute('aria-label', 'Notifications');
        pop.hidden = true;
        pop.innerHTML =
            '<div id="rf-note-head">Notifications</div>' +
            '<div id="rf-note-body"></div>' +
            '<button type="button" id="rf-note-all">Open all messages</button>';
        document.body.appendChild(pop);

        document.getElementById('rf-note-all').addEventListener('click', function () {
            closeNotifications();
            open();
        });

        // Anywhere else dismisses it, the way every other dropdown behaves.
        document.addEventListener('click', function (e) {
            var btn = document.getElementById('rf-msg-btn');
            if (pop.hidden) return;
            if (pop.contains(e.target) || (btn && btn.contains(e.target))) return;
            closeNotifications();
        });
        document.addEventListener('keydown', function (e) {
            if (e.key === 'Escape') closeNotifications();
        });
    }

    function renderNotifications() {
        var body = document.getElementById('rf-note-body');
        if (!body) return;

        if (!state.email) {
            body.innerHTML = '<div class="rf-note-empty">Sign in to see your notifications.</div>';
            return;
        }

        var threads = unreadThreads();
        if (!threads.length) {
            body.innerHTML = '<div class="rf-note-empty">You are all caught up.</div>';
            return;
        }

        body.innerHTML = threads.map(function (c) {
            var source = sourceOf(c);
            var who = c.otherParty || 'Someone';
            var count = c.unreadCount;
            return '<button type="button" class="rf-note-row" data-id="' + esc(c.id) + '">' +
                '<span class="rf-note-pip" style="background:' + source.color + '"></span>' +
                '<span class="rf-note-main">' +
                    '<span class="rf-note-title">' + count + ' new message' + (count === 1 ? '' : 's') +
                        ' from ' + esc(who) + '</span>' +
                    '<span class="rf-note-meta">' +
                        '<span class="rf-msg-tag" style="color:' + source.color +
                            ';background:' + source.color + '1f">' + esc(source.label) + '</span>' +
                        '<span class="rf-note-when">' + esc(timeAgo(c.lastMessageAt)) + '</span>' +
                    '</span>' +
                    '<span class="rf-note-preview">' + esc(c.lastMessage || '') + '</span>' +
                '</span>' +
            '</button>';
        }).join('');

        Array.prototype.forEach.call(body.querySelectorAll('.rf-note-row'), function (row) {
            row.addEventListener('click', function () {
                var id = row.getAttribute('data-id');
                closeNotifications();
                open();
                openThread(id);
            });
        });
    }

    function toggleNotifications(e) {
        if (e) e.stopPropagation();
        var pop = document.getElementById('rf-note-pop');
        if (!pop) return;
        if (pop.hidden) {
            // Refresh on open so the list is what is true now, not what was
            // true up to fifteen seconds ago.
            refreshUnread();
            renderNotifications();
            positionNotifications();
            pop.hidden = false;
        } else {
            closeNotifications();
        }
    }

    function closeNotifications() {
        var pop = document.getElementById('rf-note-pop');
        if (pop) pop.hidden = true;
    }

    /** Under the bell, and never off the side of a narrow screen. */
    function positionNotifications() {
        var pop = document.getElementById('rf-note-pop');
        var btn = document.getElementById('rf-msg-btn');
        if (!pop || !btn) return;
        var box = btn.getBoundingClientRect();
        var width = Math.min(340, window.innerWidth - 24);
        var left = Math.min(Math.max(12, box.left + box.width / 2 - width / 2),
                            window.innerWidth - width - 12);
        pop.style.width = width + 'px';
        pop.style.top = (box.bottom + 10) + 'px';
        pop.style.left = left + 'px';
    }

    function injectDrawer() {
        if (document.getElementById('rf-msg-drawer')) return;
        var d = document.createElement('div');
        d.id = 'rf-msg-drawer';
        d.setAttribute('role', 'dialog');
        d.setAttribute('aria-label', 'Messages');
        d.innerHTML =
            '<div id="rf-msg-head">' +
              '<button class="rf-msg-icobtn" id="rf-msg-back" hidden aria-label="Back to all messages">' +
                '<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"' +
                ' stroke-linecap="round" stroke-linejoin="round"><path d="m15 18-6-6 6-6"/></svg>' +
              '</button>' +
              '<h4 id="rf-msg-title">Messages</h4>' +
              '<button class="rf-msg-icobtn" id="rf-msg-close" aria-label="Close messages">' +
                '<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"' +
                ' stroke-linecap="round" stroke-linejoin="round"><path d="M18 6 6 18M6 6l12 12"/></svg>' +
              '</button>' +
            '</div>' +
            '<div id="rf-msg-body"></div>' +
            '<form id="rf-msg-compose" hidden>' +
              '<input id="rf-msg-input" type="text" placeholder="Write a message" autocomplete="off">' +
              '<button id="rf-msg-send" type="submit" aria-label="Send">&#8593;</button>' +
            '</form>';
        document.body.appendChild(d);

        document.getElementById('rf-msg-close').addEventListener('click', close);
        document.getElementById('rf-msg-back').addEventListener('click', showList);
        document.getElementById('rf-msg-compose').addEventListener('submit', send);

        document.addEventListener('keydown', function (e) {
            if (e.key === 'Escape' && state.open) close();
        });
    }

    /** listings.html has its own panel; two envelopes in two corners is worse
     *  than either one alone. */
    function hideLegacyPanel() {
        var legacy = document.getElementById('messagingPanel');
        if (legacy) legacy.style.display = 'none';
    }

    // ------------------------------------------------------------------- data

    function api(path, options) {
        return fetch(path, options).then(function (r) {
            if (!r.ok) throw new Error('HTTP ' + r.status);
            return r.json();
        });
    }

    function refreshUnread() {
        if (!state.email) return Promise.resolve();
        return api('/api/conversations?userEmail=' + encodeURIComponent(state.email))
            .then(function (payload) {
                state.conversations = (payload && payload.data) || [];
                state.unread = state.conversations.reduce(function (n, c) {
                    return n + (c.unreadCount || 0);
                }, 0);
                paintCount();
                if (state.open && !state.activeId) renderList();
                // Keep an open bell list honest while it sits there: a message
                // arriving during the poll should appear, and one that has been
                // read elsewhere should drop off.
                var pop = document.getElementById('rf-note-pop');
                if (pop && !pop.hidden) renderNotifications();
            })
            .catch(function () { /* a badge that fails to update must not break the page */ });
    }

    function paintCount() {
        var text = state.unread > 99 ? '99+' : String(state.unread);
        // Both carry it: the launcher is the way in, the header one is the
        // notification you notice without looking down.
        ['rf-msg-count', 'rf-msg-launcher-count'].forEach(function (id) {
            var el = document.getElementById(id);
            if (!el) return;
            if (state.unread > 0) {
                el.textContent = text;
                el.hidden = false;
            } else {
                el.hidden = true;
            }
        });
    }

    // --------------------------------------------------------------- rendering

    function renderList() {
        var body = document.getElementById('rf-msg-body');
        if (!body) return;

        document.getElementById('rf-msg-back').hidden = true;
        document.getElementById('rf-msg-title').textContent = 'Messages';
        document.getElementById('rf-msg-compose').hidden = true;

        if (!state.email) {
            body.innerHTML = '<div class="rf-msg-empty">Sign in to see your messages.<br><br>' +
                '<a href="login.html" style="color:#4f46e5;font-weight:600">Sign in</a></div>';
            return;
        }
        if (!state.conversations.length) {
            body.innerHTML = '<div class="rf-msg-empty">No messages yet.<br>' +
                'Message a landlord from any room and it will appear here.</div>';
            return;
        }

        body.innerHTML = state.conversations.map(function (c) {
            var who = c.otherParty || 'Someone';
            var initial = esc(who.charAt(0).toUpperCase());
            var source = sourceOf(c);
            return '<div class="rf-msg-row" data-id="' + esc(c.id) + '">' +
                '<div class="rf-msg-av" style="background:' + source.color + '">' + initial + '</div>' +
                '<div style="flex:1;min-width:0">' +
                  '<div class="rf-msg-who"><span>' + esc(who) + '</span>' +
                    '<span class="rf-msg-when">' + esc(timeAgo(c.lastMessageAt)) + '</span></div>' +
                  '<div><span class="rf-msg-tag" style="color:' + source.color +
                    ';background:' + source.color + '1f">' + esc(source.label) + '</span></div>' +
                  (c.subject ? '<div class="rf-msg-sub">' + esc(c.subject) + '</div>' : '') +
                  '<div class="rf-msg-last">' + esc(c.lastMessage || 'No messages yet') + '</div>' +
                '</div>' +
                (c.unreadCount ? '<span class="rf-msg-dot" title="' + c.unreadCount + ' unread"></span>' : '') +
            '</div>';
        }).join('');

        Array.prototype.forEach.call(body.querySelectorAll('.rf-msg-row'), function (row) {
            row.addEventListener('click', function () { openThread(row.getAttribute('data-id')); });
        });
    }

    function openThread(id) {
        var conversation = state.conversations.filter(function (c) { return String(c.id) === String(id); })[0];
        state.activeId = id;
        state.lastMessageIds = new Set();

        document.getElementById('rf-msg-back').hidden = false;
        document.getElementById('rf-msg-title').textContent =
            (conversation && conversation.otherParty) || 'Conversation';
        document.getElementById('rf-msg-compose').hidden = false;
        document.getElementById('rf-msg-body').innerHTML =
            '<div class="rf-msg-empty">Loading…</div>';

        loadThread(true);
        clearInterval(state.threadTimer);
        // Polled while open, so a reply lands without the reader doing anything.
        state.threadTimer = setInterval(function () { loadThread(false); }, THREAD_POLL_MS);
    }

    function loadThread(scroll) {
        if (!state.activeId || !state.email) return;
        api('/api/messages?conversationId=' + encodeURIComponent(state.activeId) +
            '&userEmail=' + encodeURIComponent(state.email))
            .then(function (payload) {
                var messages = (payload && (payload.data || payload.messages)) || [];
                var body = document.getElementById('rf-msg-body');
                if (!body || state.activeId == null) return;

                var atBottom = body.scrollHeight - body.scrollTop - body.clientHeight < 60;

                body.innerHTML = messages.map(function (m) {
                    var mine = String(m.sender_email || '').toLowerCase() === state.email.toLowerCase();
                    return '<div class="rf-msg-bubble ' + (mine ? 'rf-msg-mine' : 'rf-msg-theirs') + '">' +
                        esc(m.content) + '</div>';
                }).join('') || '<div class="rf-msg-empty">No messages yet. Say hello.</div>';

                if (scroll || atBottom) body.scrollTop = body.scrollHeight;

                // Opening the thread marks it read server-side, so the badge
                // should stop claiming otherwise.
                refreshUnread();
            })
            .catch(function () {
                var body = document.getElementById('rf-msg-body');
                if (body && scroll) body.innerHTML =
                    '<div class="rf-msg-empty">Couldn\'t load this conversation.</div>';
            });
    }

    function send(event) {
        event.preventDefault();
        var input = document.getElementById('rf-msg-input');
        var button = document.getElementById('rf-msg-send');
        var text = (input.value || '').trim();
        if (!text || !state.activeId || !state.email) return;

        input.value = '';
        button.disabled = true;

        api('/api/messages', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                conversationId: state.activeId,
                userEmail: state.email,
                content: text
            })
        }).then(function () {
            loadThread(true);
        }).catch(function () {
            // Put the words back rather than losing them.
            input.value = text;
            alert("That message didn't send. Try again.");
        }).then(function () {
            button.disabled = false;
            input.focus();
        });
    }

    // ------------------------------------------------------------------ opening

    function showList() {
        state.activeId = null;
        clearInterval(state.threadTimer);
        renderList();
    }

    function open() {
        var drawer = document.getElementById('rf-msg-drawer');
        if (!drawer) return;
        state.open = true;
        document.body.classList.add('rf-drawer-open');
        drawer.classList.add('rf-open');
        showList();
        refreshUnread();
    }

    function close() {
        var drawer = document.getElementById('rf-msg-drawer');
        if (!drawer) return;
        state.open = false;
        state.activeId = null;
        clearInterval(state.threadTimer);
        document.body.classList.remove('rf-drawer-open');
        drawer.classList.remove('rf-open');
    }

    function toggle() { state.open ? close() : open(); }

    // --------------------------------------------------------------------- init

    function start() {
        state.email = currentEmail();
        injectStyles();
        injectDrawer();
        injectNotifications();
        injectLauncher();
        hideLegacyPanel();
        window.addEventListener('resize', positionNotifications);

        injectButton();

        // Put it back when the header is rebuilt.
        //
        // site-nav.js writes the nav's contents after this script has already
        // inserted into it, so the button was there and then gone, leaving no
        // header entry point on the pages that rebuild — listings.html among
        // them. Watching is more reliable than guessing how long to wait.
        if (document.body) {
            var watcher = new MutationObserver(function () {
                if (!document.getElementById('rf-msg-btn')) injectButton();
                if (!document.getElementById('rf-msg-launcher')) injectLauncher();
                hideLegacyPanel();
        window.addEventListener('resize', positionNotifications);
            });
            watcher.observe(document.body, { childList: true, subtree: true });
        }

        if (state.email) {
            refreshUnread();
            state.pollTimer = setInterval(refreshUnread, POLL_MS);
        }

        // Signing in or out in another tab changes who this belongs to.
        window.addEventListener('storage', function (e) {
            if (e.key !== 'currentUser') return;
            state.email = currentEmail();
            state.conversations = [];
            state.unread = 0;
            paintCount();
            if (state.open) showList();
        });
    }

    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', start);
    } else {
        start();
    }

    // Opened from elsewhere, e.g. a "Message host" button that has just created
    // the thread and wants it on screen.
    window.RoomFinderMessages = {
        open: open,
        close: close,
        openConversation: function (id) { open(); openThread(id); },
        refresh: refreshUnread
    };
})();
