# Secret Rotation Checklist

Audit date: 2026-11-17  
Auditor: read-only automated scan of working tree + full git history  
Branch: `audit/secret-checklist`

---

## 1  Remote Visibility

| Remote | URL | Public? |
|--------|-----|---------|
| origin | `https://github.com/redhasanh1/RoomFinderAI.git` | **Yes — GitHub public repo.** Every credential ever committed is reachable by anyone via `git clone`. |

> **Implication:** rotating keys alone is not enough. After rotation, a history rewrite
> (`git filter-repo` or BFG Repo-Cleaner) followed by a force-push and fork
> invalidation is required to remove the plaintext blobs from reachable history.

---

## 2  Credential Inventory

### 2a  Credentials still present at HEAD

| # | File (at HEAD) | Provider | Credential type | First introduced | Notes |
|---|----------------|----------|-----------------|------------------|-------|
| H1 | `archive/legacy-android/android/app/src/main/java/com/roomfinderai/app/config/ApiConfig.java` | **OpenAI** | `sk-proj-…` API key | `1be7a98` 2026-07-01 | Real key, hardcoded constant |
| H2 | Same file | **Supabase** | Anon key (JWT `eyJhbG…`) + project URL | `1be7a98` 2026-07-01 | Grants anonymous read/write per RLS |
| H3 | Same file | **Google Maps** | `AIzaSy…` API key | `1be7a98` 2026-07-01 | Same key also in legacy server |
| H4 | Same file | **Stripe** | Publishable test key `pk_test_…` | `1be7a98` 2026-07-01 | Test-mode; still exposes account ID |
| H5 | Same file | **Brevo** | `xkeysib-…` API key | `1be7a98` 2026-07-01 | Full send-email permission |
| H6 | `archive/legacy-server/server.js` | **Google Maps** | `AIzaSy…` API key | `1be7a98` 2026-07-01 | Same key as H3 |
| H7 | `android/keystore.properties` | **Android signing** | `storePassword` + `keyPassword` | `d92ce56` 2026-11-01 | Plaintext passwords for release keystore |
| H8 | `android/roomfinder-release.jks` | **Android signing** | Binary Java Keystore (2.7 KB) | `d92ce56` 2026-11-01 | The actual signing key material |

### 2b  Credentials removed from HEAD but reachable in git history

| # | File (historical path) | Provider | Credential type | Commit introduced | Commit removed / cleaned |
|---|------------------------|----------|-----------------|-------------------|--------------------------|
| G1 | `backend/.env` | **Google / Payment** | `GOOGLE_API_KEY`, `MERCHANT_ID`, `API_KEY`, `API_SECRET`, `IPN_SECRET` | `916110b` 2025-06-17 | Deleted at `6db7e7a` 2025-07-04 |
| G2 | `RoomFinderAndroid/local.properties` | **OpenAI** | `sk-proj-…` API key (different key from H1) | `c3619e0` 2025-07-28 | Directory removed at `3ee62fb` 2026-10-28 |
| G3 | Same file | **Supabase** | Anon key (JWT) + project URL | `c3619e0` 2025-07-28 | Same removal |
| G4 | Same file | **Stripe** | `pk_test_…` + `sk_test_…` (secret key) | `c3619e0` 2025-07-28 | Same removal |
| G5 | Same file | **Brevo** | `xkeysib-…` API key | `c3619e0` 2025-07-28 | Same removal |
| G6 | Same file | **Google Maps** | `AIzaSy…` API key | `c3619e0` 2025-07-28 | Same removal |
| G7 | `RoomFinderAI-IOS/…/Secrets.swift` (multiple paths) | **OpenAI** | `sk-proj-…` API key | `aef3733` 2026-09-25 | Directory removed at `3ee62fb` |
| G8 | Same iOS files | **Supabase** | Anon key (JWT) | `aef3733` 2026-09-25 | Same removal |
| G9 | `RoomFinderAndroid/roomfinder-release.jks` | **Android signing** | Binary keystore | `aef3733` 2026-09-25 | Directory removed |

---

## 3  Rotation Order (highest blast radius first)

### Priority 1 — Supabase (anon key + service-role if shared)

| Step | Action | What breaks if skipped |
|------|--------|----------------------|
| 1 | Go to Supabase Dashboard → Settings → API → **Regenerate anon key** | Anyone with the leaked JWT can read/write any data allowed by RLS policies. This is the front door to your database. |
| 2 | Copy the new anon key | — |
| 3 | Update **Railway** env var `SUPABASE_ANON_KEY` (or `SUPABASE_KEY`) | Backend server.js loses DB access |
| 4 | Update `android/app/…/ApiKeys.java` fallback constant (currently empty — confirm it stays empty or uses BuildConfig) | Android app Supabase calls fail if fallback is used |
| 5 | Verify frontend fetches key from `/api/config` at runtime (already does) | — |
| 6 | If a `service_role` key was ever set via Railway env, regenerate it too (Dashboard → API → service_role → Regenerate) | Backend admin operations fail |
| 7 | Redeploy Railway | — |

### Priority 2 — OpenAI API key(s)

| Step | Action | What breaks if skipped |
|------|--------|----------------------|
| 1 | Go to [platform.openai.com/api-keys](https://platform.openai.com/api-keys) → **Revoke** every `sk-proj-…` key that appears in history (at least 2 distinct keys) | Attacker can run inference on your billing account |
| 2 | Create a new API key | — |
| 3 | Update **Railway** env var `OPENAI_API_KEY` | AI chat, negotiator daemon, ai-providers.js all fail |
| 4 | Redeploy Railway | — |

### Priority 3 — Stripe secret key

| Step | Action | What breaks if skipped |
|------|--------|----------------------|
| 1 | Go to Stripe Dashboard → Developers → API Keys → **Roll secret key** (`sk_test_…`) | Leaked secret key can create charges, refunds, read customer data |
| 2 | Also roll the publishable key (`pk_test_…`) if desired | Less critical but exposes account ID |
| 3 | Update **Railway** env vars `STRIPE_SECRET_KEY`, `STRIPE_PUBLISHABLE_KEY` | Subscription/payment endpoints fail |
| 4 | Redeploy Railway | — |

### Priority 4 — Brevo (Sendinblue) API key

| Step | Action | What breaks if skipped |
|------|--------|----------------------|
| 1 | Go to Brevo → Settings → API Keys → **Delete** the leaked key | Attacker can send email as your domain, read contacts |
| 2 | Create a new API key | — |
| 3 | Update **Railway** env var `BREVO_API_KEY` | Email verification, transactional emails fail |
| 4 | Redeploy Railway | — |

### Priority 5 — Google Maps / Google API key

| Step | Action | What breaks if skipped |
|------|--------|----------------------|
| 1 | Go to Google Cloud Console → APIs & Services → Credentials → **Delete or restrict** the leaked `AIzaSy…` key | Attacker can rack up Maps API charges |
| 2 | Create a new key with HTTP referrer / IP restrictions | — |
| 3 | Update **Railway** env var `GOOGLE_API_KEY` | Map tiles and geocoding fail on backend |
| 4 | Verify frontend loads map key from `/api/config` | — |
| 5 | Redeploy Railway | — |

### Priority 6 — Payment gateway credentials (from backend/.env history)

| Step | Action | What breaks if skipped |
|------|--------|----------------------|
| 1 | Identify the payment provider for `MERCHANT_ID`, `API_KEY`, `API_SECRET`, `IPN_SECRET` from commit `916110b` | Could allow fraudulent transactions |
| 2 | Rotate all four values in that provider's dashboard | — |
| 3 | Update **Railway** env vars if still in use | Payment processing fails |
| 4 | Redeploy Railway | — |

### Priority 7 — Android release signing key

| Step | Action | What breaks if skipped |
|------|--------|----------------------|
| 1 | **If using Google Play App Signing:** the upload key is compromised, but Google holds the real signing key. Request an upload key reset via Play Console → Setup → App signing → Request upload key reset | Attacker could sign APKs that look legitimate (upload key only if Play App Signing is enabled) |
| 2 | **If NOT using Play App Signing:** generate a new keystore, re-sign, and publish an update. Users will need to uninstall/reinstall. | Attacker can produce APKs signed with your key |
| 3 | Remove `android/keystore.properties` and `android/roomfinder-release.jks` from tracking: `git rm --cached` both files | Keeps leaking on every clone |
| 4 | Add to `.gitignore`: `android/keystore.properties`, `android/*.jks` | — |
| 5 | Store keystore and passwords in a secrets manager or CI-only variable | — |

---

## 4  Post-Rotation: History Cleanup

After **all** keys above are rotated:

1. Install `git filter-repo` (`pip install git-filter-repo`)
2. Run a path-based purge for every file that ever held secrets:
   ```
   git filter-repo --invert-paths \
     --path backend/.env \
     --path RoomFinderAndroid/local.properties \
     --path RoomFinderAndroid/roomfinder-release.jks \
     --path android/keystore.properties \
     --path android/roomfinder-release.jks
   ```
3. For files that must stay but had secrets in older versions (e.g., `ApiConfig.java`, `archive/legacy-server/server.js`), use blob-callback filtering or BFG `--replace-text` to scrub specific strings.
4. Force-push all branches: `git push --force --all && git push --force --tags`
5. Ask GitHub Support to run garbage collection on the repo to purge dangling objects.
6. Notify all collaborators to re-clone (force-push invalidates every existing clone's history).
7. If forks exist, they retain the old history — contact fork owners or consider making the repo private first.

---

## 5  Prevention Checklist

- [ ] `.gitignore` covers: `.env`, `*.jks`, `keystore.properties`, `local.properties`
- [ ] Pre-commit hook (`scripts/scan-secrets.cjs` from commit `91a7387`) is active via `git config core.hooksPath`
- [ ] No hardcoded keys remain in `archive/` — either remove the archive or replace keys with `process.env` references
- [ ] All secrets live exclusively in Railway environment variables
- [ ] GitHub branch protection requires status checks (including secret scan) to pass before merge
- [ ] Consider enabling GitHub Secret Scanning (free for public repos) for ongoing alerts

---

## 6  .gitignore Gaps Found

The current `.gitignore` includes `archive/legacy-android/android/keystore.properties` but is **missing**:

| Pattern to add | Reason |
|----------------|--------|
| `android/keystore.properties` | Currently tracked at HEAD |
| `android/*.jks` | Binary keystore tracked at HEAD |
| `**/local.properties` | Was committed historically; prevent recurrence |
| `**/Secrets.swift` | Was committed historically in iOS builds |

---

*End of checklist. No code was modified. No secrets were printed.*
