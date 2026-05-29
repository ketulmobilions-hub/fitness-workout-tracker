# Manual QA Test Plan — Phase 1 MVP

**Author:** QA Engineering
**Scope:** Fitness Workout Tracker mobile app (Flutter) + backend (Node.js/Express)
**Phase:** 1 (MVP)
**Build under test:** `main` @ commit `5688c97`
**Status:** Ready for execution

---

## 1. Purpose & Approach

This document drives **manual, device-level black-box testing** of the MVP. It complements the API-focused `test-scenarios.md`. Where that document covers contract behavior, this one covers what a real user sees and feels: taps, scrolls, transitions, error toasts, offline/online transitions, low-memory pressure, locale, accessibility, and cross-platform parity.

**Tester mindset:** assume nothing works until you have proven it works on a real device under realistic network and device conditions. Treat any UI freeze >300ms, any unhandled error surfaced as a raw stack trace, any data loss after backgrounding, and any inconsistency between offline and online state as a **P0 defect**.

---

## 2. Test Environment Matrix

Execute the full plan on every combination below unless noted. Smoke pass per device/OS, full pass on at least one device per platform.

| Platform | OS Version | Device Class | Network | Build |
|----------|-----------|-------------|---------|-------|
| iOS | 17.x | iPhone 15 (modern) | Wi-Fi | Release (TestFlight) |
| iOS | 16.x | iPhone SE 2nd gen (small + low-mem) | LTE | Release |
| iOS | 18.x | iPad (large layout) | Wi-Fi | Release |
| Android | 14 | Pixel 7 (modern) | Wi-Fi | Release (AAB) |
| Android | 12 | Samsung A-series (mid-range) | 4G | Release |
| Android | 10 | Budget device (low-mem) | 3G throttled | Release |

**Backend env:** staging (Render). All API mutations should be visible in the staging DB. Never test against production.

**Test accounts:** create fresh accounts per cycle. Use `qa+<scenario>-<timestamp>@example.com` to keep history isolated. Reserve one "long-history" account (≥60 days of workouts) for streak and progress regression.

---

## 3. Test Data Prerequisites

- [ ] Backend seeded with exercise library (issue #15 seed run)
- [ ] At least one pre-existing user with: 1 active plan, 30 completed sessions, 14-day streak
- [ ] One empty user (no plans, no sessions)
- [ ] One guest-mode session with local-only data
- [ ] Two devices logged into the same account for sync conflict tests

---

## 4. Severity Definitions

| Severity | Definition | Examples |
|----------|-----------|----------|
| **P0 — Blocker** | Data loss, crash, security exposure, user cannot complete primary flow | App crashes on login, set logs disappear after backgrounding, JWT leaked in logs |
| **P1 — Critical** | Primary flow degraded, workaround exists | Cardio timer drifts >5s, sync takes >30s on reconnect, validation error not shown |
| **P2 — Major** | Secondary feature broken, UX inconsistency | Chart axis labels overlap, streak count off-by-one for one timezone, back button skips a screen |
| **P3 — Minor** | Cosmetic, copy, low-impact edge case | Misaligned padding, typo in empty state, animation jank under 100ms |

---

## 5. Test Suites

### 5.1 Authentication — Email/Password

**Pre-condition:** fresh install, no stored tokens.

| ID | Scenario | Steps | Expected | Sev |
|----|----------|-------|----------|-----|
| AUTH-001 | First-launch routing | Cold open app | Lands on welcome/auth landing; no flash of authenticated UI | P0 |
| AUTH-002 | Register happy path | Tap Sign Up → enter valid email + 12-char password + display name → Submit | Account created, lands on home/today screen, tokens persisted | P0 |
| AUTH-003 | Register — duplicate email | Register with already-used email | Inline field error "Email already registered"; no toast spam; focus moves to email field | P1 |
| AUTH-004 | Register — weak password | Password = "abc12345" (no symbol/upper, length ok) | If policy enforces complexity, inline error appears as user types after blur | P1 |
| AUTH-005 | Register — invalid email format | Type `notanemail` → blur | Inline error visible BEFORE submit attempt | P2 |
| AUTH-006 | Register — submit while offline | Airplane mode → submit form | Banner/toast "No internet"; form values retained; no infinite spinner | P1 |
| AUTH-007 | Login happy path | Enter valid creds → Submit | Lands on home, no relogin prompt after backgrounding | P0 |
| AUTH-008 | Login — wrong password | Wrong password | Generic error, no enumeration; field error not shown on email | P1 |
| AUTH-009 | Login — caps lock indicator | Caps lock on, focus password field | UI hints caps lock state if iOS/Android supports | P3 |
| AUTH-010 | Login — paste password from manager | Use iOS Passwords / Google Smart Lock to autofill | Works without manual trim of whitespace | P1 |
| AUTH-011 | Password reset link | Tap "Forgot password" | Either implemented end-to-end or feature is hidden, never a dead button | P1 |
| AUTH-012 | Sign-out clears session | Sign out → kill app → reopen | Back at landing, no stored tokens | P0 |
| AUTH-013 | Sign-out clears local DB sensitive data | Sign out → re-sign in as different user | Previous user's plans/sessions not visible | P0 |

### 5.2 Authentication — OAuth (Google / Apple)

| ID | Scenario | Steps | Expected | Sev |
|----|----------|-------|----------|-----|
| OAUTH-001 | Google sign-in first time | Tap Google → select account → consent | Account created/linked, lands on home | P0 |
| OAUTH-002 | Apple sign-in first time (iOS only) | Tap Apple → Face ID → use my email | Account created with relay email | P0 |
| OAUTH-003 | OAuth cancel mid-flow | Start OAuth → dismiss provider sheet | Returns to auth screen, no error toast, no loading stuck | P1 |
| OAUTH-004 | OAuth account already exists via email | Sign up with email A, then Google with same email A | Either auto-link (preferred) or clear "use email login" message — never silent failure | P0 |
| OAUTH-005 | Apple — "hide my email" relay | Use Apple relay | Backend stores relay; user can still receive emails | P1 |
| OAUTH-006 | Revoke OAuth from provider, reopen app | Revoke in Google Account → relaunch | Forced re-auth, clean error, no crash | P1 |

### 5.3 Guest Mode

| ID | Scenario | Steps | Expected | Sev |
|----|----------|-------|----------|-----|
| GUEST-001 | Enter guest mode | Tap "Continue as guest" | Lands on home with limited capability indicator | P0 |
| GUEST-002 | Guest creates plan + logs session | Full create plan → log session → close app → reopen | Data persists locally | P0 |
| GUEST-003 | Guest upgrade to full account | Tap upgrade → register → all guest data migrated under new user ID | Plans, sessions, streak intact; appears in account on second device after login | P0 |
| GUEST-004 | Guest tries restricted feature | Try a premium-gated action (if any) | Soft block with upgrade CTA | P2 |
| GUEST-005 | Guest token expiry | Anonymous JWT expires | Auto-refresh transparent; no forced logout that wipes local data | P1 |

### 5.4 JWT & Session Lifecycle

| ID | Scenario | Steps | Expected | Sev |
|----|----------|-------|----------|-----|
| JWT-001 | Token auto-refresh | Wait for access token TTL → trigger API call | Single 401 → refresh → original call retried, user sees no error | P0 |
| JWT-002 | Refresh token expired | Manipulate clock or wait | Single forced logout; in-flight writes flushed if possible | P0 |
| JWT-003 | Concurrent 401 storm | Trigger 5 requests after access expiry | Single refresh, all queued requests resume — not 5 refreshes | P1 |
| JWT-004 | Token stored securely | Inspect device storage (Keychain / Keystore) | Tokens NOT in plain `SharedPreferences` / `NSUserDefaults` | P0 |
| JWT-005 | Background → foreground after 8h | Backgrounded overnight → resume | Refresh on resume; or graceful re-auth prompt | P1 |

### 5.5 Exercise Library

| ID | Scenario | Steps | Expected | Sev |
|----|----------|-------|----------|-----|
| EX-001 | Open library | Tap exercises tab | List loads <2s on Wi-Fi; skeleton or spinner shown | P0 |
| EX-002 | Scroll performance | Scroll continuously for 5s | 60fps target, no jank, no rebuild flicker | P1 |
| EX-003 | Search — exact match | Type "bench press" | Result shown, debounce <300ms | P1 |
| EX-004 | Search — partial / fuzzy | Type "benc" | Returns Bench Press if fuzzy is intended | P2 |
| EX-005 | Search — no results | Type "asdfqwer" | Empty state with helpful copy, not blank screen | P2 |
| EX-006 | Search — special chars | Type `"); DROP TABLE--` | No crash, normal "no results" handling | P0 |
| EX-007 | Filter by muscle group | Apply chest filter | Only chest-primary exercises shown; count matches header | P1 |
| EX-008 | Filter by type (strength/cardio/stretch) | Apply cardio | Only cardio results | P1 |
| EX-009 | Combine filters | Chest + strength | Intersect, not union | P2 |
| EX-010 | Clear filters | Tap clear | All exercises reappear, scroll resets to top | P3 |
| EX-011 | Exercise detail | Tap row | Detail screen with name, description, instructions, media | P1 |
| EX-012 | Detail — missing media | Open exercise without media | Placeholder image, no broken-image icon | P2 |
| EX-013 | Detail — long instructions | Open exercise with multi-paragraph instructions | Scrollable, no clipped text | P2 |
| EX-014 | Create custom exercise (if exposed in MVP) | Add custom → save → reopen library | Custom exercise tagged, owner can edit/delete; other users cannot see | P1 |
| EX-015 | Library while offline | Airplane mode → open library | Cached library renders from Drift; clear "offline" indicator | P0 |

### 5.6 Workout Plans

| ID | Scenario | Steps | Expected | Sev |
|----|----------|-------|----------|-----|
| PLAN-001 | Empty plan list | New user opens plans tab | Empty state with "Create plan" CTA | P2 |
| PLAN-002 | Create weekly plan | Name → schedule weekly → add 3 days → add 4 exercises per day → save | Plan visible in list, opens with correct structure | P0 |
| PLAN-003 | Create recurring plan with weeks | weeks_count=4 | All 4 weeks renderable, day_of_week + week_number respected | P1 |
| PLAN-004 | Validation — missing name | Save without name | Inline error; save disabled until valid | P2 |
| PLAN-005 | Reorder exercises within day | Drag exercise card | Order persists after save and reopen | P1 |
| PLAN-006 | Reorder days | Drag day | Order persists | P2 |
| PLAN-007 | Edit existing plan | Open plan → add exercise → save | Diff persisted; sort_order not corrupted | P1 |
| PLAN-008 | Delete plan with sessions | Plan that has logged sessions → delete | Sessions remain (orphan plan_id or soft-delete); no DB FK crash | P0 |
| PLAN-009 | Set active plan | Toggle active on Plan A while Plan B was active | Only one active per user enforced server-side | P1 |
| PLAN-010 | Target reps in non-numeric format | Enter "8-12" as reps | Stored as string, displayed verbatim in active session | P2 |
| PLAN-011 | Plan with 0 exercises in a day | Save plan with empty day | Either prevented or session-start handles empty day | P1 |
| PLAN-012 | Plan with very long name | 200 chars | Truncated in list with ellipsis, full visible in detail | P3 |
| PLAN-013 | Create plan offline | Airplane mode → create | Saved to Drift with pending sync; appears in list with sync badge | P0 |

### 5.7 Active Workout Session — Strength

| ID | Scenario | Steps | Expected | Sev |
|----|----------|-------|----------|-----|
| SESS-001 | Start session from plan day | Tap day → Start | Session created, status=in_progress, started_at recorded | P0 |
| SESS-002 | Log set — reps + weight | Enter 10 reps × 60kg → mark complete | set_log persisted, UI ticks set as done | P0 |
| SESS-003 | Log multiple sets | Complete 3 sets | set_number increments; cannot duplicate | P0 |
| SESS-004 | Skip set | Tap skip | Set marked skipped, does not break PR calculation | P1 |
| SESS-005 | Mark warmup | Toggle is_warmup on set 1 | Warmup excluded from PR / volume calculation | P1 |
| SESS-006 | Add ad-hoc exercise mid-session | Add exercise not in plan | exercise_log appended; sort_order > planned exercises | P1 |
| SESS-007 | Remove exercise mid-session | Long-press → remove | Removed from session; underlying plan not modified | P2 |
| SESS-008 | RPE entry | Enter RPE 8 | Persisted; out-of-range (>10 or <0) blocked | P2 |
| SESS-009 | Background mid-set | Backgrounded for 5 min → resume | State exactly restored, no data loss, no double-submit | P0 |
| SESS-010 | Kill app mid-set | Force-kill → reopen | Resume "in progress" session prompt; partial data restored | P0 |
| SESS-011 | Complete session | Tap finish | completed_at, duration_sec set; lands on summary | P0 |
| SESS-012 | Abandon session | Discard | status=abandoned; data preserved for forensic but excluded from streak | P1 |
| SESS-013 | Start second session while one in_progress | Try start another | Either resume existing or warn; never silently orphan | P0 |
| SESS-014 | Decimal weight (e.g. 22.5 kg) | Enter 22.5 | Accepted; correct unit shown | P1 |
| SESS-015 | Imperial unit user (lbs) | Settings → lbs → log set | UI shows lbs throughout, conversion correct (if both supported) | P1 |
| SESS-016 | Numeric keyboard | Tap reps/weight field | Numeric pad opens; decimal point available for weight | P2 |
| SESS-017 | Keyboard dismissal | Tap outside field | Keyboard dismisses without losing in-progress entry | P2 |
| SESS-018 | Rapid logging | Log 30 sets in 60s | All persisted, no UI lag, no duplicates | P1 |

### 5.8 Active Workout Session — Cardio

| ID | Scenario | Steps | Expected | Sev |
|----|----------|-------|----------|-----|
| CARD-001 | Start cardio set with duration | Enter 30 min run | Stored as duration_sec | P0 |
| CARD-002 | Distance + pace auto-calc | Enter 5km in 30 min | pace_sec_per_km derived correctly | P1 |
| CARD-003 | Heart rate entry | Enter HR 145 | Persisted | P2 |
| CARD-004 | Cardio with no distance | Duration only | Pace omitted, no NaN displayed | P2 |
| CARD-005 | Background during cardio | Backgrounded for 10 min | Elapsed time correct on resume (not paused) if timer expected to run | P1 |
| CARD-006 | Switch app mid-cardio | Switch to Spotify, return | No state loss; timer accurate | P1 |

### 5.9 Workout History

| ID | Scenario | Steps | Expected | Sev |
|----|----------|-------|----------|-----|
| HIST-001 | Empty history | New user | Empty state with helpful copy | P2 |
| HIST-002 | History list ordering | View list | Newest first; date headers correctly grouped | P1 |
| HIST-003 | Open session detail | Tap session | Shows exercises, sets, weight × reps, duration, notes | P0 |
| HIST-004 | Pagination / infinite scroll | Scroll past 20 items | Cursor pagination loads next page seamlessly | P1 |
| HIST-005 | Pull-to-refresh | Pull down | Refetches; preserves scroll position if no new data | P2 |
| HIST-006 | Session detail — abandoned | Open abandoned session | Clearly marked abandoned | P2 |
| HIST-007 | Delete past session | Long-press → delete | Confirmation; removed from list; recalculates streak/PRs | P1 |
| HIST-008 | Filter by date range | Apply last-7-days filter (if exposed) | Correct subset shown | P2 |

### 5.10 Progress Tracking

| ID | Scenario | Steps | Expected | Sev |
|----|----------|-------|----------|-----|
| PROG-001 | Open progress dashboard | Tap progress tab | Loads with summary cards (volume, sessions, PRs) | P0 |
| PROG-002 | Volume chart — last 30 days | Default view | X-axis dates, Y-axis volume, no overlapping labels | P1 |
| PROG-003 | Empty progress (new user) | New account opens dashboard | Empty state, not crash; chart placeholder | P1 |
| PROG-004 | Single-session user | Only 1 session | Chart renders with single data point | P2 |
| PROG-005 | Per-exercise progress | Open Bench Press progress | Best set per session plotted, PR markers visible | P1 |
| PROG-006 | PR detection — new max weight | Log new max | PR badge appears within session summary | P0 |
| PROG-007 | PR detection — max reps at same weight | Same weight, more reps | Triggers max_reps PR | P1 |
| PROG-008 | PR detection — cardio best pace | New 5K PR | Best pace PR recorded | P1 |
| PROG-009 | Chart interaction | Tap data point | Tooltip with date + value | P2 |
| PROG-010 | Statistics over 1 year | Long-history account | Aggregates correct, no timeouts | P1 |
| PROG-011 | Progress while offline | Airplane mode | Cached aggregates render, "as of" timestamp shown | P1 |

### 5.11 Streaks

| ID | Scenario | Steps | Expected | Sev |
|----|----------|-------|----------|-----|
| STR-001 | First-ever workout | Complete first session | Streak = 1 | P0 |
| STR-002 | Consecutive day workout | Complete session day N+1 | Streak = 2 | P0 |
| STR-003 | Missed day | Complete day N, skip N+1, complete N+2 | Streak resets to 1 | P0 |
| STR-004 | Rest day on plan | Plan-defined rest day | Does not break streak (plan-aware logic from issue #28) | P0 |
| STR-005 | Two sessions same day | Complete 2 sessions on day N | Streak counts day, not session | P1 |
| STR-006 | Timezone change mid-streak | Fly NYC → Tokyo, complete session | Streak uses user's local date, not UTC; no double-count | P0 |
| STR-007 | Streak display on home | Open app | Current streak prominent; longest streak secondary | P1 |
| STR-008 | Calendar view | Open streak calendar | Completed/rest/missed days color-coded; today highlighted | P1 |
| STR-009 | Milestone celebration | Hit 7 / 30 / 100 days | Celebration UI (confetti/modal) fires once, not on every open | P1 |
| STR-010 | Streak after backend daily job | Wait for BullMQ daily streak job | History reflects "missed" day automatically | P1 |
| STR-011 | Streak with no active plan | Log sessions without plan | Streak still increments based on session-per-day | P2 |
| STR-012 | Delete session that anchored streak | Delete today's session | Streak decrements correctly | P1 |

### 5.12 Profile & Settings

| ID | Scenario | Steps | Expected | Sev |
|----|----------|-------|----------|-----|
| PROF-001 | View profile | Tap profile tab | Display name, avatar, member-since visible | P1 |
| PROF-002 | Edit display name | Change → save | Persists, reflected across app immediately | P1 |
| PROF-003 | Upload avatar | Pick image | Uploaded, thumbnail visible, no orientation flip | P2 |
| PROF-004 | Change password | Old → new → confirm | Existing sessions invalidated on other devices | P0 |
| PROF-005 | Toggle unit preference (kg/lbs) | Switch | All session UI updates without restart | P1 |
| PROF-006 | Notification preferences | Toggle | Persisted, FCM tag updated server-side (Phase 2 link) | P2 |
| PROF-007 | Sign out | Tap sign out | Confirmation dialog; clears tokens and PII | P0 |
| PROF-008 | Delete account (GDPR) | Settings → delete account → confirm | All user data deleted server-side; cascade verified; cannot re-login | P0 |
| PROF-009 | Account deletion with pending sync | Pending writes in queue → delete account | Pending writes discarded, no orphan data | P1 |
| PROF-010 | About / version info | Open About | App version, build number, links to T&Cs | P3 |
| PROF-011 | Long display name | 50 chars | Truncated with ellipsis in header, full in profile | P3 |
| PROF-012 | Avatar — huge image (50MB) | Pick large image | Either client-resized before upload or graceful "too large" error | P1 |

### 5.13 Navigation & App Shell

| ID | Scenario | Steps | Expected | Sev |
|----|----------|-------|----------|-----|
| NAV-001 | Tab switching | Tap each bottom tab | Each loads, state preserved when returning | P1 |
| NAV-002 | Tab badge for in-progress session | Start session → switch tab | Indicator on session/home tab | P2 |
| NAV-003 | Deep back navigation | Drill 4 screens deep → back-back-back-back | Each pop is single screen, never skips | P1 |
| NAV-004 | Android hardware back from root | Press back on home tab | Backgrounds app, does not exit to login | P1 |
| NAV-005 | iOS swipe back | Edge-swipe on detail screens | Works on iOS where expected | P2 |
| NAV-006 | Deep link / cold-start with route | (if applicable) open via URL | Lands on correct screen authenticated; otherwise auth then route | P2 |
| NAV-007 | Rotation (iPad / Android tablet) | Rotate device | Layout adapts, no overflow | P2 |
| NAV-008 | Dark mode | System dark mode | All screens respect; no white flashes | P1 |
| NAV-009 | Dynamic type / large fonts | iOS Accessibility → XXL | Text scales, no clipping in cards, buttons, tabs | P1 |
| NAV-010 | RTL locale (if supported) | System lang → Arabic | Layouts mirror correctly; charts unaffected | P2 |

### 5.14 Offline-First & Sync

> **Critical area.** Bugs here cause silent data loss. Run on real devices toggling airplane mode, not simulators.

| ID | Scenario | Steps | Expected | Sev |
|----|----------|-------|----------|-----|
| SYNC-001 | Cold start offline | Airplane mode → launch | App opens to cached state; no infinite spinner | P0 |
| SYNC-002 | Log session offline | Airplane on → complete full session | Saved to Drift; pending-sync badge | P0 |
| SYNC-003 | Reconnect triggers sync | Disable airplane | Sync starts within 5s; pending badge clears per item | P0 |
| SYNC-004 | Sync queue ordering | Create plan A offline → log session against A offline → reconnect | Plan creates BEFORE session insert; FK satisfied | P0 |
| SYNC-005 | Conflict — same field edited on two devices | Edit display name on phone offline, on tablet online → both come online | Last-write-wins based on updated_at; UI shows winning value | P0 |
| SYNC-006 | Conflict — same set log on two devices | Log set on both offline | Last writer wins; no duplicate records | P0 |
| SYNC-007 | Sync after long offline (7 days) | Offline for a week with activity | Bulk replay succeeds; respects rate limits | P1 |
| SYNC-008 | Sync failure mid-batch | Reconnect on flaky Wi-Fi → partial batch | Resumes from last successful record; no double-apply | P0 |
| SYNC-009 | 401 during sync | Token expires mid-sync | Refresh → resume; no data loss | P0 |
| SYNC-010 | 4xx (validation) during sync | Server rejects malformed local record | Item parked in dead-letter; user surface error; rest of queue continues | P1 |
| SYNC-011 | 5xx during sync | Server 500 | Retry with backoff; UI not stuck | P1 |
| SYNC-012 | Clock skew | Device clock 1h ahead | updated_at still resolves correctly (server-stamped where possible) | P1 |
| SYNC-013 | Network transition (Wi-Fi → cell) | Mid-sync change network | Sync resumes; no duplicate writes | P1 |
| SYNC-014 | Sync indicator UX | Trigger sync | Per-item or global indicator clear; never "stuck" without progress | P2 |
| SYNC-015 | Large queue (200 pending writes) | Simulate | Completes in reasonable time, app remains responsive | P1 |
| SYNC-016 | Reinstall app, login | Reinstall → login | Server is source of truth; full hydrate; local DB rebuilt | P0 |
| SYNC-017 | Two devices same user, both online | Edit on A, observe B | B reflects change within reasonable interval (push or pull) | P1 |
| SYNC-018 | Delete while offline | Delete plan offline → reconnect | Server delete confirmed; no resurrection from server pull | P0 |
| SYNC-019 | Local DB encryption | Inspect Drift file | Sensitive fields encrypted or DB inaccessible without app | P0 |

### 5.15 Security & Privacy

| ID | Scenario | Steps | Expected | Sev |
|----|----------|-------|----------|-----|
| SEC-001 | HTTPS only | MITM proxy attempt | App refuses connection on cert pin failure (if pinned) or warns | P0 |
| SEC-002 | Token in logs | Run `flutter logs` during auth | No JWT, password, or refresh token in logs | P0 |
| SEC-003 | Screenshot redaction (optional) | Background app | App snapshot in app-switcher does not show PII (if redaction enabled) | P2 |
| SEC-004 | Biometric re-auth (optional) | If enabled, reopen app | Face ID / fingerprint prompt | P2 |
| SEC-005 | Authorization — other user's data | Modify request to fetch another user's session ID | 403, no data leakage | P0 |
| SEC-006 | Authorization — write to other user's plan | PATCH /plans/:id with non-owner token | 403 | P0 |
| SEC-007 | Guest cannot access full-user routes | Guest token to premium endpoint | 403 | P1 |
| SEC-008 | Password reset token reuse | Use reset link twice | Second use rejected | P1 |
| SEC-009 | Account enumeration via reset | Reset for unknown email | Same generic success response as known email | P1 |
| SEC-010 | Rate limit on auth | 11 failed logins | 429 after 10 | P1 |
| SEC-011 | SQL injection in search | Already covered in EX-006 — verify server logs | No DB error logged | P0 |
| SEC-012 | XSS in display name | Name = `<script>alert(1)</script>` | Rendered as text everywhere, no execution | P0 |

### 5.16 Performance & Stability

| ID | Scenario | Steps | Expected | Sev |
|----|----------|-------|----------|-----|
| PERF-001 | Cold start time | Measure from tap to interactable | < 2s on mid-range device | P1 |
| PERF-002 | Warm start time | Background → foreground | < 500ms | P2 |
| PERF-003 | Workout log action latency | Tap "complete set" | < 100ms perceived | P1 |
| PERF-004 | Library scroll fps | Profile with Flutter DevTools | ≥ 55 fps sustained | P2 |
| PERF-005 | Memory after 30-min usage | Run varied flows | No leak >10MB/min; no OOM on 2GB device | P1 |
| PERF-006 | Battery drain idle | App in foreground 10 min idle | < 2% drain on modern device | P2 |
| PERF-007 | API p95 | Backend metrics | < 200ms p95 under expected load | P1 |
| PERF-008 | Photo / avatar upload | Upload | < 3s on Wi-Fi | P2 |

### 5.17 Accessibility

| ID | Scenario | Steps | Expected | Sev |
|----|----------|-------|----------|-----|
| A11Y-001 | VoiceOver / TalkBack — auth | Navigate login screen with screen reader | Every control labeled; logical focus order | P1 |
| A11Y-002 | Screen reader — active session | Log set with TalkBack | Set completion announced; reps/weight read back | P1 |
| A11Y-003 | Color contrast | Inspect with accessibility scanner | WCAG AA on body text and buttons | P2 |
| A11Y-004 | Tap target size | Inspect buttons | ≥ 44×44pt iOS / 48×48dp Android | P2 |
| A11Y-005 | Reduce motion | Enable system setting | No bouncy/spring animations; replace with fade | P3 |
| A11Y-006 | Bold text / dynamic type | Enable system setting | Layouts adapt, no truncation of primary CTAs | P1 |

### 5.18 Error Handling & Empty States

| ID | Scenario | Steps | Expected | Sev |
|----|----------|-------|----------|-----|
| ERR-001 | 500 from API | Trigger via debug menu / staging fault | User-friendly error, retry CTA; no raw stack | P1 |
| ERR-002 | 422 validation | Submit invalid form | Field-level errors mapped from `details[].field` | P1 |
| ERR-003 | 404 on stale entity | Open plan after it was deleted on another device | Friendly "not found", navigate back | P2 |
| ERR-004 | Timeout | Throttle network to 30s | Timeout surfaces clearly; retry available | P1 |
| ERR-005 | Empty list states | Every list when empty | Has a meaningful empty-state, never blank screen | P2 |
| ERR-006 | Snackbar / toast duration | Trigger error | Auto-dismiss 3-5s; dismissible | P3 |

### 5.19 Localization & Internationalization

| ID | Scenario | Steps | Expected | Sev |
|----|----------|-------|----------|-----|
| I18N-001 | Date display per locale | Switch device to UK locale | dd/mm/yyyy format respected | P2 |
| I18N-002 | Number format | Switch to DE locale | Comma as decimal separator in weight fields | P2 |
| I18N-003 | First day of week | US vs EU | Calendar starts Sun vs Mon as expected | P2 |
| I18N-004 | Long translations | Switch to German | Buttons / tabs do not clip | P2 |
| I18N-005 | Time format | 12h vs 24h | Respects system | P3 |

### 5.20 Installation, Update, Uninstall

| ID | Scenario | Steps | Expected | Sev |
|----|----------|-------|----------|-----|
| INST-001 | Fresh install | Install from TestFlight / Play Internal | App opens, requests only declared permissions | P1 |
| INST-002 | Upgrade install over previous version | Install build N+1 over N with data | Drift migration runs cleanly; no data loss | P0 |
| INST-003 | Uninstall + reinstall | Uninstall → reinstall | Reopens fresh; on login, full hydrate from server | P1 |
| INST-004 | Permissions denied | Deny notification permission | App still usable; non-blocking | P1 |
| INST-005 | Force-stop from system settings | Kill via OS | Next launch clean | P2 |

---

## 6. Regression Smoke Suite (15-minute pass)

Run after any backend deploy or app build:

1. AUTH-007 (login)
2. EX-001 (open library)
3. PLAN-002 (create plan)
4. SESS-001 + SESS-002 + SESS-011 (full session)
5. HIST-003 (session detail)
6. PROG-001 (progress dashboard)
7. STR-002 (streak increment)
8. SYNC-002 + SYNC-003 (offline log + reconnect)
9. PROF-007 (sign out)

If any smoke fails, **halt full pass and triage**.

---

## 7. Exit Criteria

The MVP is QA-signed-off when:

- All **P0** scenarios pass on every device in the matrix
- ≥ 95% of **P1** scenarios pass; remaining P1s have a known workaround and approved deferral
- ≥ 80% of **P2** scenarios pass
- No open P0/P1 defects in offline-sync or security suites
- Performance targets met on mid-range device
- Accessibility scan returns no critical violations

---

## 8. Defect Reporting Template

```
Title:        [Area] [Concise one-liner]
ID:           QA-MVP-####
Severity:     P0 | P1 | P2 | P3
Environment:  Device + OS + Build + Network
Pre-cond:     Account state, route, data setup
Steps:        1. ...
              2. ...
              3. ...
Expected:     ...
Actual:       ...
Evidence:     Screenshots / screen recording / device logs / API trace
Reproducible: Always | Intermittent (X/N) | Once
Notes:        Related to issue #__, similar to QA-MVP-####
```

---

## 9. Out of Scope (defer to Phase 2/3)

- Progress photos & body measurements (issues #33–#39)
- Push notifications & FCM (issues #43–#44)
- Apple Health / Google Fit (issues #45–#47)
- Supersets / circuits (issue #48)
- Social, gamification, payments, web — Phase 3

---

**End of plan.**
