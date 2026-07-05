# RoomFinderAI — Full End-to-End Audit & Remediation Plan

**Project:** RoomFinderAI
**Note:** "RoomPal" referenced throughout is a feature/module within RoomFinderAI, not the project name.

**Purpose:** Single source of truth for a full-stack consistency pass across UI/Frontend, Backend/AI/APIs, and Supabase/Data/Pipelines. Drop this into the project repo (e.g. `/docs/AUDIT_PLAN.md`) and work through it top to bottom. Each module has three lanes — **Frontend**, **Backend/API**, **Supabase/Data** — because a bug reported as "UI issue" is very often actually a data or API contract issue surfacing in the UI.

**Ground rule for this whole pass:** nothing is "done" until all three lanes agree for that module — same field names, same status enums, same auth checks, same empty/loading/error states. Consistency across the whole app is the actual deliverable, not just fixing the symptom the user saw.

---

## 0. How to Use This Document

For every module below:
1. Reproduce the bug exactly as described.
2. Trace it: Frontend component → API route/edge function → Supabase table/RLS policy.
3. Fix at the root cause layer, not just where it's visible.
4. Re-check every OTHER module that shares the same component/table/pattern (e.g. if messaging is broken in one place, check all message surfaces).
5. Add the item to the **Regression Checklist** at the bottom before marking complete.

Priority key: 🔴 Blocking/broken · 🟠 Functional but inconsistent · 🟡 Polish/consistency only

---

## 1. Home Page
**Status:** UI confirmed fine by user. Backend/Supabase not yet verified.

- [ ] 🟠 Audit every API call the Home page makes on load (listings preview, roommate matches, notifications badge count, etc.) — confirm each hits a real, current endpoint (no dead/mocked calls left over from earlier builds).
- [ ] 🟠 Confirm Supabase RLS policies let the logged-in user read only what Home actually needs (no over-fetching, no leaking other users' rows).
- [ ] 🟡 Confirm loading/skeleton and empty states exist for every Home widget (new users with no data shouldn't see a blank/broken block).

---

## 2. RoomPal → "I Have a Space"
**Status:** UI confirmed fine by user. Backend/Supabase not yet verified.

- [ ] 🟠 Confirm the "space" listing a user creates here is the SAME record type used everywhere else it's referenced (Listings page, Messages, AI Negotiator, Student Housing). Check for duplicate/parallel tables (e.g. a `spaces` table vs a `listings` table that should be one source of truth).
- [ ] 🟠 Confirm create/edit/delete of a space correctly cascades: e.g. deleting a space should not orphan chat threads, sublease interest records, or AI negotiation sessions tied to it.
- [ ] 🟡 Confirm field-level validation matches the Listings page's "Add Property" form (see §5) — these are very likely meant to be the same underlying flow and currently may be two different half-built forms.

---

## 3. RoomPal → "I Need a Roommate"
**Bug reported:** Full blank form shown every time instead of the user's existing roommate profile.

**Required behavior:**
- On load: show the user's **existing roommate profile card** (summary view) first.
- An **Edit** button opens the form pre-filled with existing data — not a blank form.
- If no profile exists yet, only THEN show the empty creation form.
- This same profile card/edit pattern must also appear inside the **Profile section** (§16) — one profile, two entry points, always in sync.

**Frontend**
- [ ] 🔴 Build/restore the "view mode" component (profile summary card) that renders when a profile record exists.
- [ ] 🔴 Gate the full form behind an explicit Edit action; form must be pre-populated from existing record, not reset.
- [ ] 🟠 Reuse the exact same profile component in Profile section (§16) rather than a second parallel implementation.

**Backend/API**
- [ ] 🔴 Add/confirm a `GET /roommate-profile?user_id=` (or equivalent) check that runs before deciding which view to render.
- [ ] 🟠 Ensure update endpoint does a partial `UPDATE`, not a destructive upsert that wipes unfilled fields.

**Supabase**
- [ ] 🔴 Confirm one `roommate_profiles` row per user (unique constraint on `user_id`), not multiple rows accumulating on every save.
- [ ] 🟠 Confirm RLS: user can read/update only their own row; other users can read limited public fields only (for matching).

---

## 4. RoomPal Main Page — Messaging Split
**Requirement:** Messages from "Space" listings and messages from "Roommate" matches must be fully separate — separate inboxes, shown only within their own section (mirroring how Space and Roommate already live on separate pages). No cross-bleed of message threads between the two contexts.

**Frontend**
- [ ] 🔴 Split the message inbox UI into two distinct views/tabs bound to two distinct data sources — do not filter one combined list client-side (that's fragile and is likely the current bug).
- [ ] 🟠 Confirm unread-count badges are computed per-context, not globally combined then wrongly displayed.

**Backend/API**
- [ ] 🔴 Confirm there are two distinct query paths (or one query with a mandatory `context`/`thread_type` filter enforced server-side, not just client-side) for space-messages vs roommate-messages.

**Supabase**
- [ ] 🔴 Confirm the `messages`/`threads` table has a `context_type` (`space` | `roommate`) column that is NOT nullable and is set correctly at thread-creation time.
- [ ] 🟠 Audit existing rows for NULL/incorrect `context_type` values causing current mixing — write a migration/backfill if needed.
- [ ] 🟠 RLS policies should filter by context_type + participant, not just participant.

---

## 5. Listing Page — Add Property, View Details, Map, Message Popup
Multiple issues reported here — treat as one broken flow.

### 5a. "Add Property" inaccessible
- [ ] 🔴 **Frontend:** Reproduce the exact click path from Listings page — confirm the button is wired to the correct route/modal (not a dead link or a route that requires a role/permission the user doesn't have set).
- [ ] 🔴 **Backend:** Confirm the create-listing endpoint doesn't silently reject due to missing required fields the form isn't collecting, or an auth/role check mismatch.
- [ ] 🟠 **Supabase:** Confirm RLS allows INSERT for the authenticated user's role on the listings table (a common cause of "form opens but nothing happens").

### 5b. Photo upload not working
- [ ] 🔴 **Frontend:** Confirm file input actually triggers upload handler; check console for silent failures.
- [ ] 🔴 **Backend:** Confirm upload goes to correct Supabase Storage bucket, correct path convention, and returns a URL that gets saved back onto the listing record.
- [ ] 🔴 **Supabase Storage:** Confirm bucket exists, is set to correct public/private access, and storage RLS/policies allow authenticated uploads. This is the single most common cause of "photo upload silently does nothing."

### 5c. View Details popup — image not showing
- [ ] 🔴 Confirm the popup queries the same listing record (with photo URLs) as the listing card, not a stripped-down summary object missing the image field.
- [ ] 🟠 Confirm image URLs stored in Supabase are valid/public and not expired signed URLs.

### 5d. Map view not working
- [ ] 🔴 Confirm the listing record includes valid lat/lng (or a full address that gets geocoded) — many "map broken" bugs are actually missing/null coordinate data, not a map rendering bug.
- [ ] 🟠 Confirm map API key/config is present in this environment and not silently failing (check network tab / console).
- [ ] 🟡 Add a fallback state ("location unavailable") instead of a broken/blank map when coordinates are missing.

### 5e. Message popup UI broken (file/send button overlap, layout "direct"/unstyled)
- [ ] 🔴 **Frontend:** This is a CSS/layout bug in the message compose component — audit the flex/grid layout of that popup specifically; likely a missing container width/height constraint causing the attach-file icon and send button to overlap.
- [ ] 🟠 Confirm this popup shares the same message-compose component used elsewhere (§4, §7) — fixing it once should fix it everywhere, and if it's a separate copy-pasted component that's itself a consistency bug to resolve (merge into one shared component).

---

## 6. Messages — "From Other Users" requirement
**Bug reported:** unclear whose messages are shown.

- [ ] 🔴 **Frontend:** Confirm inbox lists show the counterparty's name/photo (the other user), not the current user's own identity.
- [ ] 🔴 **Backend:** Confirm the query joins on the *other* participant of the thread relative to `auth.uid()`, not a hardcoded or first-participant assumption.
- [ ] 🟠 **Supabase:** Confirm `threads`/`participants` table structure supports this join cleanly (many-to-many participants table, not a single sender/receiver pair, if group threads exist).

---

## 7. AI Notifications — AI Negotiator messages
**Requirement:** The notification center should surface actual messages/updates FROM the AI negotiator (e.g. "AI negotiated a new offer with the landlord") — not just generic app notifications.

- [ ] 🔴 **Backend:** Confirm the AI negotiator service writes a notification record (or dedicated event) every time it takes an action on the user's behalf (sends offer, receives landlord reply, reaches a deal).
- [ ] 🔴 **Frontend:** Confirm the notification center subscribes to / polls this specific notification type and renders it distinctly (e.g. "AI Negotiator" badge/icon) vs. generic system notices.
- [ ] 🟠 **Supabase:** Confirm a `notifications` table with a `type` column (`ai_negotiation`, `message`, `system`, etc.) and that Realtime (if used) is subscribed correctly per user.

---

## 8. Student Housing Page — University Selector Cascading
**Requirement:** Selecting a university must filter/update everything below it on the page: university-specific housing listings, housing portal redirect links, budget guidance, roommate agreement templates, lease agreement templates, and any other section-specific content.

**Frontend**
- [ ] 🔴 Confirm the university selector's `onChange` actually triggers a re-fetch/re-filter of every downstream section — not just the top listings block while the rest stays static/generic.
- [ ] 🟠 Add loading states for each section while it re-fetches on university change.

**Backend/API**
- [ ] 🔴 Confirm one endpoint (or a small set) accepts `university_id` as a required param and returns ALL the relevant sections (or confirm each section's endpoint independently accepts and respects `university_id` — no section should silently ignore it).

**Supabase**
- [ ] 🔴 Confirm `university_id` is a proper foreign key on: listings, portal links, budget data, roommate agreement templates, lease agreement templates. Audit for any of these tables missing the FK entirely, which would explain "some sections don't update."
- [ ] 🟡 Seed/verify data actually exists per-university — a cascading filter that's correctly wired will still look "broken" if only one university has real data behind it.

---

## 9. Sublease — Reverse Interest Visibility
**Bug reported:** User can see subleases they expressed interest in, but cannot see who expressed interest in THEIR OWN sublease listing.

**Frontend**
- [ ] 🔴 Add a new view/tab on the sublease listing owner's side: "Interest received" — list of users who expressed interest in listings the current user owns.

**Backend/API**
- [ ] 🔴 New (or existing-but-unused) endpoint: `GET /sublease/:id/interests` scoped to the listing owner, returning interested users.
- [ ] 🟠 Confirm interest creation writes owner_id alongside interested_user_id so this reverse query is possible without expensive joins.

**Supabase**
- [ ] 🔴 Confirm `sublease_interests` table has both `listing_owner_id` and `interested_user_id` columns (not just a link to the listing, forcing a join every time).
- [ ] 🔴 RLS: listing owner must be able to SELECT rows where `listing_owner_id = auth.uid()`; interested users can only see their own submitted rows, not other applicants (privacy).
- [ ] 🟠 Consider a trigger/notification firing to §7's notification system when new interest is created, so the owner is alerted, not just able to check a page manually.

---

## 10. AI Negotiator — Full Bidirectional Workflow
**Requirement (core product loop):**
1. User picks a listing and messages the AI negotiator with intent/terms.
2. AI negotiator contacts the landlord (in the same thread or a linked thread) on the user's behalf.
3. When the landlord responds, the AI negotiator automatically continues the negotiation — no manual "restart" needed.
4. AI reaches/proposes a deal and reports back to the user.
5. **This must work symmetrically** — a landlord-initiated flow negotiating with a tenant should follow the same pattern.

This is the most complex module — treat it as its own mini state machine.

**Frontend**
- [ ] 🔴 One consistent chat UI surface for: user↔AI, AI↔landlord (visible to user as a transcript), and the final deal summary — likely three views of the SAME thread rather than three separate screens.
- [ ] 🟠 Clear visual state indicator: "Waiting for landlord," "AI negotiating," "Deal reached," "Needs your input" — the user should always know what state the negotiation is in.

**Backend/API**
- [ ] 🔴 Confirm a defined state machine exists server-side (e.g. `initiated → ai_contacted_landlord → awaiting_landlord_reply → ai_processing_reply → deal_proposed → accepted/rejected`) and every transition is logged.
- [ ] 🔴 Confirm there's a webhook/listener that fires automatically when a landlord reply arrives (email, in-app message, SMS — whatever channel) and triggers the AI's next turn WITHOUT requiring the user or landlord to manually re-trigger it.
- [ ] 🔴 Confirm the exact same negotiation engine/service handles both directions (user-initiated and landlord-initiated) — do not maintain two separate negotiation codepaths that can drift out of sync.
- [ ] 🟠 Confirm retries/timeouts: what happens if the landlord never replies? There should be a defined timeout/escalation state, not an infinite silent "waiting."

**Supabase**
- [ ] 🔴 A `negotiations` table with `status` enum matching the state machine above, `listing_id`, `initiator_id`, `counterparty_id`, timestamps per transition.
- [ ] 🔴 A `negotiation_messages` (or reuse `messages` with `negotiation_id` FK) table logging every AI turn, landlord turn, and user turn in order — this is both the audit trail and what renders the transcript in the UI.
- [ ] 🟠 RLS: both parties can read the negotiation transcript that involves them; no other user can.
- [ ] 🟠 If Realtime is used for auto-continuation, confirm the Postgres trigger/Edge Function subscription is actually deployed and active (not just written in a dev branch).

---

## 11. Legal Help
**Requirement:** All features functional; text boxes and overall UI visually and behaviorally consistent with the rest of the app; backend/Supabase consistent with the same patterns used elsewhere.

- [ ] 🔴 Inventory every feature this page claims to offer (e.g. document generation, Q&A, template downloads) and manually test each end-to-end.
- [ ] 🟠 **Frontend:** Audit every text input/textarea on this page against the app's shared form component library — replace any one-off custom inputs with the shared components used on Listings/Profile/etc. (this is almost certainly why it currently "feels" inconsistent).
- [ ] 🟠 **Backend:** If this page calls an AI/LLM for legal Q&A, confirm it uses the same model/provider config pattern as the AI Negotiator (§10) and AI Assessment (§14), not a separate hardcoded call.
- [ ] 🟠 **Supabase:** Confirm any generated documents/history are saved per-user with proper RLS, consistent with how other user-generated content is stored elsewhere in the app.

---

## 12. Pricing / Billing / Stripe
**Requirement:** Consistent UI, working Stripe integration, and full visibility of plan + billing history inside the user's Profile.

**Frontend**
- [ ] 🟠 Audit Pricing page UI against the shared design system (cards, buttons, typography) used elsewhere — fix one-off styling.
- [ ] 🔴 Add/confirm a **Billing** section inside Profile showing: current plan, renewal date, payment method on file (last 4 digits only), and full invoice/billing history.

**Backend/API**
- [ ] 🔴 Confirm Stripe webhook handler is live and updates the user's plan/status in Supabase on every relevant event (`checkout.session.completed`, `customer.subscription.updated`, `invoice.paid`, `customer.subscription.deleted`) — a very common bug class is "payment succeeds in Stripe but app never learns about it."
- [ ] 🟠 Confirm a "manage billing" action opens the Stripe customer portal rather than a custom-built (and likely incomplete) in-app billing manager.

**Supabase**
- [ ] 🔴 Confirm a `subscriptions` (or similar) table storing `stripe_customer_id`, `stripe_subscription_id`, `plan`, `status`, `current_period_end` — kept in sync purely by the webhook, never guessed client-side.
- [ ] 🟠 Confirm RLS lets a user read only their own subscription/billing rows.
- [ ] 🟡 Never store full card numbers — confirm nothing beyond Stripe's tokenized/last-4 data is ever persisted in Supabase.

---

## 13. Support Center
**Requirement:** Remove anything unnecessary/hanging; make sure remaining features are fully wired and consistent.

- [ ] 🟠 Audit every element on the Support Center for dead links, placeholder text, or features that don't actually do anything ("unnecessary hand" items) — remove or complete each one; don't leave half-built UI live.
- [ ] 🟠 Confirm ticket/inquiry submission (if present) actually writes to a Supabase table and is retrievable, not just a form that "submits" into nothing.
- [ ] 🟡 Match styling to the rest of the app (buttons, spacing, headers).

---

## 14. AI Assessment
**Requirement:** Should work reliably at all times, with correct data, and consistent backend/Supabase wiring.

- [ ] 🔴 Confirm what "AI Assessment" pulls as input data — audit that the source tables/fields are the current, correct ones (not stale/deprecated fields from an earlier schema version).
- [ ] 🔴 Confirm the AI call itself (model, prompt, provider) uses the same shared AI-service pattern as AI Negotiator (§10) and Legal Help (§11) rather than a separate implementation that can silently break independently.
- [ ] 🟠 Add proper error handling/retry so a transient AI API failure shows a clear retry state instead of "not working."
- [ ] 🟠 **Supabase:** Confirm assessment results are persisted per-user (so results don't disappear/reset unexpectedly) with correct RLS.

---

## 15. Navigation Bar
**Bugs reported:** buttons not working across many pages; the profile icon area shows unwanted written text that should be removed (icon only).

**Frontend**
- [ ] 🔴 Audit the nav bar component itself — if it's one shared component, find why certain page contexts break its click handlers (commonly: a page-specific `z-index`/overlay stacking above the nav, or a route-specific wrapper that isn't passing router context correctly).
- [ ] 🔴 Remove the extra written profile text/label next to the profile avatar cutout — icon/avatar only, consistent with a clean nav pattern.
- [ ] 🟠 Confirm the SAME nav bar component is rendered on every page (this is likely the root cause if it "works on some pages but not others" — meaning it's not actually one shared component right now).

**Backend/Supabase**
- [ ] 🟠 Confirm nav-driven data (e.g. unread message count badge, notification count) pulls from the correct consistent source used in §4/§7, not a separate stale counter.

---

## 16. Profile & Account Verification
**Requirement:** Verification should work; profile should stay consistent with (and connected to) every other page that touches profile data (Roommate profile §3, Billing §12, etc.)

**Frontend**
- [ ] 🔴 Confirm the profile page renders the Roommate Profile card (see §3) using the same shared component — one profile, viewable/editable from two places, always in sync.
- [ ] 🔴 Confirm the Billing section (§12) renders here as specified.
- [ ] 🟠 Add a clear verification status indicator (e.g. "Verified" badge / "Verify your account" CTA) if not already present.

**Backend/API**
- [ ] 🔴 Confirm the account verification flow (email verification, ID verification, or whatever method is used) actually updates a `verified` flag on the user record on completion, and that flag is checked wherever verification gates access (e.g. maybe listing creation or messaging requires verification — confirm that gate is actually enforced).

**Supabase**
- [ ] 🔴 Confirm a single `profiles` table (1 row per user) is the join point for roommate profile data, verification status, and billing reference — audit for duplicate/fragmented user data tables that have crept in across features.
- [ ] 🟠 RLS: user can update their own profile; verification status field should only be writable by a trusted backend function/service role, never directly by the client (prevents users self-marking as verified).

---

## Cross-Cutting Consistency Checklist
Run this against the WHOLE app after individual modules are fixed:

- [ ] One shared message/chat component used everywhere messaging appears (§4, §5e, §6, §10).
- [ ] One shared profile data source (§3, §16) — no duplicate "profile" tables.
- [ ] One shared AI-service wrapper used by AI Negotiator, Legal Help, AI Assessment (§10, §11, §14) — same provider config, same error handling, same logging.
- [ ] One shared notifications table/system feeding Home badges, AI Notifications, Sublease interest alerts, and Nav bar counts (§1, §7, §9, §15).
- [ ] One shared form/input component library used across Add Property, Legal Help, Roommate Profile, Support Center (§3, §5, §11, §13).
- [ ] Consistent RLS pattern: every table follows the same "owner can read/write own rows, counterparty can read shared rows, no one else" logic — document this pattern once and check every table against it.
- [ ] Consistent status/enum naming across tables (e.g. don't have `status: 'active'` in one table and `is_active: true` in another for the same concept).
- [ ] Consistent loading/empty/error UI states across all pages (not just the ones that were visibly broken).

---

## Suggested Execution Order (by dependency, not just by severity)
1. **§16 Profile/Verification + §3 Roommate Profile** — foundational, other modules read from this.
2. **§4 Messaging split + §5e Message popup + §6 Other-user display** — one shared messaging fix covers three reported bugs at once.
3. **§5a–5d Listing/Add Property/Photos/Map** — core supply-side flow, blocks everything downstream (negotiator, sublease).
4. **§10 AI Negotiator** — biggest, most valuable, depends on messaging + listings being solid first.
5. **§7 AI Notifications + §9 Sublease reverse interest** — both are "surface an event the backend already half-produces."
6. **§8 Student Housing cascading filters**.
7. **§11 Legal Help, §14 AI Assessment** — consistency/polish once shared AI wrapper exists.
8. **§12 Pricing/Stripe + §13 Support Center + §15 Nav bar** — polish and account-management layer, do last so it reflects the now-stable feature set.

---

## Regression Checklist (fill in as each module is closed out)

| Module | Frontend Fixed | Backend Fixed | Supabase Fixed | Retested Cross-Module | Date |
|---|---|---|---|---|---|
| Home | ☐ | ☐ | ☐ | ☐ | |
| I Have a Space | ☐ | ☐ | ☐ | ☐ | |
| I Need a Roommate | ☐ | ☐ | ☐ | ☐ | |
| Messaging Split | ☐ | ☐ | ☐ | ☐ | |
| Listing/Add Property | ☐ | ☐ | ☐ | ☐ | |
| Photo Upload | ☐ | ☐ | ☐ | ☐ | |
| View Details Popup | ☐ | ☐ | ☐ | ☐ | |
| Map View | ☐ | ☐ | ☐ | ☐ | |
| Message Popup Layout | ☐ | ☐ | ☐ | ☐ | |
| AI Notifications | ☐ | ☐ | ☐ | ☐ | |
| Student Housing Filters | ☐ | ☐ | ☐ | ☐ | |
| Sublease Reverse Interest | ☐ | ☐ | ☐ | ☐ | |
| AI Negotiator | ☐ | ☐ | ☐ | ☐ | |
| Legal Help | ☐ | ☐ | ☐ | ☐ | |
| Pricing/Stripe/Billing | ☐ | ☐ | ☐ | ☐ | |
| Support Center | ☐ | ☐ | ☐ | ☐ | |
| AI Assessment | ☐ | ☐ | ☐ | ☐ | |
| Nav Bar | ☐ | ☐ | ☐ | ☐ | |
| Profile/Verification | ☐ | ☐ | ☐ | ☐ | |

