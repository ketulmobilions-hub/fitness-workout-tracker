# API Foundation — Code Review: Issues & Fixes

This document records the 7 security and correctness issues found during the post-feature code review of issue #7 (API foundation layer). Each issue explains what the problem is, why it exists, how it manifests in production, and what was done to fix it.

---

## Issue 1 — Wildcard CORS in production (Critical / Security)

**File:** `server/src/app.ts`

### What it is

The `CORS_ORIGIN` environment variable is marked optional in `env.ts` with no default. When it is unset, `app.ts` falls back to `origin: '*'`, which tells the browser to allow cross-origin requests from any website on the internet.

```ts
// Before fix — blindly falls back to '*'
cors({ origin: env.CORS_ORIGIN ?? '*' })
```

### Why it's dangerous

CORS exists to prevent a random website from making authenticated requests to your API on behalf of a logged-in user. Allowing `*` disables this protection entirely. It doesn't matter whether the app uses cookies or JWTs — `*` opens two real attack vectors:

1. **CSRF via cookies (Phase 3 web dashboard):** When a web client eventually stores the session in a cookie, any site can trigger requests using that cookie. The browser enforces CORS on the *response*, not the *request* — with `*` it lets the attacker's script read the response too.
2. **Credential exposure via storage:** If a JWT leaks from `localStorage` (e.g., via an XSS in a partner site), the attacker can freely call every API endpoint because there is no origin restriction to stop them.

### How it fails in production

`CORS_ORIGIN` is optional with no validation that it is set in production. A deploy engineer sets up the Render environment, forgets to add `CORS_ORIGIN`, and the server starts without error. The API is now accessible cross-origin from any website. There is no log line, no startup warning, nothing to indicate the misconfiguration.

### Fix

`env.ts` now uses `superRefine` to fail the Zod parse at startup if `NODE_ENV` is `production` and `CORS_ORIGIN` is not set. The server refuses to boot rather than silently running in an insecure configuration.

---

## Issue 2 — Rate limiter ignores real client IP behind a proxy (High / Security + Correctness)

**File:** `server/src/app.ts`, `server/src/middleware/rate-limiter.ts`

### What it is

`express-rate-limit` identifies clients by `req.ip`. When the API is deployed behind Render's load balancer or an AWS ALB, the actual TCP connection comes from the proxy — so `req.ip` is the internal proxy IP, not the user's real IP. Express only uses `X-Forwarded-For` to reconstruct the real IP if `app.set('trust proxy', N)` is configured. Without it, every single user shares the same "IP" (the load balancer).

### Why it's dangerous

Rate limiting is the primary defence against brute-force attacks on the auth endpoints. With a shared bucket:

- **Scenario A (bucket too small):** One attacker sends 15 login attempts. The bucket fills to 15. Every other user in a different country now gets 429 on their legitimate login because they share the same counter.
- **Scenario B (bucket large enough to not trip on normal traffic):** The attacker's 20 attempts spread across a 200-req bucket and the `authLimiter` never fires for them individually. Brute-forcing is unconstrained.

### How it fails in production

This is invisible in local development (no proxy), so it passes all local testing. The bug only surfaces after the first production deploy to Render. At that point, either the rate limiter falsely blocks legitimate users en masse or it does nothing useful for security.

### Fix

`app.set('trust proxy', 1)` is added to `app.ts` before `globalLimiter`. This tells Express to trust one hop of `X-Forwarded-For`, which is exactly the right value for Render (single proxy) and AWS ALB (also single hop to the app).

---

## Issue 3 — Internal error details leak to clients in production (High / Security)

**File:** `server/src/middleware/error-handler.ts`

### What it is

The message redaction logic in the error handler contained this condition:

```ts
// Before fix
status >= 500 && !(err instanceof AppError) && env.NODE_ENV === 'production'
```

The intent was "only redact generic Errors, not AppErrors". But this means any code that throws `new AppError(500, someInternalMessage)` sends `someInternalMessage` verbatim to the client in production.

### Why it's dangerous

`AppError` is a shared utility class that any future developer — or any library wrapping errors — can use. The class has no concept of "safe for clients vs internal only". Examples of messages that should never leave the server:

- A Prisma error message wrapped in `AppError` to add a status code: `"Unique constraint failed on column 'email' in table 'users'"` — reveals schema details.
- An AWS SDK error message: `"The security token included in the request is expired"` — reveals infrastructure provider.
- A database connection string fragment if error formatting is naive.

None of these are `AppError` instances at the wrapping point, but the pattern encourages it.

### How it fails in production

A developer catches a Prisma error and throws `new AppError(500, error.message)` to preserve the stack context. It works in dev (messages are visible, useful). In production the message passes through the `!(err instanceof AppError)` guard untouched and is serialised into the JSON response sent to every API client.

### Fix

The condition is simplified: **all 500-level errors have their messages redacted in production**, regardless of class. Only 4xx `AppError` messages are forwarded to clients (these are by definition user-facing validation/permission messages). In development, full messages are always visible.

```ts
// After fix
const isClientError = err instanceof AppError && status < 500;
const message = !isClientError && env.NODE_ENV === 'production'
  ? 'An unexpected error occurred'
  : err.message || 'An unexpected error occurred';
```

---

## Issue 4 — Unmatched routes return HTML instead of JSON (Medium / API Contract)

**File:** `server/src/app.ts`

### What it is

There was no catch-all route handler after `app.use('/api/v1', routes)`. When a request arrives for a path that doesn't exist — `GET /api/v1/workuot` (typo), `DELETE /api/v1/nonexistent`, or any other undefined endpoint — Express 5 falls through all middleware and sends its own built-in response:

```
Cannot GET /api/v1/workuot
```

This response is `text/plain` or `text/html` with HTTP 404, completely bypassing the error handler. The RFC 7807 JSON contract is broken.

### How it fails in production

The Flutter app uses Dio + Retrofit. Retrofit expects a JSON body on error responses and will attempt to decode it. Receiving a plain-text HTML "Cannot GET …" causes a `FormatException` in Dart. Instead of showing a graceful "not found" message, the app crashes or displays a raw unhandled error. This happens for every typo, deprecated endpoint, or version mismatch that a client sends.

### Fix

A catch-all middleware is added between the route mount and the error handler:

```ts
app.use((_req, _res, next) => next(new AppError(404, 'Route not found')));
```

This ensures all unmatched routes flow through the error handler and return a RFC 7807-compliant JSON 404.

---

## Issue 5 — `DATABASE_URL` validation rejects valid Render connection strings (Medium / Production Readiness)

**File:** `server/src/utils/env.ts`

### What it is

The environment validator required `DATABASE_URL` to start with `postgresql://`:

```ts
DATABASE_URL: z.string().startsWith('postgresql://')
```

The PostgreSQL URI specification allows both `postgresql://` and `postgres://` as valid schemes. They are identical in meaning. Prisma, `pg`, and every cloud platform (Render, Supabase, Railway, AWS RDS) generates and accepts both.

### How it fails in production

Render's "Internal Database URL" for a PostgreSQL instance uses the `postgres://` scheme. An engineer copies it directly into the Render environment dashboard. On the next deploy, the server crashes at startup with:

```
ZodError: DATABASE_URL: Invalid input
```

This looks like an infrastructure problem. The Render health check fails, the deploy is marked as failed, and the engineer wastes time diagnosing the wrong layer.

### Fix

The validator now accepts both schemes:

```ts
DATABASE_URL: z.string().refine(
  (v) => v.startsWith('postgresql://') || v.startsWith('postgres://'),
  { message: 'Must be a valid PostgreSQL connection string (postgresql:// or postgres://)' }
)
```

---

## Issue 6 — Zod-coerced query values are silently lost (High / Correctness)

**File:** `server/src/middleware/validate.ts`

### What it is

The original validation middleware assigned parsed Zod output back to `req.body`, `req.query`, and `req.params` using an unsafe cast:

```ts
(req as unknown as Record<string, unknown>)[section] = result.data;
```

In Express 5, `req.query` is defined as a **getter** on the request prototype — it is not a plain writable property. Attempting to assign to it via a cast silently fails in non-strict property environments (the assignment is a no-op). The Zod-coerced/defaulted values are discarded, and controllers receive the raw un-coerced strings from the original URL.

`req.params` has a similar issue: it is the same object reference that the router uses for routing. Replacing it breaks the internal reference.

### How it fails in production

A pagination endpoint uses `validate({ query: z.object({ limit: z.coerce.number().default(20) }) })`. The middleware validates successfully. But because the assignment to `req.query` silently fails, `req.query.limit` in the controller is still the string `"5"` (or `undefined` if omitted). Prisma receives `take: "5"` or `take: undefined` and either throws a type error, returns all records, or applies no limit — depending on how strictly Prisma checks the value at runtime. The user requests 5 results and gets 2,000.

### Fix

Validated data is no longer written back onto `req`. Instead it is stored on `res.locals.validated`:

```ts
res.locals.validated = { body: ..., query: ..., params: ... };
```

Controllers read from `res.locals.validated.query`, `res.locals.validated.body`, etc. This is the idiomatic Express pattern for passing middleware-computed data to handlers. TypeScript types for the `validated` namespace are added to `Express.Locals` via module augmentation in `src/types/index.ts`.

---

## Issue 7 — Rate limit counters reset on deploy and don't work across multiple instances (Medium / Security + Production Readiness)

**File:** `server/src/middleware/rate-limiter.ts`

### What it is

Both `globalLimiter` and `authLimiter` used the default in-memory store. Rate limit counters exist only in the Node.js process memory. They are lost whenever the server restarts or a new instance starts.

The project already has Redis configured and running. Not using it for the rate limiter store is an oversight.

### Why this matters immediately (not just at scale)

1. **Deploy resets:** Every code push triggers a deploy on Render. The server restarts. All counters reset to zero. An attacker who monitors the deploy webhook (public on many OSS repos) or simply retries every minute can always keep their attempt count below the limit by timing requests around restarts.

2. **Multiple instances:** When the app scales to two ECS tasks (Phase 1 → Phase 2 traffic), each instance has its own counter. `authLimiter` allows 20 attempts per window. With 3 instances, an attacker effectively gets 60 attempts before being blocked on *any single instance* — and they can round-robin between instances trivially.

### How it fails in production

A bot attempts to brute-force a user's password. It sends 19 attempts (just under the `authLimiter` limit), waits for the next deploy, then sends 19 more. The counter never reaches 20 from the server's perspective. The account is brute-forced without the rate limiter ever firing. This is not a theoretical attack — it is how credential-stuffing tools work.

### Fix

`rate-limit-redis` is installed and the existing `redis` client from `src/lib/redis.ts` is used as the store. Because Redis is optional in the current setup (no `REDIS_URL` = no Redis client), the rate limiter gracefully falls back to in-memory with a startup warning if Redis is unavailable. This ensures the app still starts in environments without Redis while making the Redis-backed store the default when it is present.
