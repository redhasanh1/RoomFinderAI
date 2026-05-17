# LEARN.md — RoomFinderAI design log

Running notes on bugs we hit, what worked, what didn't, and what to remember next time. Newest entries on top.

---

## 2026-05-17 — Unwanted black backgrounds across the whole site

**Symptom:** Site rendered with near-black backgrounds and dark slate panels on every page, even though no commit had explicitly turned the site dark. Hasan reported "idk where the black background thing came from."

**Root cause:** Three CSS files contained `@media (prefers-color-scheme: dark)` blocks that auto-flipped colors when the browser detected the user's OS was in dark mode (Windows 11 default). The worst offender was `frontend/modules/css/variables.css` which inverted the entire `--color-gray-*` scale — so `--color-gray-50` became `#111827` (near-black) in dark mode. Anything using `var(--color-gray-50)` as a background went near-black. `frontend/css/ios-native.css` did the same for `--ios-background`, and `frontend/map-integration.css` darkened map popup styles.

**Fix:** Deleted all three dark-mode media query blocks (91 lines total) and added `color-scheme: light;` to `:root` in variables.css. The `color-scheme` declaration tells the browser the site is light-only, which also prevents the user agent from applying its own dark-mode adjustments to scrollbars and native form controls.

**What didn't apply:** No JS was toggling dark mode dynamically (grepped `prefers-color-scheme` across `frontend/**/*.{js,html}` — zero matches), and there was no `frontend/build/` directory with stale copies, so editing the three source files was sufficient.

**If we want a proper dark mode later:** Don't put it back via `prefers-color-scheme` alone — the gray-scale inversion in variables.css is too aggressive and breaks components that assume light grays. Add a `.dark` class toggled by a user-controlled switch, and define dark-mode variables under `:root.dark`. Then the user opts in instead of inheriting the OS preference.
