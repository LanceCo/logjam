# Logjam

A personal iOS app for tracking listens across a Discogs-imported vinyl collection. Single-user, no backend, no external accounts beyond Discogs and iCloud.

**Design north star:** Letterboxd — collection browsing + a lightweight, satisfying logging ritual per item.

## Tech Stack

- **UI:** Swift + SwiftUI, targeting iPhone and iPad (adaptive layout — grid/list on iPhone, consider split view or wider grids on iPad)
- **Persistence:** SwiftData with CloudKit sync (private database — data stays scoped to the user's own iCloud account, no shared/public containers)
- **Networking:** URLSession-based client for the Discogs API
- **Auth:** Discogs personal access token, entered once and stored in Keychain (not SwiftData, not plaintext)
- **Min iOS version:** Last 2 major iOS releases (update as new versions ship)
- **No backend server.** All API calls go directly from the app to Discogs.

## Core Features

### 1. Discogs Import & Sync
- Pull the user's Discogs collection via the Discogs API using their personal access token.
- **Exclude** formats: CD, Cassette, and any digital/file release types. Only vinyl formats (LP, 7", 10", 12", etc.) are imported.
- Re-sync should be idempotent: adding a release in Discogs adds it here; removing a release from the Discogs collection removes (or clearly marks removed) it here on next sync. Local log history for a removed release should be preserved, not deleted, unless the user explicitly deletes it.
- Sync should be user-triggerable (pull-to-refresh or a manual "Sync" action) — polling in the background is not required for a personal app but can be considered later.

### 2. Library Browse
- Default sort: by artist (last name convention, matching Discogs' own sort behavior — needs verification during implementation).
- Filters (combinable):
  - Genre
  - Format/type (7", 10", LP)
  - Listened / Not listened
- "Listened" status is derived from whether an album has at least one log entry (mirrors Letterboxd's watched-via-diary-entry model) — no separate manual toggle.
- Search bar (artist or album title) for direct lookup.
- A–Z index alongside the list (tap or drag, Contacts-app style) for quickly jumping to a section of the alphabetically-sorted library.

### 3. Album Detail Page
Pulled from Discogs, cached locally:
- Cover art
- Artist name
- Album title
- Year
- Genre (and style, if useful as secondary metadata)
- Tracklist
- Production credits

### 4. Logging
From the album detail page, the user can add one or more log entries:
- Date
- Star rating
- Heart ("loved this")

A log entry is a discrete event (like a Letterboxd diary entry) — an album can be logged multiple times across multiple listens.

Separately, each album carries a standing **Keep / Sell flag** on the album itself (not per log entry). It's settable from the album detail page and persists independently of logging activity.

### 5. Sell Queue
- A permanent view filtered to albums with the standing Keep/Sell flag set to "sell."
- Shows sale price info per release, sourced from Discogs' current marketplace stats (lowest listed price, number for sale) via the release marketplace stats endpoint — not a historical average, since Discogs' public API doesn't expose true historical sale averages.

### 6. Home (Profile-style landing screen)
Modeled on Letterboxd's profile page:
- Last 4 loved (hearted) albums, shown as cover art.
- A brief recent-activity feed: the last 5–10 log entries across the whole collection.

### 7. Diary
- Full chronological history of every log entry across the whole collection (not scoped to one album), newest first — mirrors Letterboxd's diary view.

## Non-Goals

- No multi-user support, accounts, or sharing features.
- No Android/cross-platform support.
- No custom backend/server component.
- No social features (this is explicitly not trying to be Letterboxd's social layer — just its logging/browsing UX pattern).

## Open Questions to Resolve During Implementation

- Exact Discogs API endpoints for: collection listing, release detail, marketplace stats — confirm rate limits and required auth scopes.
- Artist sort convention (e.g., "The Beatles" vs "Beatles, The") — match Discogs' own convention unless the user prefers otherwise.
