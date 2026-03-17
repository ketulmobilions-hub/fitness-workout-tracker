# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Fitness & workout tracker app — custom workout plans, exercise logging, progress photos, streak tracking, social sharing, and health API integration. Freemium model, solo developer.

## Tech Stack

### Frontend: Flutter
- **State management:** Riverpod + riverpod_generator (NOT Bloc)
- **Data classes:** Freezed + json_serializable
- **Local DB:** Drift (SQLite) — mirrors PostgreSQL schema for offline-first
- **HTTP:** Dio + Retrofit (typed API clients)
- **Notifications:** firebase_messaging
- **Health:** `health` package (Apple Health + Google Fit)

### Backend: Node.js + TypeScript
- **Framework:** Express
- **ORM:** Prisma (schema-first, manages migrations)
- **Auth:** JWT + Passport.js (email/password, Google, Apple, guest mode)
- **Real-time:** Socket.IO
- **Background jobs:** BullMQ
- **Validation:** Zod

### Infrastructure
- **Database:** PostgreSQL (primary) + Redis (cache/real-time)
- **Hosting:** Render (MVP) → AWS ECS Fargate (scale)
- **File storage:** AWS S3 + CloudFront CDN + Sharp (image processing)
- **Push:** Firebase Cloud Messaging
- **Monitoring:** Sentry

## Flutter Architecture (VGV Layered Pattern)

Follows the [Very Good Ventures layered architecture](https://verygood.ventures/blog/very-good-flutter-architecture/), adapted to use Riverpod instead of BLoC.

### Four Layers (strict dependency order)

```
Presentation → Business Logic → Domain → Data
```

Each layer may ONLY depend on its direct neighbor. Never skip layers.

| Layer | Responsibility | Package |
|-------|---------------|---------|
| **Data** | Raw API calls, HTTP, device APIs, Drift DB access | Separate Dart package |
| **Domain** | Transform raw data into domain models, business rules | Separate Dart package |
| **Business Logic** | State management (Riverpod providers), orchestrates data flow | Main app |
| **Presentation** | Widgets, pages, UI rendering, event triggering | Main app |

### Rules
- **Presentation must NEVER** call the Data layer directly or contain data-fetching logic
- **Widgets must contain ZERO** data or domain interactions
- **Data and Domain layers** are isolated as separate Dart packages
- Features use **feature-based folder organization**:
  ```
  lib/
  ├── feature_name/
  │   ├── providers/        # Riverpod providers (business logic)
  │   ├── models/           # Domain models (if feature-specific)
  │   ├── view/             # Pages
  │   ├── widgets/          # Feature widgets
  │   └── feature_name.dart # Barrel file
  ├── app.dart
  └── main.dart
  ```

### Riverpod as Business Logic Layer
Riverpod replaces BLoC in the VGV pattern. Providers manage immutable state, react to UI input, and call repositories. Cross-domain dependencies use `ref.watch`. `StreamProvider` for real-time data. `keepAlive` + custom cache layers for offline data.

## Cross-Cutting Architecture

### Monorepo Layout
```
/
├── app/          # Flutter app
│   └── packages/ # Separate Dart packages (data layer, domain layer)
└── server/       # Node.js + Express API
```

### Offline-First Sync Pattern
The app must work offline. Local changes are queued in Drift (SQLite), pushed to server when online, then server changes are pulled. Drift is the source of truth on the client; PostgreSQL is the source of truth on the server. **Conflict resolution: last-write-wins** (using `updated_at` timestamps).

### Auth Flow
JWT-based stateless auth. Guest mode uses anonymous JWTs with limited permissions, upgradeable to full accounts without data loss.

### Photo Pipeline
Client uploads directly to S3 via pre-signed URLs (no file data through API server). Server-side Sharp processing generates thumbnails (150px list, 600px feed, full-res) and compresses to WebP.

## Development Workflow (Mandatory)

After completing **every feature**, the following 3-step review flow is **strictly required** before merging. Do not skip any step.

### Step 1 — Developer Explanation

Immediately after finishing a feature, provide a detailed explanation:

1. **What was done, why, and how** — describe the feature, its purpose, and the approach taken
2. **List ALL created/modified files** with a one-line purpose for each
3. **Explain the complete data flow** through the system (e.g., UI → Provider → Repository → API/DB and back)
4. **Wait for the user to review** before proceeding to Step 2

### Step 2 — Code Review

After the user has reviewed Step 1:

1. **Run a code reviewer agent** to audit all feature code
2. **List ALL issues found** with their respective file names
3. **For each issue:** explain what it is, why it's a problem, and give a **real-world example** of the consequence if left unfixed
4. **Present the full list** to the user and **wait** for their decision

### Step 3 — Fix Approved Issues

After the user has reviewed Step 2:

1. The user decides **which issues to fix** — fix only those
2. Do NOT fix issues the user has not approved
3. If fixes are substantial (new files, significant logic changes), **repeat from Step 1** for the fixes

---

## Implementation Phases

**Phase 1 (MVP):** Auth, exercise database, workout plan creation, workout logging (strength + cardio), basic progress charts, streaks, offline-first sync, user profile.

**Phase 2 (Retention):** Progress photos, body measurements, pre-built templates, rest timer, push notifications, health API integration, supersets/circuits.

**Phase 3 (Growth):** Social feed, follows, likes/comments, plan sharing, gamification (badges/XP/leaderboards), real-time features, freemium paywall, web dashboard.

## Git Workflow (Strict)

Two permanent branches: `main` and `dev`.

```
main ← dev ← feature/*
```

- **`main`:** Production-stable. Only receives merges from `dev` when a full phase is complete.
- **`dev`:** Active development. All feature branches merge here.
- **`feature/*`:** Created from `dev` for every new feature. Merged back into `dev` when done.

### Rules
1. **Every new feature** gets its own branch off `dev` (e.g., `feature/auth`, `feature/workout-logging`)
2. **Never commit directly** to `main` or `dev` — always use a feature branch
3. **Merge feature → dev** when the feature is complete
4. **Merge dev → main** only when an entire phase is complete (Phase 1, Phase 2, Phase 3)
5. **Never merge feature branches directly into main**

## API Conventions

### URL Structure
```
/api/v1/{resource}          # Collection (GET list, POST create)
/api/v1/{resource}/:id      # Item (GET, PATCH, DELETE)
/api/v1/{resource}/:id/{sub} # Nested resources
```
- Plural nouns for resources (e.g., `/api/v1/workouts`, `/api/v1/exercises`)
- API versioning via URL prefix (`/api/v1/`)
- Use PATCH for partial updates, PUT for full replacement

### Error Response Format (RFC 7807)
```json
{
  "status": 422,
  "error": "Unprocessable Entity",
  "message": "Validation failed",
  "details": [
    { "field": "email", "message": "must be a valid email address" }
  ]
}
```

### Pagination (cursor-based)
```json
{
  "data": [...],
  "pagination": {
    "next_cursor": "abc123",
    "has_more": true,
    "limit": 20
  }
}
```
Default limit: 20, max: 100. Use cursor-based pagination (not offset) for stable results with real-time data.

## Testing Strategy

### Flutter (Extensive)
- **Unit tests:** All providers, repositories, domain logic, sync engine, streak calculations
- **Widget tests:** Every screen/page and reusable widget
- **Integration tests:** Critical flows (sign up → create plan → log workout → see progress)
- Test framework: `flutter_test`, `mocktail` for mocks

### Backend (Extensive)
- **Unit tests:** All service functions, validation, business logic, auth middleware
- **Integration tests:** All API endpoints against real test database
- Test framework: `jest` (or `vitest`), `supertest` for HTTP testing

## CI/CD

GitHub Actions pipeline on every push and PR:
- **Flutter:** analyze → test → build
- **Backend:** lint → test → build
- Runs against both `app/` and `server/` directories

## MVP Database Schema (PostgreSQL)

```sql
-- Users & Auth
users (id, email, password_hash, display_name, avatar_url, auth_provider, is_guest, preferences JSONB, created_at, updated_at)

-- Exercise Library
muscle_groups (id, name, display_name, body_region)
exercises (id, name, description, exercise_type ENUM[strength,cardio,stretching], instructions TEXT, media_url, created_by, is_custom BOOLEAN, created_at, updated_at)
exercise_muscle_groups (exercise_id, muscle_group_id, is_primary BOOLEAN)

-- Workout Plans
workout_plans (id, user_id, name, description, is_active BOOLEAN, schedule_type ENUM[weekly,recurring], weeks_count, created_at, updated_at)
plan_days (id, plan_id, day_of_week INT, week_number INT, name, sort_order)
plan_day_exercises (id, plan_day_id, exercise_id, sort_order, target_sets INT, target_reps VARCHAR, target_duration_sec INT, target_distance_m FLOAT, notes)

-- Workout Logging
workout_sessions (id, user_id, plan_id, plan_day_id, started_at, completed_at, duration_sec INT, notes, status ENUM[in_progress,completed,abandoned], created_at, updated_at)
exercise_logs (id, session_id, exercise_id, sort_order, notes, created_at)
set_logs (id, exercise_log_id, set_number INT, reps INT, weight_kg FLOAT, duration_sec INT, distance_m FLOAT, pace_sec_per_km FLOAT, heart_rate INT, rpe INT, tempo VARCHAR, is_warmup BOOLEAN, completed_at)

-- Progress & Streaks
personal_records (id, user_id, exercise_id, record_type ENUM[max_weight,max_reps,max_volume,best_pace], value FLOAT, achieved_at, session_id)
streaks (id, user_id, current_streak INT, longest_streak INT, last_workout_date DATE, updated_at)
streak_history (id, user_id, date DATE, status ENUM[completed,rest_day,missed])

-- Sync
sync_queue (id, user_id, table_name, record_id, operation ENUM[create,update,delete], payload JSONB, created_at, synced_at)
```

All tables include `id` (UUID), `created_at`, `updated_at` unless noted. Every mutable table has `updated_at` for last-write-wins conflict resolution.

## Key Design Decisions

- **Riverpod over Bloc:** ~15 interacting data domains make Bloc's inter-bloc communication unwieldy; Riverpod's `ref.watch` handles this naturally
- **Drift over other local DBs:** Typed SQL, compile-time verification, reactive streams that pair with Riverpod, supports migrations
- **Prisma over other ORMs:** Type-safe queries matching TypeScript, schema-first approach keeps DB and code in sync
- **Containerize from day 1** (Docker) to simplify Render → AWS migration later
- **App is source of truth** for health data when syncing with Apple Health / Google Fit

## Performance Targets

- App launch to usable: < 2s
- Workout logging (offline): < 100ms per action
- Sync after reconnect: < 5s for typical session
- Photo upload: < 3s (pre-signed URL direct to S3)
- API response times: < 200ms p95
