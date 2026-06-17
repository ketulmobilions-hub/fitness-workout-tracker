# Powerlifting Launch Sprint

Issues #63–#86. Goal: ship a powerlifting-focused version of the app with dedicated tooling for
programming, competition, analytics, and branding. Four sub-phases in order.

---

## Status

| # | Title | Phase | Type | Status |
|---|-------|-------|------|--------|
| 63 | Seed powerlifting exercise database | Programming | fullstack | ✅ Done |
| 64 | 1RM calculator — backend utility and Flutter widget | Programming | fullstack | ✅ Done |
| 65 | RPE-first set logging UX redesign | Programming | frontend | ✅ Done |
| 66 | Tempo notation input in set logging | Programming | frontend | ✅ Done |
| 67 | Enhanced previous performance card with RPE history | Programming | frontend | ✅ Done |
| 68 | % of 1RM auto-suggest for plan creation | Programming | fullstack | ✅ Done |
| 69 | RPE-to-weight suggestion engine | Programming | fullstack | ✅ Done |
| 70 | Built-in powerlifting program templates | Programming | fullstack | ✅ Done |
| 71 | Multi-week program calendar view | pl-programming | frontend | ✅ Done |
| 72 | Deload week tagging and display | pl-programming | fullstack | ✅ Done |
| 73 | Athlete competition profile (weight class, federation, division) | pl-competition | fullstack | 🔲 Todo |
| 74 | Wilks/Dots/IPF GL score calculation and display | pl-competition | fullstack | 🔲 Todo |
| 75 | Meet day mode — attempt tracking for competition | pl-competition | fullstack | 🔲 Todo |
| 76 | Attempt selection calculator for competition | pl-competition | frontend | 🔲 Todo |
| 77 | Competition history screen and meet results archive | pl-competition | frontend | 🔲 Todo |
| 78 | SBD total tracking and trend chart | pl-analytics | fullstack | 🔲 Todo |
| 79 | Wilks/Dots trend chart on progress screen | pl-analytics | frontend | 🔲 Todo |
| 80 | Strength balance ratios visualization | pl-analytics | frontend | 🔲 Todo |
| 81 | Weekly volume load analysis by intensity zone | pl-analytics | fullstack | 🔲 Todo |
| 82 | Training max tracking per exercise | pl-analytics | fullstack | 🔲 Todo |
| 83 | App rebrand for powerlifting identity | pl-launch | frontend | 🔲 Todo |
| 84 | Powerlifting-focused onboarding flow | pl-launch | frontend | 🔲 Todo |
| 85 | Shareable PR cards for social media | pl-launch | frontend | 🔲 Todo |
| 86 | App Store optimization for powerlifting niche | pl-launch | frontend | 🔲 Todo |

---

## Sub-phases

### Phase PL-1 — Programming Foundations (✅ Complete — #63–#70)

Built the powerlifting-specific exercise and programming layer:

- **Exercise database**: full powerlifting exercise library seeded (squat, bench, deadlift, OHP,
  pause variants, accessories)
- **1RM calculator**: Epley/Brzycki formula, server utility + Flutter widget
- **RPE logging UX**: RPE-first set entry, half-point increments (6–10), tempo notation
- **Previous performance card**: RPE history display per exercise
- **% of 1RM auto-suggest**: plan-day exercises with `target_weight_pct_1rm` → suggested weight
  at session start using user's PR
- **RPE-to-weight suggestion**: lazy-loaded per-exercise suggestion based on RPE history,
  with linear interpolation/extrapolation
- **Built-in templates**: 5/3/1 BBB (12 wk), GZCLP (8 wk), The Bridge 1.0 (8 wk) — import
  with 1RM inputs, creates fully-editable plan, upserts PRs

---

### Phase PL-2 — Programming UX (#71–#72)

Make multi-week programs navigable and deload weeks visible.

**#71 — Multi-week program calendar view**
Visual calendar/grid showing all weeks and days of a recurring plan. User can see the full
12-week structure at a glance, tap a week/day to view or log it. Replaces the flat day list
on plan detail screen.

**#72 — Deload week tagging and display**
Tag specific plan weeks as deload weeks (flag on `plan_days` or inferred from template metadata).
Display deload badge on calendar view and session start screen. Warn user if they skip a deload.

---

### Phase PL-3 — Competition (#73–#77)

Full meet-day and competition tracking feature set.

**#73 — Athlete competition profile**
User sets their weight class, federation (USAPL, IPF, RPS, etc.), division (raw/equipped,
open/junior/master), and competition lifts (SBD or just bench). Stored on `users` profile.
Used by Wilks/Dots calculation and meet day mode.

**#74 — Wilks/Dots/IPF GL score calculation and display**
Server utility functions for Wilks 2.0, Dots, and IPF GL coefficients. Display score on
session summary and progress screen when the session contains SBD lifts. Auto-computed from
best SBD total in the session.

**#75 — Meet day mode — attempt tracking for competition**
Special workout session mode for competition day. User selects opener, second, third attempt
for each lift. App tracks make/miss per attempt, updates total after each lift, shows running
SBD total. Stores results in a `competition_results` table.

**#76 — Attempt selection calculator**
Given a target total and current PRs, suggest openers (90% PR) and second/third attempts for
each lift to hit the total. Flutter-side calculator widget, no server round-trip needed.

**#77 — Competition history screen and meet results archive**
Screen listing all past competitions with date, federation, weight class, total, and Wilks/Dots.
Tapping a meet shows the full attempt-by-attempt breakdown.

---

### Phase PL-4 — Analytics (#78–#82)

Powerlifting-specific progress dashboards.

**#78 — SBD total tracking and trend chart**
Track best squat + bench + deadlift PR per date → plot SBD total over time. Server endpoint
aggregating PRs by date. Line chart on progress screen.

**#79 — Wilks/Dots trend chart**
Same as #78 but normalised by bodyweight using Wilks 2.0 / Dots. Requires bodyweight log
(tracked in user profile or a separate `bodyweight_logs` table).

**#80 — Strength balance ratios visualization**
Compute and display squat:bench:deadlift ratios vs. powerlifting norms (e.g. S:B:D = 1.5:1:1.75).
Bar or radar chart. Flutter-side calculation from existing PRs.

**#81 — Weekly volume load analysis by intensity zone**
Break weekly training volume into intensity zones (< 70% 1RM / 70–80% / 80–90% / 90%+).
Chart showing distribution per week. Server aggregation over `set_logs` with `weight_kg` and
user PRs. Helps athletes see if they're accumulating enough volume in the right zones.

**#82 — Training max tracking per exercise**
Store and display training max (TM = 90% × 1RM) separately from true 1RM. Users running 5/3/1
manually adjust TM each wave. UI to set/update TM per lift, shown alongside 1RM on the PR
card and session start weight suggestion.

---

### Phase PL-5 — Branding & Launch (#83–#86)

Polish and App Store presence for the powerlifting niche.

**#83 — App rebrand for powerlifting identity**
New app name, icon, color palette, and typography targeting powerlifters. Update splash screen,
app shell, and marketing assets.

**#84 — Powerlifting-focused onboarding flow**
Onboarding that asks: primary lifts (SBD / bench-only), experience level, competition goals,
current maxes. Pre-populates PRs and suggests a starting template. Replaces generic onboarding.

**#85 — Shareable PR cards for social media**
Generate a styled image card when user sets a new PR (e.g. "New Squat PR — 180 kg 🔥").
Share sheet integration. Server-side image generation (Sharp + canvas) or Flutter-side
screenshot + share_plus.

**#86 — App Store optimization for powerlifting niche**
Screenshots, preview video, keyword strategy, and app description targeting powerlifting
search terms. Separate from dev work — copy and asset deliverables.

---

## Suggested Order

PL-2 → PL-3 → PL-4 → PL-5

PL-2 (#71–#72) builds on the templates just shipped — do these first while the plan model is
fresh. PL-3 (#73–#77) is self-contained but #74 (Wilks) is needed by #79 and #78, so complete
all of PL-3 before PL-4. PL-4 (#78–#82) depends on PRs and session data already in place.
PL-5 (#83–#86) is non-blocking — #83 and #84 can run in parallel with PL-4, #85 and #86 are
last.
