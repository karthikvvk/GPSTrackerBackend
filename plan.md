# UI-Only Plan (No Backend)

This project is **UI-first**.

- No Firebase / Supabase / real servers.
- Any “network calls” are represented as **localhost endpoints** (placeholder strings only).
- Any persistence is represented as **RoomDB-like structures** (i.e., local entities/DAOs), but **we will not implement** the DB layer yet—only the screens and fields.

## Product Goal
A clean, modern GPS tracking-style app UI that supports the full user flow and data fields, while remaining backend-agnostic.

## UX Principles
- Fast, uncluttered screens with generous spacing
- Clear hierarchy (title → key action → supporting info)
- Subtle motion (fade/slide transitions, AnimatedSwitcher)
- No outdated splash/ripple emphasis

## Information Architecture
### 1) Auth flow
- **Welcome**
  - CTA: Sign in
  - CTA: Create account
- **Sign in**
  - Fields: Email, Password
  - Action: Sign in
- **Sign up**
  - Fields: Full name, Email, Password, Confirm password
  - Action: Create account

> Auth is simulated with an in-memory session flag. No JWT logic is implemented.

### 2) Main app shell (Bottom tabs)
- **Dashboard**
  - “Today” status card
  - Quick actions: Start trip, Add device
  - Recent activity list (mock)
- **Trips**
  - List of trips (mock)
  - Trip details (route/map placeholder, stats)
- **Profile**
  - User summary
  - Settings tiles
  - Sign out

## Data Shapes (UI Models Only)
These are UI-facing models to keep fields consistent.

- User
  - id, fullName, email
- Device
  - id, name, vehiclePlate (optional), lastSeenAt, status
- Trip
  - id, title, startTime, endTime, distanceKm, avgSpeedKph

## “Localhost endpoints” (Placeholders)
Used only as labels / future integration points:
- POST http://localhost:8080/auth/login
- POST http://localhost:8080/auth/register
- GET  http://localhost:8080/trips
- GET  http://localhost:8080/devices

## Deliverables (UI)
- go_router-based navigation
- Modern component set (cards, buttons, list tiles)
- Responsive layouts (no overflow)
- Dummy/mock data displayed to validate field coverage

## Open Questions (Optional)
If you already have a stricter flow/field list, share it and we’ll align the UI models/screens 1:1.
