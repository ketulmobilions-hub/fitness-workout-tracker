# Fitness Workout Tracker — Test Scenarios

> Exhaustive list of scenarios to test after Phase 1 MVP completion.
> Organized by feature area. Each section covers happy paths, edge cases, and validation failures.

---

## Table of Contents

1. [Authentication](#1-authentication)
2. [Exercise Library](#2-exercise-library)
3. [Workout Plans](#3-workout-plans)
4. [Active Workout Session](#4-active-workout-session)
5. [Workout History](#5-workout-history)
6. [Progress Tracking](#6-progress-tracking)
7. [Streaks](#7-streaks)
8. [Profile & Settings](#8-profile--settings)
9. [Offline-First Behavior](#9-offline-first-behavior)
10. [Security & Authorization](#10-security--authorization)
11. [Complex Real-World Scenarios](#11-complex-real-world-scenarios)
12. [API-Level Edge Cases](#12-api-level-edge-cases)

---

## 1. Authentication

### 1.1 Registration

| # | Scenario | Steps | Expected Result |
|---|----------|-------|----------------|
| A1 | Register new user | POST /auth/register with valid email + password | 201, returns accessToken + refreshToken, user created |
| A2 | Register with display name | Include displayName in body | Name stored, returned in response |
| A3 | Register then immediately login | Register → login with same credentials | Both succeed, tokens issued each time |
| A4 | Duplicate email registration | Register twice with same email | First: 201. Second: 409 Conflict, `details[0].field = "email"` |
| A5 | Email case normalization | Register as `User@Example.COM`, login as `user@example.com` | Login succeeds (email normalized to lowercase) |
| A6 | Password too short | password = "abc123" (6 chars) | 422, `details[0].field = "password"` |
| A7 | Password too long | password = 129 chars | 422 |
| A8 | Invalid email format | email = "notanemail" | 422, `details[0].field = "email"` |
| A9 | Display name too long | displayName = 51 chars | 422 |
| A10 | Registration rate limit | POST /auth/register 11 times in 15 min | First 10: succeed or 409. 11th: 429 Too Many Requests |

### 1.2 Login

| # | Scenario | Steps | Expected Result |
|---|----------|-------|----------------|
| B1 | Login with correct credentials | POST /auth/login with registered email/password | 200, accessToken + refreshToken |
| B2 | Login with wrong password | Correct email, wrong password | 401, same generic error message as unknown email |
| B3 | Login with unknown email | Unregistered email | 401, same generic error as wrong password (no enumeration) |
| B4 | Login rate limit | 11 login attempts in 15 min | 11th returns 429 |
| B5 | Login after registration | Register then immediately login | 200, valid tokens |
| B6 | Login with email different case | Registered as `test@example.com`, login as `TEST@EXAMPLE.COM` | 200 (normalized) |

### 1.3 Token Lifecycle

| # | Scenario | Steps | Expected Result |
|---|----------|-------|----------------|
| C1 | Use access token immediately | Login → make authenticated request within 15 min | 200 |
| C2 | Access token expires, refresh succeeds | Wait 15+ min (or manipulate token) → make request | 401 triggers auto-refresh → original request retried → 200 |
| C3 | Both tokens expired | Access + refresh both expired → make request | Forced logout, redirected to login screen |
| C4 | Tampered access token | Modify JWT payload before sending | 401 |
| C5 | Missing Authorization header | Request to protected endpoint without header | 401 |
| C6 | Refresh token used correctly | POST /auth/refresh with valid refreshToken | 200, new accessToken + refreshToken issued |
| C7 | Refresh token expired | POST /auth/refresh with 8-day-old token | 401 |
| C8 | Refresh token revoked | Logout → attempt to refresh with old token | 401 |
| C9 | Session cap (20 devices) | Login from 21 devices | 21st login succeeds, oldest session revoked (token no longer works) |
| C10 | App restart restores session | Close and reopen app | Session restored from FlutterSecureStorage, no re-login |

### 1.4 Password Reset

| # | Scenario | Steps | Expected Result |
|---|----------|-------|----------------|
| D1 | Full password reset flow | POST /auth/forgot-password → receive email → POST /auth/reset-password with token | 200 each step, can login with new password |
| D2 | Forgot password for unknown email | POST /auth/forgot-password with unregistered email | 200 (same response — prevents email enumeration) |
| D3 | Expired reset token | Use token > 1 hour old | 422 or 401 error |
| D4 | Already-used reset token | Use same token twice | 422 on second use |
| D5 | Forgot password rate limit | 6 requests in 15 min | 6th returns 429 |
| D6 | New password same as old | Reset with same password as before | Succeeds (no rule against it unless explicitly added) |

### 1.5 Social Auth

| # | Scenario | Steps | Expected Result |
|---|----------|-------|----------------|
| E1 | Google sign-in (new user) | POST /auth/google with valid idToken | 201, account created, tokens returned |
| E2 | Google sign-in (returning user) | POST /auth/google with same idToken as before | 200, same user data, tokens refreshed |
| E3 | Apple sign-in (first time) | POST /auth/apple with identityToken + email | 201, email stored |
| E4 | Apple sign-in (subsequent) | POST /auth/apple with identityToken, no email | 200, user found by providerUserId |
| E5 | Invalid Google idToken | POST /auth/google with malformed/expired token | 401 |
| E6 | Invalid Apple identityToken | POST /auth/apple with malformed token | 401 |

### 1.6 Guest Account

| # | Scenario | Steps | Expected Result |
|---|----------|-------|----------------|
| F1 | Guest login | POST /auth/guest | 201, tokens returned, isGuest = true in JWT |
| F2 | Guest rate limit | POST /auth/guest 4 times in 15 min | 4th returns 429 |
| F3 | Guest tries to create plan | POST /api/v1/plans with guest token | 403 with upgrade message |
| F4 | Guest views exercise library | GET /api/v1/exercises (no auth needed) | 200, exercises listed |
| F5 | Guest upgrades to email | POST /auth/upgrade with type=email, email, password | 200, isGuest = false, data preserved |
| F6 | Guest upgrades to Google | POST /auth/upgrade with type=google, idToken | 200, isGuest = false |
| F7 | Guest upgrade duplicate email | Upgrade to email that's already registered | 409 Conflict |
| F8 | Guest upgrade rate limit | POST /auth/upgrade 11 times in 15 min | 429 |

### 1.7 Logout

| # | Scenario | Steps | Expected Result |
|---|----------|-------|----------------|
| G1 | Normal logout | Tap logout in app | Tokens cleared, redirected to login |
| G2 | Post-logout request | Use old token after logout | 401 (refresh token revoked) |
| G3 | Google logout | Logout while Google-signed-in | GoogleSignIn SDK signed out |

---

## 2. Exercise Library

### 2.1 Browsing & Filtering

| # | Scenario | Steps | Expected Result |
|---|----------|-------|----------------|
| H1 | Open exercise list | Navigate to exercises | All seeded exercises visible (75+) |
| H2 | Search by name | Type "bench" in search bar | Bench Press and variants appear |
| H3 | Search case-insensitive | Type "SQUAT" | Squat appears |
| H4 | Search no results | Type "xyzabc123" | Empty state shown |
| H5 | Filter by type: strength | Select Strength filter | Only strength exercises |
| H6 | Filter by type: cardio | Select Cardio filter | Only cardio exercises |
| H7 | Filter by type: stretching | Select Stretching filter | Only stretching exercises |
| H8 | Filter by muscle group: chest | Select Chest filter | All chest exercises (primary + secondary) |
| H9 | Filter by muscle group: quadriceps | Select Quads filter | Squats, Leg Press, Lunges, etc. |
| H10 | Combined filter: strength + chest | Select Strength + Chest | Bench Press, Incline DB Press, etc. |
| H11 | Search + muscle group filter | "press" + chest | Intersection: chest press exercises only |
| H12 | Clear filters | Apply filter → tap clear | All exercises shown again |
| H13 | Paginate exercises | Scroll to bottom | Next page loads (cursor-based) |

### 2.2 Exercise Detail

| # | Scenario | Steps | Expected Result |
|---|----------|-------|----------------|
| I1 | View seeded exercise | Tap "Bench Press" | Name, type, description, instructions, muscle groups (primary + secondary) |
| I2 | Exercise with no instructions | View such an exercise | No crash, graceful empty state |
| I3 | Exercise with multiple muscle groups | View "Deadlift" | Shows all: lower back (primary), hamstrings, glutes, traps, etc. |
| I4 | Cardio exercise | View "Running" | Shows distance/pace targets, no weight info |

### 2.3 Custom Exercise CRUD

| # | Scenario | Steps | Expected Result |
|---|----------|-------|----------------|
| J1 | Create custom exercise | Fill name + type + muscle groups → submit | 201, appears in exercise list |
| J2 | Create with all fields | Name + description + instructions + type + muscle groups | All fields saved |
| J3 | Edit custom exercise | Change name/description | Changes reflected in list + detail |
| J4 | Delete custom exercise | Delete own custom exercise | Removed from list |
| J5 | Duplicate name | Create exercise with same name as existing | 409 Conflict |
| J6 | Name too long | name = 101 chars | 422 |
| J7 | Guest creates exercise | Logged in as guest | 403 |
| J8 | Delete another user's exercise | Try to delete custom exercise created by another user | 403 |
| J9 | Create with no muscle groups | Submit without selecting muscle groups | Check if valid (may be allowed) |
| J10 | Custom exercise appears in plan picker | After creation | Visible when adding exercises to a plan |

---

## 3. Workout Plans

### 3.1 Creating Plans

| # | Scenario | Steps | Expected Result |
|---|----------|-------|----------------|
| K1 | Create weekly plan | Name + description + scheduleType=weekly | 201, plan visible in list |
| K2 | Create recurring 4-week plan | Name + scheduleType=recurring + weeksCount=4 | 201, plan with 4-week structure |
| K3 | Create recurring plan without weeksCount | scheduleType=recurring, no weeksCount | 422 validation error |
| K4 | Plan name only (no description) | Submit without description | Valid, created successfully |
| K5 | Guest creates plan | Logged in as guest | 403 |
| K6 | Plan name too long | name > 100 chars | 422 |

### 3.2 Plan Structure

| # | Scenario | Steps | Expected Result |
|---|----------|-------|----------------|
| L1 | Add exercises to Monday | Select Monday day → add Bench Press, OHP, Tricep Pushdown | All three visible on Monday |
| L2 | Set strength targets | Add Bench Press → set 4 sets, "8-12" reps | Targets saved and displayed |
| L3 | Set cardio targets | Add Running → set 30 min duration, 5km distance | Targets saved |
| L4 | Target reps range | targetReps = "8-12" | Valid |
| L5 | Target reps single number | targetReps = "10" | Valid |
| L6 | Invalid reps format | targetReps = "abc" | 422 |
| L7 | Reorder exercises in a day | Drag exercise 3 to position 1 | New order persists after page refresh |
| L8 | Plan with no exercises | Create plan with days but no exercises assigned | Valid, empty days shown |
| L9 | Add same exercise twice to same day | | Depends on implementation — should work or show warning |

### 3.3 Plan Management

| # | Scenario | Steps | Expected Result |
|---|----------|-------|----------------|
| M1 | View plan list | Navigate to Plans tab | All user's plans with cards |
| M2 | View plan detail | Tap a plan | All days, exercises, and targets |
| M3 | Edit plan name | Edit → change name → save | Updated in list and detail |
| M4 | Edit plan description | Change description | Updated |
| M5 | Delete plan | Tap delete → confirm | Plan disappears (soft-delete), not visible in list |
| M6 | Deleted plan sessions preserved | Delete plan that had sessions | Sessions still visible in history |
| M7 | Non-existent plan | GET /api/v1/plans/nonexistent-id | 404 |
| M8 | Another user's plan | Try to access plan owned by User B (as User A) | 404 (not 403) |
| M9 | Add exercise to non-existent plan day | planDayId that doesn't exist | 404 |

---

## 4. Active Workout Session

### 4.1 Starting a Session

| # | Scenario | Steps | Expected Result |
|---|----------|-------|----------------|
| N1 | Start from a plan | Tap "Start Workout" on plan detail | Session created with planId + planDayId, exercises pre-loaded in order |
| N2 | Start free session | Start without selecting a plan | Empty session, no pre-loaded exercises |
| N3 | Session timer starts | Open active workout screen | Timer counting up from 0 |
| N4 | Multiple sessions | Start session while another is in_progress | Second session starts (previous remains in_progress until completed/abandoned) |

### 4.2 Logging Sets

| # | Scenario | Steps | Expected Result |
|---|----------|-------|----------------|
| O1 | Log strength set | Enter reps=10, weight=80kg → add set | Set appears in list, setNumber=1 |
| O2 | Log second set | Add another set | setNumber=2, previous set visible |
| O3 | Log cardio set | Enter duration=30min, distance=5km | Pace auto-calculated and displayed |
| O4 | Log with heart rate | Add heartRate=145 | Saved with set |
| O5 | Log with RPE | Add RPE=8 | Saved with set |
| O6 | Log with tempo | Add tempo="3-1-1" | Saved with set |
| O7 | Log warmup set | Toggle isWarmup=true | Set visually distinguished, not counted in working volume |
| O8 | View previous performance | Log second session of same exercise | Previous session's sets shown in reference card |
| O9 | Previous performance on first session | First time doing an exercise | Reference card empty (graceful) |
| O10 | Delete a set | Tap delete on a set | Removed from list, setNumbers don't reorder |
| O11 | Update a set | Tap edit → change weight | Updated in list |
| O12 | Log 20+ sets | Log 20+ sets in one session | All visible, UI scrollable, no performance issues |

### 4.3 Validation

| # | Scenario | Steps | Expected Result |
|---|----------|-------|----------------|
| P1 | Reps = 0 | Enter reps=0 | 422 (min: 1) |
| P2 | Negative weight | weightKg = -5 | 422 |
| P3 | Heart rate > 300 | heartRate = 301 | 422 |
| P4 | RPE > 10 | rpe = 11 | 422 |
| P5 | Duration > 86400s | durationSec = 86401 (24h+1s) | 422 |
| P6 | Negative distance | distanceM = -100 | 422 |

### 4.4 Completing a Session

| # | Scenario | Steps | Expected Result |
|---|----------|-------|----------------|
| Q1 | Complete session | Tap "Finish Workout" | WorkoutSummary screen shown: duration, total sets, exercises |
| Q2 | New personal record: max weight | Beat previous PR on Bench Press | PR highlighted on summary screen |
| Q3 | New personal record: max reps | Log more reps than ever before | PR shown |
| Q4 | New personal record: best pace | Run faster than before | PR shown |
| Q5 | No new PRs | Normal session below PRs | Summary shows stats, no PR callouts |
| Q6 | Complete with 0 sets | Complete session with no sets logged | Valid — session marked completed with durationSec |
| Q7 | Abandon session | Tap "Abandon" | Status = abandoned, no PRs recorded |
| Q8 | Complete already-completed session | Try to complete twice | 409 Conflict |
| Q9 | App killed mid-session | Force-close app during active session | Session remains in_progress in Drift, can be resumed |

---

## 5. Workout History

### 5.1 Viewing History

| # | Scenario | Steps | Expected Result |
|---|----------|-------|----------------|
| R1 | Empty history | New user, no sessions | Empty state shown |
| R2 | List past sessions | After logging sessions | Chronological list, most recent first |
| R3 | Session card content | View any session card | Date, duration, plan name (if applicable), status badge |
| R4 | Filter by completed | Select "Completed" filter | Only completed sessions |
| R5 | Filter by abandoned | Select "Abandoned" filter | Only abandoned sessions |
| R6 | Filter by date range | Set from/to date | Only sessions in that range |
| R7 | Paginate history | Many sessions, scroll to bottom | Next page loads (cursor-based, no duplicates) |

### 5.2 Session Detail

| # | Scenario | Steps | Expected Result |
|---|----------|-------|----------------|
| S1 | View session detail | Tap a session | All exercise logs with all sets and values |
| S2 | Strength session detail | Session with reps + weight | Shows reps × weight for each set |
| S3 | Cardio session detail | Session with duration + distance + pace | All cardio metrics shown |
| S4 | Mixed session detail | Both strength + cardio exercises | Both formatted correctly |
| S5 | Session from plan | Session linked to a plan | Shows plan name + plan day name |
| S6 | Free session (no plan) | Session without planId | No plan name shown, graceful |
| S7 | Session with 30+ sets | Very long session | All sets shown, no UI issues |
| S8 | Abandoned session detail | View abandoned session | Clearly marked as abandoned, sets visible |

---

## 6. Progress Tracking

### 6.1 Progress Overview

| # | Scenario | Steps | Expected Result |
|---|----------|-------|----------------|
| T1 | View progress dashboard | Navigate to Progress tab | Personal records, total workouts, volume data |
| T2 | Total workouts count | After 5 sessions | Shows "5" (only completed sessions) |
| T3 | Top personal records | After PRs established | Top exercises with their PR values |
| T4 | No sessions yet | Brand new account | Empty state, "Start your first workout" |

### 6.2 Exercise Progress

| # | Scenario | Steps | Expected Result |
|---|----------|-------|----------------|
| U1 | View exercise progress | Tap exercise name in dashboard | Line chart of max weight over time |
| U2 | Period filter: 1 month | Select 1m | Chart shows last 30 days |
| U3 | Period filter: all time | Select "All" | Full history shown |
| U4 | PRs panel | View exercise progress | maxWeight, maxReps, maxVolume, bestPace (relevant ones only) |
| U5 | Estimated 1RM | Strength exercise with reps + weight | 1RM displayed (if calculated) |
| U6 | Exercise with only 1 data point | Single session | Chart with single point, no line |
| U7 | Exercise with no history | View progress for exercise never logged | Empty chart, "No data yet" |
| U8 | Cardio exercise progress | Running | Shows pace/distance progress, not weight |
| U9 | Period with no activity | Select 1m, no sessions in last month | Gap in chart, not zero-fill |
| U10 | Multiple sessions same day | Log twice in one day | Aggregated or shown as separate points (verify behavior) |

### 6.3 Personal Records

| # | Scenario | Steps | Expected Result |
|---|----------|-------|----------------|
| V1 | List all PRs | GET /api/v1/progress/personal-records | All records for all exercises |
| V2 | Filter PRs by exercise | ?exercise_id=xxx | Only that exercise's records |
| V3 | Filter PRs by type | ?record_type=max_weight | Only weight PRs across all exercises |
| V4 | PR updated on new record | Beat existing PR | Old PR replaced, new value shown |

### 6.4 Volume Tracking

| # | Scenario | Steps | Expected Result |
|---|----------|-------|----------------|
| W1 | View volume by week | GET /api/v1/progress/volume?period=1w&granularity=daily | 7 days of volume data |
| W2 | View volume by month | period=1m&granularity=weekly | ~4 weekly aggregates |
| W3 | View volume by year | period=1y&granularity=monthly | 12 monthly aggregates |
| W4 | Timezone alignment | Include utc_offset param | Data grouped by user's local date, not UTC |

---

## 7. Streaks

### 7.1 Streak Calculation

| # | Scenario | Steps | Expected Result |
|---|----------|-------|----------------|
| X1 | First ever workout | Complete first session | Streak = 1 (after next 00:05 UTC job) |
| X2 | Consecutive workout days | Complete sessions 3 days in a row | Streak = 3 |
| X3 | Miss a workout day (with plan) | Have plan, skip a scheduled day | Streak resets to 0 (after 00:05 UTC job marks as missed) |
| X4 | Rest day preserves streak | No exercise scheduled for Tuesday | Streak unchanged on Wednesday |
| X5 | Longest streak preserved after reset | Achieve 10-day streak, then miss → streak resets | longestStreak still shows 10 |
| X6 | Streak resumes after reset | Miss a day, then log next scheduled day | streak restarts at 1, longestStreak preserved |
| X7 | No active plan, every day is rest day | User with no plan | Streak never breaks (all rest days) |
| X8 | Recurring plan week calculation | 4-week plan, week 2 Thursday | Cycle week calculated correctly relative to plan.createdAt |

### 7.2 Streak UI

| # | Scenario | Steps | Expected Result |
|---|----------|-------|----------------|
| Y1 | View streak screen | Navigate to streak detail | Current streak, longest streak shown |
| Y2 | View streak calendar | Open calendar | Days color-coded: green=completed, red=missed, gray=rest_day |
| Y3 | Navigate calendar months | Tap previous month | History shown correctly |
| Y4 | View empty calendar | New user | Calendar with no completed days |
| Y5 | Calendar year 2020 (boundary) | GET /api/v1/streaks/history?year=2020&month=1 | Valid, empty or with data |
| Y6 | Calendar invalid month | GET /api/v1/streaks/history?year=2026&month=0 | 422 |
| Y7 | Calendar invalid month 13 | month=13 | 422 |
| Y8 | Calendar year out of range | year=2019 or year=2101 | 422 |

---

## 8. Profile & Settings

### 8.1 Viewing Profile

| # | Scenario | Steps | Expected Result |
|---|----------|-------|----------------|
| Z1 | View profile (email user) | Navigate to Profile tab | Display name, email, auth provider badge, bio |
| Z2 | View profile (Google user) | | Shows Google auth indicator |
| Z3 | View profile (guest user) | | Guest badge, GuestUpgradeCard shown |
| Z4 | View user stats | Scroll to stats section | Total workouts, total volume, average session duration, top PRs |

### 8.2 Editing Profile

| # | Scenario | Steps | Expected Result |
|---|----------|-------|----------------|
| AA1 | Edit display name | Change name → save | Updated everywhere (profile, home) |
| AA2 | Edit bio | Add bio text → save | Bio saved and displayed |
| AA3 | Bio at max length | 500-char bio | Accepted |
| AA4 | Bio over max length | 501-char bio | 422 |
| AA5 | Display name over max | 51-char name | 422 |
| AA6 | Update avatar URL (HTTPS) | Enter valid HTTPS URL | Avatar displayed |
| AA7 | Avatar URL without HTTPS | Enter HTTP URL | 422 validation error |
| AA8 | Profile update rate limit | PATCH /users/me 31 times in 15 min | 429 |

### 8.3 Preferences

| # | Scenario | Steps | Expected Result |
|---|----------|-------|----------------|
| AB1 | Switch to imperial units | Settings → Units → Imperial | Weight in lbs, distance in miles |
| AB2 | Switch back to metric | Settings → Units → Metric | Weight in kg, distance in km |
| AB3 | Switch to dark theme | Settings → Theme → Dark | App switches to dark mode |
| AB4 | Switch to light theme | Settings → Theme → Light | App switches to light mode |
| AB5 | System theme | Settings → Theme → System | Follows device dark/light mode |
| AB6 | Invalid units value | PATCH /users/me/preferences with units="feet" | 422 |

### 8.4 Account Deletion

| # | Scenario | Steps | Expected Result |
|---|----------|-------|----------------|
| AC1 | Delete account (email auth) | Enter correct password + "DELETE MY ACCOUNT" phrase | Account deleted, data purged, logged out |
| AC2 | Delete account wrong password | Wrong password entered | 401 |
| AC3 | Delete account wrong phrase | Correct password, wrong confirm phrase | 422 |
| AC4 | Delete account (Google user) | Provide valid idToken + phrase | Account deleted |
| AC5 | Delete account rate limit | Try 6 times in 15 min | 429 |
| AC6 | After deletion, old token | Use tokens after account deletion | 401 (user no longer exists) |

---

## 9. Offline-First Behavior

### 9.1 Working Offline

| # | Scenario | Steps | Expected Result |
|---|----------|-------|----------------|
| AD1 | Enable airplane mode | Turn off wifi + mobile data | Offline banner appears at top of screen |
| AD2 | Browse exercises offline | Open exercise list in airplane mode | Cached exercises from last sync shown |
| AD3 | Create plan offline | Build a new workout plan in airplane mode | Saved to Drift immediately, queued in SyncQueue |
| AD4 | Log session offline | Start and complete a session in airplane mode | Session saved locally, summary shown, queued for sync |
| AD5 | View history offline | Open workout history | Shows locally cached sessions |
| AD6 | View progress offline | Open progress dashboard | Shows locally cached progress data |

### 9.2 Reconnection & Sync

| # | Scenario | Steps | Expected Result |
|---|----------|-------|----------------|
| AE1 | Reconnect after offline work | Turn airplane mode off | Sync triggers after 2-second debounce |
| AE2 | All queued items pushed | After reconnect | SyncState shows "synced", pendingCount = 0 |
| AE3 | Pull server changes | Reconnect | New server data appears in app |
| AE4 | App resume triggers sync | Put app in background, come back | Sync runs if connected |
| AE5 | Periodic sync | Stay online for 5+ minutes | Sync runs automatically in background |
| AE6 | SyncStatus indicator | During active sync | Shows "syncing" spinner |
| AE7 | SyncStatus after sync | After successful sync | Shows "synced" with timestamp |

### 9.3 Sync Edge Cases

| # | Scenario | Steps | Expected Result |
|---|----------|-------|----------------|
| AF1 | 100+ offline sets | Log 100 sets offline (5 sessions × 20 sets) | All queued, pushed in batches of 20 |
| AF2 | Server 500 during push | Simulate server error during push | Items marked failed, retry scheduled |
| AF3 | Single item retry | Item fails once | Retried after 30s backoff |
| AF4 | Item fails 5 times | Simulate 5 consecutive failures | Marked permanently failed, no more retries |
| AF5 | Connectivity flickers | On → off → on within 2 seconds | Debounce prevents double sync, one sync triggered |
| AF6 | Pull transaction failure | Server returns partial pull data mid-transaction | Entire pull rolled back, retried next sync from previous `since` |
| AF7 | Last-write-wins conflict | Edit same plan on two devices offline | Later `updated_at` wins on pull |
| AF8 | Large sync payload | 100 items in one push batch | Server processes all, returns success/failure per item |

---

## 10. Security & Authorization

### 10.1 Endpoint Access Control

| # | Scenario | Steps | Expected Result |
|---|----------|-------|----------------|
| AG1 | Public endpoint without auth | GET /api/v1/exercises | 200 (no auth needed) |
| AG2 | Protected endpoint without auth | GET /api/v1/plans | 401 |
| AG3 | Protected endpoint with valid token | GET /api/v1/plans with valid Bearer token | 200 |
| AG4 | Full-account endpoint as guest | POST /api/v1/plans with guest token | 403 with "upgrade your account" message |
| AG5 | Access own resource | GET /api/v1/plans/:myPlanId | 200 |
| AG6 | Access other user's resource | GET /api/v1/plans/:otherUserPlanId | 404 (not 403 — prevents existence disclosure) |
| AG7 | Log set to another user's session | POST /api/v1/sessions/:otherUserId_sessionId/sets | 404 |
| AG8 | Complete another user's session | POST /api/v1/sessions/:otherSessionId/complete | 404 |

### 10.2 Input Security

| # | Scenario | Steps | Expected Result |
|---|----------|-------|----------------|
| AH1 | Request body over 100kb | Send 101kb JSON body | 413 |
| AH2 | Multiple Zod validation errors | Send body with 3 invalid fields | 422 with `details` array containing all 3 errors |
| AH3 | Non-existent route | GET /api/v1/nonexistent | 404 "Route not found" |
| AH4 | SQL injection in search param | ?search=' OR 1=1 -- | Prisma parameterizes queries, returns 200 with no results (not 500) |
| AH5 | XSS in displayName | displayName = "<script>alert(1)</script>" | Stored as plain text, never executed (API returns JSON) |
| AH6 | Oversized array in sync push | items array with 101 items | 422 (max 100) |

### 10.3 Token Security

| # | Scenario | Steps | Expected Result |
|---|----------|-------|----------------|
| AI1 | Use refresh token as access token | Send refreshToken in Authorization header | 401 (different claims structure) |
| AI2 | Use access token as refresh token | POST /auth/refresh with accessToken as refreshToken | 401 |
| AI3 | Password reset token used as refresh | Use reset token in Authorization header | 401 |
| AI4 | Decode JWT, modify isGuest=false, re-sign | Attempt signature bypass | 401 (server verifies signature) |

---

## 11. Complex Real-World Scenarios

### Scenario A: Full Week of Push/Pull/Legs

**Goal:** Verify streak + plan scheduling + progress all work correctly for a full training week.

```
Day 1 (Monday):
  1. Create PPL plan: Push Mon, Pull Wed, Legs Fri. Tue/Thu/Sat/Sun = rest days.
  2. Start Monday push session (Bench Press, OHP, Tricep Pushdown)
  3. Log 4 sets each: Bench 4×8 @ 80kg, OHP 4×10 @ 60kg, Tricep 3×12 @ 30kg
  4. Complete session
  5. Check: WorkoutSummary shown, new PRs if first time
  
Day 2 (Tuesday — rest day):
  6. Don't log any session
  7. After 00:05 UTC: streak check → rest day → streak holds at 1
  
Day 3 (Wednesday):
  8. Start and complete Pull session (Deadlift, Pull-up, Rows, Bicep Curls)
  9. After 00:05 UTC: streak = 2

Day 4 (Thursday — rest day):
  10. Skip. Streak holds at 2.

Day 5 (Friday):
  11. Start and complete Legs session (Squat, Leg Press, Romanian Deadlift)
  12. After 00:05 UTC: streak = 3

Days 6-7 (Sat/Sun — rest):
  13. Streak holds at 3

End-of-week checks:
  - Progress dashboard shows volume for 3 sessions
  - Personal records updated for Bench, Deadlift, Squat
  - Streak calendar shows Mon/Wed/Fri green, rest days gray
  - Streak: current=3, longest=3
```

### Scenario B: Guest to Full Account Migration

**Goal:** Verify offline data survives the upgrade.

```
1. Open app as guest (no internet needed)
2. Enable airplane mode
3. Create workout plan "My First Plan"
4. Log 3 sessions with sets
5. Complete all 3 sessions
6. Reconnect to internet
7. Navigate to Profile → tap "Create an Account"
8. Enter email + password → upgrade
9. App syncs all 3 sessions + plan to server
10. Verify: Plan visible in plans list, sessions visible in history
11. Progress dashboard shows data from those 3 sessions
12. Logout and log back in with new credentials
13. All data still visible
```

### Scenario C: Personal Record Cascade

**Goal:** Test PR detection across all 4 record types.

```
Session 1 (baseline):
  - Bench Press: 3 × 10 @ 75kg
  - Completed → PRs set: maxWeight=75, maxReps=10, maxVolume=75×10×3=2250, 1RM≈100kg

Session 2 (beat weight):
  - Bench Press: Set1: 80kg×8, Set2: 82.5kg×6, Set3: 80kg×4
  - Complete session
  - Expected summary: New PR — maxWeight 82.5kg (was 75kg)
  - Expected: maxVolume = 80×8 + 82.5×6 + 80×4 = 640+495+320 = 1455 < 2250 → no volume PR
  
Session 3 (beat volume):
  - Bench Press: 5 × 12 @ 77.5kg
  - maxVolume = 77.5 × 12 × 5 = 4650 > 2250
  - Expected: New volume PR
  - maxWeight still 82.5 (not beaten)

Running PR:
  - Session 1: 5km in 30min (pace = 6:00/km = 360 sec/km)
  - Session 2: 5km in 28min (pace = 336 sec/km)
  - Expected on Session 2: New best pace PR
```

### Scenario D: App Killed Mid-Session + Recovery

**Goal:** Verify session state survives unexpected app termination.

```
1. Start an active workout session
2. Log 5 sets
3. Force-kill the app (don't complete)
4. Reopen app
5. Expected: 
   - App restores to correct screen (or shows "Resume session?" prompt)
   - Session is still in_progress in Drift
   - 5 previously logged sets still present
6. Continue logging 5 more sets
7. Complete session normally
8. Summary shows all 10 sets
```

### Scenario E: Complete Account Lifecycle

**Goal:** E2E test of the entire app from registration to data-rich usage.

```
1. Register with email + strong password
2. Verify: Splash → Login → Home
3. Browse exercise library: search "squat", filter by Legs muscle group
4. Create 4-week recurring strength plan:
   - Week 1-4, Monday: Upper (Bench, OHP, Pull-up, Row)
   - Week 1-4, Thursday: Lower (Squat, Deadlift, Leg Press)
5. Add exercises with targets: 4×8, "8-12" reps, 80% of max
6. Start first Upper session from plan
7. Log 4×8 @ bodyweight for Pull-up (isWarmup for set 1)
8. Log 4×8 @ 80kg Bench, 4×10 @ 60kg OHP
9. Complete session → summary + PRs
10. Check streak = 1 (next day after job)
11. Navigate to progress: Bench Press chart shows first data point
12. Edit profile: add display name "Test User", bio "Phase 1 tester"
13. Switch to dark theme in settings
14. Switch units to imperial → verify weights show in lbs
15. Switch back to metric
16. Logout
17. Log back in → session restored, all data visible
18. Start Lower session (Thursday)
19. Log Squat: 5×5 @ 100kg
20. Complete → new squat PRs
21. Check progress → Squat shows data point
22. Check streak after next job → streak = 2 (Mon + Thu logged, Tue/Wed = rest days for this plan? depends on plan days)
23. View streak calendar → correct days colored
```

### Scenario F: Rapid Set Logging Performance Test

**Goal:** Verify offline write speed meets < 100ms target.

```
1. Start active session (airplane mode for pure offline)
2. Log 30 sets back-to-back as fast as possible
3. Each set: reps=10, weight=100kg (minimal input)
4. Expected: Each tap completes instantly (< 100ms Drift write)
5. Complete session → all 30 sets visible in summary
6. Reconnect → all 30 sets sync to server
7. Check session detail → all 30 sets with correct values
```

### Scenario G: Streak Break and Recovery

**Goal:** Verify streak math is correct across a miss-and-recovery cycle.

```
1. Log sessions 10 days in a row (with plan scheduled every day)
2. After day 10: streak = 10, longestStreak = 10
3. Day 11: miss the workout (plan has session scheduled)
4. After 00:05 UTC on day 12: 
   - StreakHistory[day 11].status = missed
   - currentStreak = 0
   - longestStreak = 10 (preserved)
5. Log session day 12: streak = 1 after job
6. Log sessions days 13-21 (9 more days): streak = 10
7. Log day 22: streak = 11 → new longestStreak!
8. Verify: longestStreak = 11, currentStreak = 11
```

### Scenario H: Custom Exercise Lifecycle

**Goal:** Verify custom exercises work end-to-end including plan integration.

```
1. Create custom exercise "Landmine Press" (strength, shoulders + upper chest)
2. Verify: visible in exercise list with custom badge
3. Filter by shoulders → "Landmine Press" appears
4. Create a workout plan
5. Add "Landmine Press" to Monday with targets: 4×10 @ 30kg
6. Start session → "Landmine Press" pre-loaded
7. Log sets
8. Complete session → PR for "Landmine Press" established
9. View exercise progress → chart for Landmine Press
10. Try to delete "Landmine Press" → success (you are the creator)
11. Check plan → planDayExercise still references deleted exercise (verify cascade behavior)
12. Try to log next session → what happens when plan exercise is deleted?
```

### Scenario I: Multi-Device Token Refresh Race

**Goal:** Verify two devices refreshing simultaneously doesn't cause issues.

```
Setup: Same account logged in on Device A and Device B

1. Both devices' access tokens expire at similar times
2. Device A makes an API call → gets 401 → triggers /auth/refresh
3. Device B makes an API call at the same time → gets 401 → also triggers /auth/refresh
4. Both refresh requests hit server nearly simultaneously
5. Expected:
   - Both succeed (server issues separate tokens with different jti)
   - Both devices get new tokens
   - Neither device is logged out
   - Session count increments by 2 (within 20-session cap)
6. Both devices can continue making API calls
```

### Scenario J: Sync Failure Recovery

**Goal:** Verify exponential backoff and eventual success.

```
1. Go offline
2. Log a session with 10 sets
3. Come online → sync push starts
4. Server is intentionally returning 500 for push endpoint
5. Expected after attempt 1: item marked failed, retry in 30s
6. Still failing after attempt 2: retry in 60s
7. Fix server issue
8. Attempt 3: SUCCESS
9. Verify: all 10 sets present in server database
10. SyncState shows "synced", pendingCount = 0
```

---

## 12. API-Level Edge Cases

### 12.1 Pagination Stability

| # | Scenario | Expected |
|---|----------|---------|
| PA1 | New session inserted while paginating history | Cursor-based pagination prevents duplicate/missing items |
| PA2 | Limit = 1 | Returns 1 item, has_more = true if more exist |
| PA3 | Limit = 100 (max) | Returns up to 100 items |
| PA4 | Limit = 101 (over max) | 422 |
| PA5 | Cursor from page 1 used for page 2 | Correct next page returned |
| PA6 | Cursor from deleted session | Graceful (returns next valid item or empty) |

### 12.2 Health Check

| # | Scenario | Expected |
|---|----------|---------|
| HC1 | GET /api/v1/health (all healthy) | 200, `{ status: "ok", services: { database: "ok", redis: "ok" } }` |
| HC2 | GET /api/v1/health (no auth needed) | 200 without Authorization header |
| HC3 | Uptime value | Positive number of seconds since server start |

### 12.3 Sync Push Edge Cases

| # | Scenario | Expected |
|---|----------|---------|
| SP1 | Push create operation | Record inserted in correct table |
| SP2 | Push update operation | Record upserted (update or insert) |
| SP3 | Push delete operation | Record soft-deleted or deleted |
| SP4 | Push unsupported table | entityTable = "users" | 422 (not in allowed list) |
| SP5 | Push record owned by other user | Server rejects with ownership error |
| SP6 | Push 100 items (max) | All processed |
| SP7 | Push 101 items (over max) | 422 |
| SP8 | Push empty items array | 422 (or 200 with empty results — check implementation) |

### 12.4 Sync Pull Edge Cases

| # | Scenario | Expected |
|---|----------|---------|
| PL1 | Pull with no `since` (initial sync) | Returns all data for user |
| PL2 | Pull with recent `since` (delta sync) | Returns only changed records since that timestamp |
| PL3 | Pull with future `since` | Returns empty data (no changes in the future) |
| PL4 | Pull with invalid ISO date | 422 |
| PL5 | Pull while another pull is in flight | Both complete, client handles duplication gracefully |

---

## Testing Checklist Summary

Before marking Phase 1 MVP as fully tested, verify:

### Auth
- [ ] Registration + login + token refresh + logout
- [ ] Social auth (Google + Apple)  
- [ ] Guest + upgrade
- [ ] Password reset full flow
- [ ] Rate limits on all auth endpoints
- [ ] Token expiry + auto-refresh in app

### Core Features
- [ ] Exercise library browse + filter + search
- [ ] Custom exercise CRUD
- [ ] Workout plan create + edit + delete
- [ ] Plan exercise management (add, reorder, targets, delete)
- [ ] Active session: start, log sets, complete, abandon
- [ ] Personal records detected on session completion
- [ ] Workout history: list + filter + detail
- [ ] Progress charts + PRs + volume
- [ ] Streak calculation + calendar
- [ ] Profile edit + preferences + account deletion

### Cross-Cutting
- [ ] Offline-first: create plans + log sessions in airplane mode
- [ ] Sync: reconnect triggers push + pull
- [ ] Sync retry: verify exponential backoff behavior
- [ ] Authorization: guest blocked from full-account endpoints
- [ ] Cross-user isolation: User A cannot access User B's data
- [ ] Validation: all known invalid inputs return 422 with field-level errors
- [ ] Rate limits trigger 429 on all rate-limited endpoints

### Complex Flows
- [ ] Full week of PPL (Scenario A)
- [ ] Guest → full account migration (Scenario B)
- [ ] PR cascade across all 4 types (Scenario C)
- [ ] App killed mid-session + recovery (Scenario D)
- [ ] Complete account lifecycle E2E (Scenario E)
