# Production TODO - Hidden Features to Re-enable Later

These features are currently hidden on the home page (index.html) during development.
To re-enable, search for `HIDDEN FOR DEVELOPMENT` comments and remove `style="display: none !important;"`.

## Hidden Sections in index.html

### Feature Cards (in Features Section)
1. **Sublease Finder Card** (~line 1664)
   - Location: Features grid section
   - Search: `HIDDEN FOR DEVELOPMENT: Sublease Finder Card`

2. **Mortgage Calculator Card** (~line 1698)
   - Location: Features grid section
   - Search: `HIDDEN FOR DEVELOPMENT: Mortgage Calculator Card`

### Complete Housing Solutions Section Cards
3. **Student Housing Center Card** (~line 1741)
   - Location: Three Main Service Cards grid
   - Search: `HIDDEN FOR DEVELOPMENT: Student Housing Card`

4. **Mortgage Intelligence Hub Card** (~line 1836)
   - Location: Three Main Service Cards grid
   - Search: `HIDDEN FOR DEVELOPMENT: Mortgage Intelligence Hub Card`

### Full Sections
5. **Mortgage Intelligence Section** (~line 1892)
   - Full section with rate analysis, calculator demo
   - Search: `HIDDEN FOR DEVELOPMENT: Enhanced Mortgage Intelligence Section`

6. **AI Search Demo Section** (~line 2038)
   - "See RoomFinderAI in Action" with AI search input and negotiation preview
   - Search: `HIDDEN FOR DEVELOPMENT: Interactive Demo Section (AI Search)`

7. **Browse Our Listings CTA Section** (~line 2110)
   - Simple CTA section linking to listings page
   - Search: `HIDDEN FOR DEVELOPMENT: Browse Listings CTA Section`

8. **RoomPal Preview Section** (~line 2121)
   - Roommate matching preview with swipe demo
   - Search: `HIDDEN FOR DEVELOPMENT: RoomPal Preview Section`

### Navigation Items
9. **Desktop Browse Dropdown** (~line 1407-1409)
   - Hidden: Sublease Property, Student Housing

10. **Desktop Tools Dropdown** (~line 1421-1422)
    - Hidden: Mortgage Tools

11. **Mobile Browse Section** (~line 1484-1486)
    - Hidden: Sublease Property, Student Housing

12. **Mobile Tools Section** (~line 1498-1499)
    - Hidden: Mortgage Tools

### Footer Links
13. **Footer Tools Section** (~line 2281-2283)
    - Hidden: Mortgage Calculator, Sublease

---

## How to Re-enable

1. Open `frontend/index.html`
2. Search for `HIDDEN FOR DEVELOPMENT`
3. Remove `style="display: none !important;"` from each element
4. Remove/update the `HIDDEN FOR DEVELOPMENT` comments

## Notes
- All hidden elements use `style="display: none !important;"` for easy toggling
- Features were hidden to focus on core functionality during development
- Re-enable when these features are ready for production
