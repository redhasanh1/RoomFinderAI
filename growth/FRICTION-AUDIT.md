# What a landlord has to do today to post one room

Measured from the code, not guessed. Source: `backend/server.js`
`validateListingInput()` (line 711) and `POST /api/listings` (line 725).

## The current funnel

1. Land on roomfinderai.com
2. **Create an account** — `POST /api/listings` returns
   `401 User authentication required` if `userEmail` is absent. There is no
   way to post without signing up first.
3. Fill **8 mandatory fields**:

   | Field | Required | Effort |
   |---|---|---|
   | `city` | yes | trivial |
   | `street` | yes | trivial |
   | `postalCode` | yes | trivial |
   | `title` | yes | **writing** |
   | `price` | yes | **a decision — what is it worth?** |
   | `houseType` | yes | trivial |
   | `bedrooms` | yes | trivial |
   | `utilities` | yes, must be exactly "included"/"not included" | trivial |
   | `description` | no | **writing** |
   | `media` | no | photos |

4. Upload photos
5. Submit

## Why this matters more than any incentive

A landlord who has never heard of RoomFinderAI is being asked to open an
account and complete an eight-field form, on a promise of tenants we cannot
yet prove we deliver. Every incentive we design has to be paid out *after*
that wall.

The two fields that cost real effort are the two that require thought rather
than typing: **the title** and **the price**. Those are exactly what an AI
listing feature removes. That is the hypothesis worth testing — not because
"AI" is fashionable, but because it deletes the only two hard fields in the
form.

The account wall is the other half. "Post a room in 30 seconds, no sign-up"
is a stronger sentence than most cash incentives, and it costs nothing per
landlord.

## Open questions the research agents are answering

- Is listing-writing genuinely a top pain for small landlords, or are we
  solving something they do not care about?
- Is there a stronger hook than listing generation (screening, inquiry
  handling, pricing)?
- What has actually worked for other marketplaces at cold start?
