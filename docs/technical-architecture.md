# Fitness Workout Tracker — Technical Architecture

> Authoritative reference for every design decision, every layer, every component. Written after Phase 1 (MVP) completion.

---

## Table of Contents

1. [Project Overview](#1-project-overview)
2. [Monorepo Layout](#2-monorepo-layout)
3. [Flutter Architecture — VGV Four-Layer Pattern](#3-flutter-architecture--vgv-four-layer-pattern)
4. [State Management — Riverpod](#4-state-management--riverpod)
5. [Navigation — GoRouter](#5-navigation--gorouter)
6. [HTTP Layer — Dio + Retrofit](#6-http-layer--dio--retrofit)
7. [Local Database — Drift / SQLite](#7-local-database--drift--sqlite)
8. [Offline-First Sync Engine](#8-offline-first-sync-engine)
9. [Authentication — Flutter Side](#9-authentication--flutter-side)
10. [Backend Architecture — Node.js + Express](#10-backend-architecture--nodejs--express)
11. [Database Schema — PostgreSQL + Prisma](#11-database-schema--postgresql--prisma)
12. [Authentication — Server Side](#12-authentication--server-side)
13. [API Design](#13-api-design)
14. [Validation — Zod](#14-validation--zod)
15. [Rate Limiting](#15-rate-limiting)
16. [Error Handling](#16-error-handling)
17. [Background Jobs — BullMQ](#17-background-jobs--bullmq)
18. [Code Generation](#18-code-generation)
19. [Infrastructure & Deployment](#19-infrastructure--deployment)
20. [Security Measures](#20-security-measures)
21. [CI/CD Pipelines](#21-cicd-pipelines)
22. [Performance Targets](#22-performance-targets)
23. [Key Files Reference](#23-key-files-reference)

---

## 1. Project Overview

**What:** A fitness and workout tracking app. Users build workout plans, log sessions, track personal records, monitor streaks, and view progress charts.

**Business model:** Freemium. Phase 1 is fully free (MVP). Phase 3 adds a paywall.

**Phases:**
- **Phase 1 (MVP) — complete:** Auth, exercise database, workout plan builder, session logging (strength + cardio), progress charts, streak tracking, offline-first sync, user profile.
- **Phase 2 (Retention):** Progress photos, body measurements, pre-built templates, rest timer, push notifications, health API integration (Apple Health / Google Fit), supersets/circuits.
- **Phase 3 (Growth):** Social feed, follows, likes/comments, plan sharing, gamification (badges/XP/leaderboards), real-time features, freemium paywall, web dashboard.

**Stack summary:**
- Frontend: Flutter (iOS + Android)
- Backend: Node.js + TypeScript + Express
- Database: PostgreSQL (server) + SQLite via Drift (client)
- Cache / Queue: Redis + BullMQ
- Hosting: Render (MVP) → AWS ECS Fargate (scale)

---

## 2. Monorepo Layout

```
fitness_workout_tracker/
├── app/                          # Flutter mobile app
│   ├── lib/                      # Main app code (presentation + business logic)
│   ├── packages/
│   │   ├── fitness_domain/       # Domain models + repository interfaces
│   │   └── fitness_data/         # API clients, DTOs, Drift DB, DAOs
│   ├── android/
│   ├── ios/
│   └── pubspec.yaml
├── server/                       # Node.js + Express API
│   ├── src/                      # TypeScript source
│   ├── prisma/                   # Schema, migrations, seed
│   ├── Dockerfile
│   └── package.json
├── docs/                         # Internal documentation (not git-tracked)
├── .github/workflows/            # CI/CD pipelines
├── render.yaml                   # Render Blueprint (IaC)
└── CLAUDE.md                     # Development guide for Claude Code
```

**Why a monorepo?** Single repo for the mobile app + API keeps issues, PRs, and CI in one place for a solo developer. No cross-repo coordination overhead.

---

## 3. Flutter Architecture — VGV Four-Layer Pattern

Follows the [Very Good Ventures layered architecture](https://verygood.ventures/blog/very-good-flutter-architecture/), adapted to use Riverpod instead of BLoC.

### Layer Diagram

```
┌──────────────────────────────────────┐
│           PRESENTATION               │  Widgets, Pages, UI rendering
│  (main app — lib/features/*/view)    │
├──────────────────────────────────────┤
│         BUSINESS LOGIC               │  Riverpod providers, state management
│  (main app — lib/features/*/providers│  orchestrates data flow
├──────────────────────────────────────┤
│             DOMAIN                   │  Domain models (Freezed), repository
│  (packages/fitness_domain)           │  interfaces, pure business rules
├──────────────────────────────────────┤
│              DATA                    │  API clients (Retrofit), DTOs,
│  (packages/fitness_data)             │  Drift DB, DAOs, mappers
└──────────────────────────────────────┘
```

**Strict dependency rule:** Each layer may only depend on its direct neighbor downward. Presentation never touches Data directly.

### Why this architecture?

- **Testability:** Each layer can be tested in isolation. Domain and Data have no Flutter dependencies.
- **Scalability:** Features can be added without touching other features.
- **Separation of concerns:** UI code never contains fetching logic; data code never contains rendering logic.
- **Why Riverpod over BLoC:** With ~15 interacting data domains (auth, exercises, plans, sessions, progress, streaks, sync, profile, connectivity, theme, etc.), BLoC's inter-bloc communication via StreamSubscriptions becomes unwieldy. Riverpod's `ref.watch` expresses these dependencies declaratively with compile-time safety.

### Package Roles

| Package | Layer | Responsibilities |
|---------|-------|-----------------|
| `fitness_domain` | Domain | Freezed immutable models, repository interfaces (abstract), enums. Zero Flutter or network dependencies. |
| `fitness_data` | Data | Implements domain interfaces. Contains Retrofit API clients, Freezed+json DTOs, Drift tables/DAOs, type converters, mappers. |
| Main app `lib/` | Business Logic + Presentation | Riverpod providers (business logic), all screens/widgets (presentation). |

### Feature Folder Structure (inside main app)

```
lib/features/auth/
├── data/
│   └── auth_repository_impl.dart    # Implements domain interface
├── presentation/
│   ├── screens/                     # Full pages
│   └── widgets/                     # Feature-specific widgets
└── providers/
    ├── auth_notifier.dart            # State notifier
    ├── auth_state.dart               # Freezed state union
    └── auth_providers.dart           # Provider definitions
```

---

## 4. State Management — Riverpod

All providers use `@Riverpod` annotation and are code-generated via `riverpod_generator`.

### Provider Types in Use

| Type | Used For | Example |
|------|----------|---------|
| `@Riverpod(keepAlive: true)` | Long-lived singletons | `dioProvider`, `appDatabaseProvider`, `authTokenProvider` |
| `Notifier` | Mutable state with methods | `AuthNotifier`, `ActiveSessionNotifier`, `SyncNotifier` |
| `AsyncNotifier` | Async mutable state | Form submission notifiers |
| `StreamProvider` | Reactive DB streams | `planListProvider`, `exerciseListProvider` |
| `FutureProvider` | One-shot async data | `exerciseDetailProvider` |

### Key Patterns

**`keepAlive: true`** — prevents Riverpod from disposing providers when no widget is listening. Used on all infrastructure providers that hold connections (Dio, Drift, secure storage) and on auth/sync notifiers that must run continuously.

**Repository streams → `AsyncValue<T>`** — repositories expose `watch()` methods that return Dart `Stream<T>`. Providers convert these to `AsyncValue<T>`, giving widgets a tri-state (loading / data / error) with zero boilerplate.

**Form providers** — each form (login, register, forgot password, plan form, etc.) has a dedicated Freezed state holding field values + `isLoading` + error messages. This keeps form state isolated from global state.

**`ref.watch` for cross-domain dependencies** — e.g., `activeSessionProvider` watches `authTokenProvider` and `dioProvider`. When auth changes, session provider automatically rebuilds. This replaces BLoC's stream subscriptions.

**Cache invalidation** — `ref.invalidate(planListProvider)` or `.refresh()` forces a fresh fetch. Used after create/update/delete operations.

### AuthState Sealed Union

```dart
@freezed
sealed class AuthState with _$AuthState {
  const factory AuthState.initializing()         = AuthInitializing;
  const factory AuthState.unauthenticated()      = AuthUnauthenticated;
  const factory AuthState.loading()              = AuthLoading;
  const factory AuthState.authenticated(AuthUser user) = Authenticated;
  const factory AuthState.guest(AuthUser user)   = AuthGuest;
}
```

The router listens to this union to drive auth redirects.

---

## 5. Navigation — GoRouter

### Route Structure

```
/                               → SplashScreen (loading)
/auth/login                     → LoginScreen
/auth/register                  → RegisterScreen
/auth/forgot-password           → ForgotPasswordScreen
/auth/reset-password?token=...  → ResetPasswordScreen

[StatefulShellRoute — bottom nav]
  /home                         → HomeScreen (dashboard)
  /plans                        → PlanListScreen
  /progress                     → ProgressDashboardScreen
  /profile                      → ProfileScreen

[Full-screen routes — above shell]
  /exercises                    → ExerciseListScreen
  /exercises/create             → CreateExerciseScreen
  /exercises/:exerciseId        → ExerciseDetailScreen
  /plans/create                 → PlanFormScreen (create)
  /plans/:planId                → PlanDetailScreen
  /plans/:planId/edit           → PlanFormScreen (edit)
  /workout/active               → ActiveWorkoutScreen
  /workout/summary              → WorkoutSummaryScreen
  /history                      → WorkoutHistoryScreen
  /history/:sessionId           → SessionDetailScreen
  /progress/exercises/:exerciseId?name=... → ExerciseProgressScreen
  /streak                       → StreakDetailScreen
  /profile/edit                 → EditProfileScreen
  /settings                     → SettingsScreen
```

### Auth Redirect Logic

```dart
// resolveAuthRedirect — called on every navigation attempt
AuthInitializing | AuthLoading  → no redirect (show loading)
AuthUnauthenticated + not on /auth/* → redirect to /auth/login
Authenticated | AuthGuest + on /auth/* → redirect to /home
Otherwise → allow navigation
```

The router registers a `ValueNotifier` listener on `authNotifier`, triggering `router.refresh()` on every auth state change. This means screens navigate automatically when the user logs in or out — no manual `Navigator.push`.

### Key Design Decisions

- **StatefulShellRoute** with 4 branch navigator keys — each bottom-nav tab maintains its own navigation stack. Tapping Plans while on a plan detail keeps that detail in the stack when switching back.
- **Root navigator key** for full-screen routes — active workout screen appears above the shell (no bottom nav visible during a session).
- **`app_routes.dart` constants** — route paths are compile-time constants with helper functions (e.g., `planDetailPath(id)`). Prevents typos from string literals scattered across the codebase.

---

## 6. HTTP Layer — Dio + Retrofit

### Interceptor Chain (order matters)

```
Request
  ↓ AuthInterceptor       — waits for auth token, attaches "Bearer <accessToken>"
  ↓ LoggingInterceptor    — debug-only, logs requests/responses, redacts auth headers
  ↓ ErrorInterceptor      — maps Dio exceptions to AppException sealed class
  ↓ RefreshInterceptor    — on 401: refresh token, retry original request
  ↓ [server]
  ↑ (response travels back up the chain)
```

### RefreshInterceptor Detail

On a 401 response:
1. Uses an **inner Dio instance** (identical config but without `RefreshInterceptor`) to call `POST /auth/refresh`. This prevents infinite recursion if the refresh endpoint itself returns 401.
2. Parses new `accessToken` and `refreshToken` from the response.
3. Calls `authTokenProvider.notifier.setTokens(...)` to persist to `FlutterSecureStorage`.
4. Retries the original request with the new `accessToken`.
5. If refresh fails (refresh token expired or revoked) → clears tokens → `authNotifier` transitions to `AuthUnauthenticated` → router redirects to login.

### AppException Sealed Class

```dart
@freezed
sealed class AppException with _$AppException {
  const factory AppException.unauthorized(String message)  = UnauthorizedException;
  const factory AppException.forbidden(String message)     = ForbiddenException;
  const factory AppException.notFound(String message)      = NotFoundException;
  const factory AppException.conflict(String message)      = ConflictException;
  const factory AppException.badRequest(String message)    = BadRequestException;
  const factory AppException.cancelled()                   = CancelledException;
  const factory AppException.unknown(String message)       = UnknownException;
}
```

UI code pattern-matches on this sealed class to show appropriate error messages.

### Retrofit API Clients (8 total)

| Client | Base Path | Purpose |
|--------|-----------|---------|
| `AuthApiClient` | `/auth` | Login, register, refresh, OAuth, guest |
| `PlanApiClient` | `/api/v1/plans` | Workout plan CRUD + exercises |
| `ExerciseApiClient` | `/api/v1/exercises` | Exercise library + muscle groups |
| `SessionApiClient` | `/api/v1/sessions` | Session start/log/complete |
| `ProgressApiClient` | `/api/v1/progress` | Charts, PRs, volume |
| `StreakApiClient` | `/api/v1/streaks` | Streak + history |
| `UserApiClient` | `/api/v1/users` | Profile CRUD |
| `SyncApiClient` | `/api/v1/sync` | Push/pull offline sync |

Each client is a `@RestApi`-annotated abstract class. `retrofit_generator` generates the Dio implementation at build time, giving fully typed request/response methods.

---

## 7. Local Database — Drift / SQLite

Drift is the offline-first local database. It mirrors the PostgreSQL schema structure and is the **source of truth on the client** — all reads and writes go through Drift first; the server gets changes via the sync engine.

**Why Drift over other local DBs:**
- Typed SQL with compile-time verification (Dart type system catches query errors before runtime)
- Reactive streams via `watchSingle()` / `watch()` — integrate natively with Riverpod `StreamProvider`
- Code-generated DAOs: no raw SQL strings in business logic
- Supports schema migrations (version-based, similar to Prisma)

### Tables (13 total)

| Table | Key Fields | Notes |
|-------|-----------|-------|
| `Users` | id, email, displayName, authProvider, isGuest, preferences (JSON) | One row per logged-in user |
| `MuscleGroups` | id, name, displayName, bodyRegion | Seeded from server on first sync |
| `Exercises` | id, name, exerciseType, isCustom, createdBy | Includes user-created custom exercises |
| `ExerciseMuscleGroups` | exerciseId, muscleGroupId, isPrimary | Composite PK join table |
| `WorkoutPlans` | id, userId, name, scheduleType, weeksCount, isActive | scheduleType: weekly \| recurring |
| `PlanDays` | id, planId, dayOfWeek, weekNumber, sortOrder | weekNumber null for weekly plans |
| `PlanDayExercises` | id, planDayId, exerciseId, targetSets, targetReps, targetDurationSec | targetReps stored as text: "8" or "8-12" |
| `WorkoutSessions` | id, userId, planId, startedAt, completedAt, status | status: in_progress \| completed \| abandoned |
| `ExerciseLogs` | id, sessionId, exerciseId, sortOrder | One row per exercise within a session |
| `SetLogs` | id, exerciseLogId, setNumber, reps, weightKg, durationSec, distanceM, paceSecPerKm, heartRate, rpe, tempo, isWarmup | All metric fields nullable — only relevant ones populated per exercise type |
| `PersonalRecords` | id, userId, exerciseId, recordType, value, achievedAt | recordType: max_weight \| max_reps \| max_volume \| best_pace |
| `Streaks` | id, userId, currentStreak, longestStreak, lastWorkoutDate | One row per user |
| `StreakHistory` | id, userId, date, status | UNIQUE(userId, date); status: completed \| missed \| pending |
| `SyncQueue` | id, userId, entityTable, recordId, operation, payload (JSON), retryCount, lastError | Offline write queue |

### Schema Version & Migrations

- **Version 1:** Initial schema
- **Version 2:** Added `createdAt`/`updatedAt` to `PlanDays` and `PlanDayExercises`

Migrations are defined in `AppDatabase`'s `migration` getter using Drift's `Migrator`.

### DAOs (6 total)

| DAO | Key Methods |
|-----|-------------|
| `UserDao` | `getUser(id)`, `upsertUser(companion)`, `watchUser(id)` |
| `ExerciseDao` | `watchExercisesFiltered(search, type, muscleGroup)`, `watchExercise(id)`, `upsertExercise()`, `upsertMuscleGroup()`, transaction support |
| `WorkoutPlanDao` | `watchPlansForUser(userId)`, `watchPlan(id)`, `upsertPlan()`, `upsertPlanDay()`, `upsertPlanDayExercise()` |
| `WorkoutSessionDao` | `watchSessionsForUser(userId, filters)`, `watchSession(id)`, `getPreviousSets(exerciseId)`, `upsertSession()`, `upsertSetLog()`, `completeSession()` |
| `ProgressDao` | `getPersonalRecords(userId, exerciseId)`, `getExerciseHistory(exerciseId, from, to)` |
| `SyncQueueDao` | `getPendingItems(userId)`, `pendingCount(userId)`, `enqueue(companion)`, `markSynced(id)`, `markFailed(id, error)` |

### Type Converters

Drift stores all values as SQL primitives (text, int, real, blob). Custom converters handle:
- Enums → stored as text strings (e.g., `ExerciseTypeConverter`, `SessionStatusConverter`)
- JSON objects → stored as JSON text strings (`JsonStringConverter`)
- `DateTime` → stored as ISO 8601 text (`DateStringConverter`)

---

## 8. Offline-First Sync Engine

**Location:** `app/lib/core/sync/sync_service.dart`

### Philosophy

The app must work 100% offline. Every user action writes to Drift immediately (optimistic update — no loading spinner for local writes). The sync engine runs in the background to reconcile local state with the server.

**Conflict resolution: last-write-wins** using `updated_at` timestamps. This is the simplest correct strategy for solo-user fitness data — there is no scenario where two conflicting edits to the same workout need a three-way merge.

### Sync Triggers (4)

| Trigger | When | Action |
|---------|------|--------|
| Login | User authenticates | `performInitialSync()` — full pull from server |
| Connectivity restore | Device comes back online | Debounced 2 seconds, then `triggerSync()` |
| App resume | App brought to foreground | `triggerSync()` if connected |
| Periodic timer | Every 5 minutes if connected | `triggerSync()` |

### Two-Phase Sync

**Phase 1 — Push (client → server):**
1. Query `SyncQueueDao.getPendingItems(userId)` — items with `syncedAt == null`
2. Filter out items still in backoff window (see retry logic)
3. Batch into groups of 20
4. `POST /api/v1/sync/push` for each batch
5. On success: `markSynced(id, now)` for each item
6. On failure: `markFailed(id, error)`, increment `retryCount`

**Phase 2 — Pull (server → client):**
1. `GET /api/v1/sync/pull?since=<lastSyncedAt>` — delta since last sync
2. Upsert all returned records into Drift in a **single transaction** (all-or-nothing)
3. On success: persist new `lastSyncedAt` to `FlutterSecureStorage` (`last_synced_at_<userId>`)
4. On failure: transaction rolled back entirely; next sync re-fetches from previous `since`

### Retry Logic

- Max retries: **5**
- Backoff formula: `min(2^retryCount × 30s, 1800s)`
  - Retry 1: 30s
  - Retry 2: 60s
  - Retry 3: 120s
  - Retry 4: 240s
  - Retry 5: 480s
  - (then permanently failed — `failedAt` set, no more retries)

### SyncState (visible to UI)

```dart
enum SyncStatus { syncing, synced, pending, error }

@freezed
class SyncState with _$SyncState {
  const factory SyncState({
    required SyncStatus status,
    DateTime? lastSyncedAt,
    required int pendingCount,
    String? lastError,
  }) = _SyncState;
}
```

`SyncStatusIndicator` widget displays this in the app shell.

### Supported Tables for Sync

`workout_sessions`, `exercise_logs`, `set_logs`, `workout_plans`, `plan_days`, `plan_day_exercises`

Exercise library data (exercises, muscle groups) is read-only from the client's perspective — it comes from the server pull, never pushed.

---

## 9. Authentication — Flutter Side

### Token Storage

Tokens are persisted to `FlutterSecureStorage` (iOS Keychain / Android Keystore):
- Key `access_token` → JWT access token (15min TTL)
- Key `refresh_token` → JWT refresh token (7 days TTL)

### Session Restoration (App Startup)

On app launch, `AuthNotifier._restoreSession()` runs:
1. Loads tokens from `FlutterSecureStorage`
2. If no token → `AuthUnauthenticated`
3. If token exists → decodes JWT `sub` claim (base64 decode of payload, no signature verification — server verifies on every request)
4. Queries `UserDao.getUser(userId)` from Drift
5. If user row found + `isGuest == false` → `Authenticated(user)`
6. If user row found + `isGuest == true` → `AuthGuest(user)`
7. If user row not found → `AuthUnauthenticated` (clears tokens)
8. On successful restore → triggers `SyncService.performInitialSync()`

### Auth Methods

| Method | Flutter Flow |
|--------|-------------|
| Email/Password | POST credentials → receive tokens → persist → set `Authenticated` |
| Google | `google_sign_in` SDK → get `idToken` → POST to `/auth/google` → receive tokens |
| Apple | `sign_in_with_apple` SDK → get `identityToken` → POST to `/auth/apple` → receive tokens |
| Guest | POST to `/auth/guest` → receive tokens → set `AuthGuest` |
| Logout | Clear tokens → sign out Google SDK → set `AuthUnauthenticated` |

---

## 10. Backend Architecture — Node.js + Express

### Tech Choices & Rationale

| Technology | Version | Why |
|------------|---------|-----|
| Node.js | 24 (Alpine) | LTS, excellent TypeScript support, fast async I/O for API workloads |
| Express | 5.2.1 | Minimal and unopinionated; v5 improves async error propagation |
| Prisma | 7.5 with `@prisma/adapter-pg` | Type-safe queries matching TypeScript; schema-first keeps DB and code in sync; `adapter-pg` uses `node-pg` connection pool for optimal PostgreSQL performance |
| Zod | 4.3.6 | Schema-first validation with discriminated unions, cross-field refinement, and transform pipelines; better than `express-validator` for complex shapes |
| BullMQ | 5.74.1 | Reliable Redis-backed job queue for the daily streak calculation cron |
| Helmet | 8.1.0 | Security headers (CSP, HSTS, X-Frame-Options) with one line |
| bcryptjs | 3.0.2 | Password hashing; cost 12 ≈ 250ms (brute-force resistant) |

### Request Lifecycle

```
Incoming request
  → trust proxy (Render reverse proxy support)
  → requestLogger (Morgan: dev format locally, combined in prod)
  → globalLimiter (200 req / 15 min)
  → helmet() (security headers)
  → cors({ origin: env.CORS_ORIGIN })
  → express.json({ limit: '100kb' })
  → route-specific rate limiter (auth, profile, etc.)
  → authenticate middleware (JWT verification → res.locals.auth)
  → requireFullAccount middleware (if route needs it → 403 for guests)
  → validate middleware (Zod schema → res.locals.validated or 422)
  → controller function
  → success response (200/201)
     OR AppError thrown
  → errorHandler middleware (formats error, redacts 5xx in prod)
```

### All API Endpoints

#### Auth (`/auth`)
| Method | Path | Auth | Description |
|--------|------|------|-------------|
| POST | /auth/register | — | Email/password signup |
| POST | /auth/login | — | Email/password login |
| POST | /auth/refresh | — | Refresh access token |
| POST | /auth/forgot-password | — | Send password reset email |
| POST | /auth/reset-password | — | Reset password with token |
| POST | /auth/google | — | Google OAuth sign-in |
| POST | /auth/apple | — | Apple OAuth sign-in |
| POST | /auth/guest | — | Create guest account |
| POST | /auth/upgrade | auth | Upgrade guest to full account |

#### Health
| Method | Path | Auth | Description |
|--------|------|------|-------------|
| GET | /api/v1/health | — | DB + Redis status, uptime |

#### Exercises (`/api/v1/exercises`)
| Method | Path | Auth | Description |
|--------|------|------|-------------|
| GET | /api/v1/exercises | — | List exercises (cursor pagination, search, type, muscle_group filters) |
| GET | /api/v1/exercises/:id | — | Get exercise detail |
| POST | /api/v1/exercises | full account | Create custom exercise |
| PATCH | /api/v1/exercises/:id | full account | Update custom exercise |
| DELETE | /api/v1/exercises/:id | full account | Delete custom exercise |
| GET | /api/v1/muscle-groups | — | List all muscle groups |

#### Workout Plans (`/api/v1/plans`)
| Method | Path | Auth | Description |
|--------|------|------|-------------|
| POST | /api/v1/plans | full account | Create plan |
| GET | /api/v1/plans | full account | List user's plans |
| GET | /api/v1/plans/:id | full account | Get plan with days + exercises |
| PATCH | /api/v1/plans/:id | full account | Update plan |
| DELETE | /api/v1/plans/:id | full account | Soft-delete plan |
| POST | /api/v1/plans/:id/exercises | full account | Add exercise to plan day |
| PATCH | /api/v1/plans/:id/exercises/reorder | full account | Reorder exercises in a day |
| PATCH | /api/v1/plans/:id/exercises/:planDayExId | full account | Update plan day exercise |
| DELETE | /api/v1/plans/:id/exercises/:planDayExId | full account | Remove exercise from plan |

#### Sessions (`/api/v1/sessions`)
| Method | Path | Auth | Description |
|--------|------|------|-------------|
| POST | /api/v1/sessions | full account | Start session |
| GET | /api/v1/sessions | full account | List sessions (cursor, status/date filters) |
| GET | /api/v1/sessions/:id | full account | Get session with all logs |
| PATCH | /api/v1/sessions/:id | full account | Update session (notes, abandon) |
| POST | /api/v1/sessions/:id/sets | full account | Log a set |
| PATCH | /api/v1/sessions/:id/sets/:setId | full account | Update a set |
| DELETE | /api/v1/sessions/:id/sets/:setId | full account | Delete a set |
| POST | /api/v1/sessions/:id/complete | full account | Complete session |

#### Progress (`/api/v1/progress`)
| Method | Path | Auth | Description |
|--------|------|------|-------------|
| GET | /api/v1/progress/overview | full account | Dashboard stats |
| GET | /api/v1/progress/exercise/:id | full account | Exercise progress + history chart |
| GET | /api/v1/progress/personal-records | full account | List PRs (filter by exercise, type) |
| GET | /api/v1/progress/volume | full account | Volume over time (period, granularity) |

#### Streaks (`/api/v1/streaks`)
| Method | Path | Auth | Description |
|--------|------|------|-------------|
| GET | /api/v1/streaks | auth | Current streak |
| GET | /api/v1/streaks/history | auth | Streak history for month/year |

#### Users (`/api/v1/users`)
| Method | Path | Auth | Description |
|--------|------|------|-------------|
| GET | /api/v1/users/me | auth | Get profile |
| PATCH | /api/v1/users/me | auth | Update profile |
| PATCH | /api/v1/users/me/preferences | auth | Update preferences |
| GET | /api/v1/users/me/stats | auth | User stats |
| DELETE | /api/v1/users/me | full account | Delete account |

#### Sync (`/api/v1/sync`)
| Method | Path | Auth | Description |
|--------|------|------|-------------|
| POST | /api/v1/sync/push | full account | Push local changes (max 100 items) |
| GET | /api/v1/sync/pull | full account | Pull server changes since timestamp |

---

## 11. Database Schema — PostgreSQL + Prisma

### Design Decisions

**UUIDs for all PKs** — distributed-safe (client generates IDs offline), no sequential ID enumeration attacks.

**Soft deletes on WorkoutPlan** — `deletedAt` field with composite index `(userId, deletedAt)`. All queries filter `WHERE deleted_at IS NULL`. This index makes those queries efficient without a full table scan. Soft deletes preserve referential integrity (sessions linked to deleted plans still have the planId).

**Separate RefreshToken table** — hashed storage, session cap enforcement, revocation support. Each row represents one active device session.

**PasswordResetToken with domain-separated hash** — SHA256 with prefix `"reset:"` before hashing. Prevents a compromised reset token from being used as a refresh token (or vice versa) even if hashing is somehow compromised.

**Separate PersonalRecord table** — PRs are computed and stored, not recalculated on every progress fetch. Indexes on `(userId, exerciseId)` and `(userId, exerciseId, recordType)` make PR queries O(1).

**StreakHistory UNIQUE(userId, date)** — idempotent upsert support. The daily BullMQ job can safely run multiple times without creating duplicate history rows.

**Equipment as a separate table** — exercises link to equipment via a join table (`ExerciseEquipment`). Not yet exposed in Phase 1 UI but schema is future-proof for Phase 2 filtering.

### Migrations (9 total, in order)

| Migration | What Changed |
|-----------|-------------|
| `20260326070644_init` | Full initial schema |
| `20260409095905_add_auth_tokens` | `RefreshToken`, `PasswordResetToken` tables |
| `20260410000000_add_provider_user_id` | `providerUserId` on `User` for OAuth linking |
| `20260413140920_add_equipment_table` | `Equipment`, `ExerciseEquipment` tables |
| `20260414000000_fix_exercise_unique_and_join_indexes` | UNIQUE on `Exercise.name`, reverse FK indexes |
| `20260414115930_add_deleted_at_to_workout_plans` | `deletedAt` on `WorkoutPlan` |
| `20260414125945_add_composite_index_workout_plans` | Composite index `(userId, deletedAt)` |
| `20260415134614_personal_record_record_type_index` | Index `(userId, exerciseId, recordType)` on PRs |
| `20260420090141_add_bio_to_users` | `bio TEXT` on `User` |

### Enums

```
AuthProvider:   email | google | apple | guest
ExerciseType:   strength | cardio | stretching
ScheduleType:   weekly | recurring
SessionStatus:  in_progress | completed | abandoned
RecordType:     max_weight | max_reps | max_volume | best_pace
StreakStatus:   completed | rest_day | missed
SyncOperation:  create | update | delete
```

---

## 12. Authentication — Server Side

### JWT Strategy

**Access token:**
- Algorithm: HS256
- Secret: `JWT_SECRET` (min 32 bytes, validated on startup)
- TTL: 15 minutes
- Claims: `{ sub: userId, email: string | null, isGuest: boolean }`
- Email is nullable because Apple sign-in only provides it on first authorization.

**Refresh token:**
- Algorithm: HS256
- Secret: `JWT_REFRESH_SECRET` (must differ from `JWT_SECRET`)
- TTL: 7 days
- Claims: `{ sub: userId, jti: UUID, exp: Unix timestamp }`
- `jti` is a unique UUID preventing replay attacks
- `exp` is set to match the DB `expiresAt` value using DB server time (`SELECT NOW()`) — eliminates clock skew between application server and DB server

### Token Generation (Thread-Safe)

Both register and login call `storeRefreshToken()` which:
1. Runs inside a Prisma transaction
2. Executes `SELECT ... FOR UPDATE` on the user row to serialize concurrent token creation
3. Fetches DB server time (`NOW()`) for the `exp` claim
4. Deletes expired or revoked tokens before inserting
5. Enforces 20-session cap (deletes oldest if exceeded)
6. Stores SHA256 hash of raw token (domain-prefixed: `"refresh:" + rawToken`)
7. Returns the raw token to the client (never stored in DB)

### 4 Auth Strategies

**Email/Password:**
- bcrypt cost factor 12 (≈250ms — brute-force resistant)
- Email normalized to lowercase + trimmed before storage and comparison
- User enumeration prevented: login returns the same 401 error for "unknown email" and "wrong password"
- Register race condition guard: catches Prisma `P2002` (unique constraint) and converts to 409 Conflict

**Google:**
- Uses `google-auth-library`'s `OAuth2Client`
- Verifies `idToken` against Google's JWKS (public key rotation handled internally by the library)
- One `OAuth2Client` instance cached at module load — reuses JWKS cache across requests
- Looks up existing user by `providerUserId` (Google `sub` claim) → create if new

**Apple:**
- Uses `apple-signin-auth` library
- Validates `identityToken` signature against Apple's public keys
- Email claim only present on first authorization (Apple's privacy design) — stored on first, looked up by `providerUserId` on subsequent logins

**Guest:**
- No credentials required
- Creates a User with `isGuest: true`, no email or password
- JWT includes `isGuest: true` claim
- Guest accounts are blocked by `requireFullAccount` middleware on most write endpoints
- Fully upgradeable to email/Google/Apple without data loss

### Guest Upgrade Flow

`POST /auth/upgrade` accepts one of:
- `{ type: 'email', email, password }` → sets `email`, `passwordHash`, `authProvider: email`, `isGuest: false`
- `{ type: 'google', idToken }` → verifies token, sets `providerUserId`, `authProvider: google`, `isGuest: false`
- `{ type: 'apple', identityToken, displayName? }` → verifies token, sets `providerUserId`, `authProvider: apple`, `isGuest: false`

---

## 13. API Design

### Conventions

- **RESTful resource naming:** Plural nouns (`/plans`, `/exercises`, `/sessions`)
- **API versioning:** URL prefix `/api/v1/` — allows breaking changes in `/api/v2/` without disrupting existing clients
- **PATCH for partial updates** — only send changed fields; server applies them with Prisma's selective update syntax
- **PUT reserved** for full replacement (not currently used in Phase 1)

### Pagination (Cursor-Based)

All list endpoints use cursor-based pagination. Response shape:
```json
{
  "data": [...],
  "pagination": {
    "next_cursor": "base64encodedCursor",
    "has_more": true,
    "limit": 20
  }
}
```

Cursor encodes `{ id, startedAt }` (or similar) as Base64. **Why cursor over offset:**
- Offset pagination breaks under concurrent inserts (items shift, causing duplicates or skips)
- Cursor-based gives stable results even with real-time data arriving between pages
- Default limit: 20, max: 100

### Success Response Shape

```json
{ "status": 200, "data": { ... } }
```

### Error Response Shape (RFC 7807-inspired)

```json
{
  "status": 422,
  "error": "Unprocessable Entity",
  "message": "Validation failed",
  "details": [
    { "field": "email", "message": "Invalid email address" },
    { "field": "password", "message": "Must be at least 8 characters" }
  ]
}
```

`details` array is included only for validation errors (422) and select 400 errors with field-level context.

---

## 14. Validation — Zod

Every request body, query string, and URL params are validated via Zod before reaching the controller. The `validate` middleware stores the parsed, coerced result in `res.locals.validated`.

### Patterns Used

```typescript
// Email normalization
email: z.string().email().toLowerCase().trim()

// Password strength
password: z.string().min(8).max(128)

// HTTPS-only URL
avatarUrl: z.string().url().refine(url => url.startsWith('https://'), 'Must use HTTPS')

// Rep range format: "10" or "8-12"
targetReps: z.string().regex(/^\d+(-\d+)?$/, 'Format: "10" or "8-12"')

// Cursor pagination
cursor: z.string().min(1).optional()
limit: z.string().optional()
  .transform(v => v !== undefined ? parseInt(v, 10) : 20)
  .pipe(z.number().int().min(1).max(100))

// Cross-field validation
.superRefine((data, ctx) => {
  if (data.planDayId && !data.planId) {
    ctx.addIssue({ code: 'custom', path: ['planId'], message: 'Required when planDayId is provided' })
  }
})

// At-least-one-field-provided
.refine(data => Object.values(data).some(v => v !== undefined), 'At least one field must be provided')

// Discriminated union (upgrade endpoint)
z.discriminatedUnion('type', [
  z.object({ type: z.literal('email'), email: ..., password: ... }),
  z.object({ type: z.literal('google'), idToken: ... }),
  z.object({ type: z.literal('apple'), identityToken: ... }),
])
```

---

## 15. Rate Limiting

Using `express-rate-limit` with Redis backing (`rate-limit-redis`) in production. Falls back to in-memory store in development/test.

| Limiter | Endpoints | Limit | Window |
|---------|-----------|-------|--------|
| `globalLimiter` | All | 200 req | 15 min |
| `authLimiter` | /register, /login, /google, /apple, /upgrade | 10 req | 15 min |
| `refreshLimiter` | /refresh | 60 req | 15 min |
| `forgotPasswordLimiter` | /forgot-password | 5 req | 15 min |
| `resetPasswordLimiter` | /reset-password | 10 req | 15 min |
| `guestLimiter` | /guest | 3 req | 15 min |
| `profileUpdateLimiter` | PATCH /users/me | 30 req | 15 min |
| `deleteAccountLimiter` | DELETE /users/me | 5 req | 15 min |

Exceeding any limit returns `429 Too Many Requests`.

---

## 16. Error Handling

### AppError Class

```typescript
class AppError extends Error {
  constructor(
    public readonly status: number,   // HTTP status code
    message: string,                   // Human-readable message
    public readonly details?: Array<{ field: string; message: string }>
  ) { super(message) }
}
```

### Error Handler Middleware

- Catches all errors (Express v5 propagates async errors automatically)
- **4xx errors (AppError):** message shown to client as-is
- **5xx errors (unexpected):** message redacted in production (`"An unexpected error occurred"`) to prevent leaking implementation details
- **Details array:** included only when AppError has `details` (validation errors)
- **5xx logging:** written to `stderr` for monitoring

### Common HTTP Error Codes

| Code | When |
|------|------|
| 400 | Malformed request (bad JSON, missing required field not caught by Zod) |
| 401 | Missing/invalid/expired JWT |
| 403 | Guest account accessing full-account endpoint |
| 404 | Resource not found (also used to avoid revealing existence of other users' resources) |
| 409 | Duplicate resource (email already registered, exercise name taken) |
| 413 | Request body > 100kb |
| 422 | Zod validation failure (field-level details) |
| 429 | Rate limit exceeded |
| 500 | Unexpected server error |
| 503 | Service unavailable (DB/Redis down) |

---

## 17. Background Jobs — BullMQ

### Daily Streak Check

**Job name:** `DAILY_STREAK_CHECK_JOB`
**Schedule:** `5 0 * * *` (00:05 UTC every day)
**Concurrency:** 1 (prevents overlapping runs)

**Algorithm:**
1. Compute `yesterday` in UTC (e.g., 2026-04-20)
2. Fetch all users with at least one active workout plan
3. For each user, determine if yesterday was a **workout day** or **rest day** based on plan schedule:
   - **Weekly plan:** check if `yesterday.dayOfWeek` matches any `PlanDay.dayOfWeek`
   - **Recurring plan:** compute current week number (`floor((yesterday - plan.createdAt) / 7)` mod `weeksCount`), then check matching `PlanDay` for that week + day
4. For workout-day users: query for completed sessions in `[yesterday 00:00 UTC, today 00:00 UTC)`
5. Classify outcome per user:
   - Session found → `completed` → increment streak
   - No session found → `missed` → reset streak to 0
   - Rest day → `rest_day` → streak unchanged
6. Batch-write `StreakHistory` rows and update `Streak` rows in a transaction
7. Skip if `StreakHistory` row already exists for that user+date (idempotent — safe to re-run)

**Why 00:05 UTC instead of 00:00:** Adds a 5-minute buffer for any session-completion events that arrive just before midnight UTC to be committed to the database.

---

## 18. Code Generation

### Tools

| Tool | Generates | Input Files |
|------|-----------|-------------|
| `freezed` | `*.freezed.dart` — immutable data classes with `copyWith`, equality, `toString`, sealed unions | Files annotated with `@freezed` |
| `json_serializable` | `*.g.dart` — `fromJson` / `toJson` methods | Files with `@JsonSerializable` |
| `riverpod_generator` | `*.g.dart` — Riverpod provider boilerplate | Files with `@riverpod` |
| `retrofit_generator` | `*.g.dart` — Dio HTTP client implementations | `@RestApi`-annotated abstract classes |
| `drift_dev` | `*.g.dart` / `app_database.g.dart` — type-safe DAO and database code | Drift table and DAO definitions |

### Generated Files Are Checked In

`*.g.dart` and `*.freezed.dart` files are committed to the repo. This means:
- CI does not need to run `build_runner` (faster CI)
- No generated-file divergence risk in CI
- Trade-off: PRs include generated file diffs — reviewers should focus on the source files

### Running Code Generation

```bash
# One-time
dart run build_runner build --delete-conflicting-outputs

# Watch mode (during development)
dart run build_runner watch --delete-conflicting-outputs
```

Must be run after modifying any `@freezed`, `@riverpod`, `@RestApi`, or Drift-annotated files.

---

## 19. Infrastructure & Deployment

### Docker (Multi-Stage Build)

```
Stage 1: deps       — npm ci (installs all deps including devDeps)
Stage 2: build      — prisma generate + tsc (compiles TypeScript → dist/)
Stage 3: prod-deps  — npm ci --omit=dev (production deps only)
Stage 4: production — Alpine Node 24, non-root 'node' user, EXPOSE 3000
                      Copies: dist/, src/generated/, prisma/, start.sh
                      HEALTHCHECK: GET /api/v1/health every 30s
                      CMD: ./start.sh
```

**Why multi-stage:** Final image contains only the compiled output + production dependencies. Dev dependencies (TypeScript compiler, Prisma CLI for generation, etc.) are discarded. Smaller image = faster deploy, smaller attack surface.

### Startup Script (`start.sh`)

```bash
#!/bin/sh
set -e
timeout 120 npx prisma migrate deploy   # run pending migrations
exec node dist/server.js                # start server
```

Migrations run on every container start. `prisma migrate deploy` is idempotent (skips already-applied migrations). The 120-second timeout prevents container startup hanging forever on DB connection issues.

### Render Blueprint (`render.yaml`)

Three services defined as Infrastructure-as-Code:
- `fitness-tracker-db` — PostgreSQL 16 (FREE tier, ⚠️ 90-day expiry)
- `fitness-tracker-redis` — Redis 7 (FREE tier)
- `fitness-tracker-api` — Docker service, deploys from `./server/Dockerfile`

**Deploy flow:**
1. Push to `main` branch
2. GitHub Actions `deploy.yml` runs CI gate (lint + typecheck + build)
3. On success, sends `POST` to Render deploy hook URL (via `RENDER_DEPLOY_HOOK_URL` secret)
4. Render pulls latest `main`, builds Docker image, runs `start.sh`, health-checks `/api/v1/health`
5. Traffic switches over (zero-downtime on paid tier)

### Environment Validation (Startup)

All environment variables are validated via Zod on server startup. If any required variable is missing or invalid, the process exits immediately with a clear error message. This prevents silent misconfiguration bugs in production.

Key validation rules:
- `DATABASE_URL` must start with `postgresql://` or `postgres://`
- `JWT_SECRET` and `JWT_REFRESH_SECRET` must differ from each other
- Production requires `CORS_ORIGIN` (not wildcard) and `REDIS_URL`
- `JWT_SECRET` minimum 32 bytes

---

## 20. Security Measures

| Measure | Implementation | Why |
|---------|---------------|-----|
| Security headers | `helmet()` | HSTS, CSP, X-Frame-Options, X-Content-Type-Options, etc. |
| CORS lockdown | `cors({ origin: env.CORS_ORIGIN })` | Prevents unauthorized origins in production |
| Rate limiting | Per-endpoint limits, Redis-backed | Brute-force and abuse prevention |
| Short-lived JWTs | 15-minute access tokens | Limits damage window if token is intercepted |
| Rotating refresh tokens | 7-day TTL, hashed storage, 20-session cap | Token theft detection via revocation |
| bcrypt cost 12 | ≈250ms per hash | Brute-force resistant password storage |
| User enumeration prevention | Same error for "unknown email" and "wrong password" | Prevents email harvesting |
| Token hash storage | SHA256(domain_prefix + raw_token) before DB storage | DB compromise doesn't expose raw tokens |
| Domain-separated hashes | `"refresh:"` vs `"reset:"` prefix | Prevents cross-context token reuse |
| Production error redaction | 5xx messages hidden from clients | Hides implementation details from attackers |
| HTTPS-only avatar URLs | Zod validation | Prevents mixed content and HTTP downgrade |
| Non-root Docker user | `USER node` in Dockerfile | Container breakout mitigation |
| `trust proxy 1` | Express setting | Correct IP for rate limiting behind Render's proxy |
| Request body size limit | `express.json({ limit: '100kb' })` | Prevents payload-based DoS |

---

## 21. CI/CD Pipelines

### Backend CI (`.github/workflows/backend.yml`)

Triggers on pushes to `main` or `dev` when `server/**` files change.

Steps: `npm ci` → `npm run lint` → `npm run typecheck` → `npm run build` → upload `dist/` artifact (3-day retention)

### Flutter CI (`.github/workflows/flutter.yml`)

Triggers on pushes to `main` or `dev` when `app/**` files change.

Steps: setup Java 17 + Flutter 3.38.4 → `flutter pub get` (in dependency order: fitness_data → fitness_domain → app) → `flutter analyze` → `flutter test` → `flutter build apk --debug` → upload APK artifact (7-day retention)

**Note:** Generated files (`*.g.dart`, `*.freezed.dart`) are checked in — no `build_runner` step needed in CI.

### Deploy to Render (`.github/workflows/deploy.yml`)

Triggers on pushes to `main` when `server/**` files change.

Two jobs run in sequence:
1. **CI gate** — mirrors backend CI (lint + typecheck + build). Must pass.
2. **Deploy trigger** — `POST` to Render deploy hook URL. Render handles the rest asynchronously.

---

## 22. Performance Targets

| Metric | Target |
|--------|--------|
| App launch to usable UI | < 2 seconds |
| Workout set logging (offline) | < 100ms per action |
| Sync after reconnect | < 5 seconds for a typical session |
| Photo upload (Phase 2) | < 3 seconds via pre-signed S3 URL |
| API response time | < 200ms p95 |

Offline operations (Drift writes) are the primary path during workouts — these are local SQLite writes and comfortably achieve < 100ms.

---

## 23. Key Files Reference

### Flutter App

| File | Layer | Purpose |
|------|-------|---------|
| `app/lib/main.dart` | Entry | App entry point, ProviderScope |
| `app/lib/app.dart` | Presentation | MaterialApp, theme, router wiring |
| `app/lib/core/router/app_router.dart` | — | GoRouter config, auth redirects, shell route |
| `app/lib/core/router/app_routes.dart` | — | Route path constants + helper functions |
| `app/lib/core/navigation/app_shell.dart` | Presentation | BottomNavigationBar scaffold |
| `app/lib/core/providers/dio_provider.dart` | BL | Singleton Dio with interceptor chain |
| `app/lib/core/providers/auth_token_provider.dart` | BL | JWT token storage + FlutterSecureStorage |
| `app/lib/core/providers/database_provider.dart` | BL | Singleton Drift AppDatabase |
| `app/lib/core/providers/connectivity_provider.dart` | BL | Device online/offline state |
| `app/lib/core/sync/sync_service.dart` | BL | Offline-first sync engine |
| `app/lib/core/network/refresh_interceptor.dart` | Data | JWT auto-refresh on 401 |
| `app/lib/features/auth/providers/auth_notifier.dart` | BL | Auth state machine |
| `app/lib/features/auth/providers/auth_state.dart` | Domain | AuthState sealed union |
| `app/lib/features/active_session/providers/active_session_notifier.dart` | BL | Live workout session state |
| `app/packages/fitness_data/lib/src/local/app_database.dart` | Data | Drift database definition |
| `app/packages/fitness_data/lib/src/local/daos/` | Data | All 6 DAOs |
| `app/packages/fitness_data/lib/src/remote/` | Data | All 8 Retrofit API clients + DTOs |
| `app/packages/fitness_domain/lib/src/` | Domain | All domain models + repository interfaces |

### Backend

| File | Purpose |
|------|---------|
| `server/src/server.ts` | Entry point, Express listen, graceful shutdown |
| `server/src/app.ts` | Express app factory, middleware chain, routes |
| `server/src/routes/index.ts` | Route aggregator |
| `server/src/middleware/authenticate.ts` | JWT verification middleware |
| `server/src/middleware/require-full-account.ts` | Guest guard middleware |
| `server/src/middleware/validate.ts` | Zod validation middleware |
| `server/src/middleware/rate-limiter.ts` | All rate limiter instances |
| `server/src/middleware/error-handler.ts` | Global error formatter |
| `server/src/utils/jwt.ts` | JWT sign/verify with type guards |
| `server/src/utils/errors.ts` | AppError class |
| `server/src/utils/env.ts` | Zod environment validation |
| `server/src/jobs/daily-streak-check.ts` | Streak BullMQ job logic |
| `server/src/workers/streak.worker.ts` | BullMQ worker + cron scheduler |
| `server/src/services/sync.service.ts` | Sync push/pull with ownership checks |
| `server/prisma/schema.prisma` | Full PostgreSQL schema |
| `server/prisma/seed.ts` | Dev seeding (75+ exercises, muscle groups, equipment) |
| `server/Dockerfile` | Multi-stage production image |
| `server/start.sh` | Container startup (migrate + serve) |
| `render.yaml` | Render Blueprint IaC |
| `.github/workflows/` | CI/CD pipelines |
