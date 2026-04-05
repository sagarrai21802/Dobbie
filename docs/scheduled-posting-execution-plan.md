# Scheduled Posting Feature — Phase-by-Phase Execution Plan
## For AI Coding Agent

---

## CONTEXT (Read Before Every Phase)

**What we are building:**
A premium content scheduling feature inside a social media management PWA. Users subscribe to a plan (dummy payment for now), then unlock the ability to auto-schedule posts across platforms (LinkedIn, Pinterest, YouTube) for an entire week or month. The app researches trending topics, assigns best-time slots, generates a content calendar, and either auto-posts or notifies the user the night before for approval.

**Current stack:**
- Frontend: Next.js App Router, TypeScript, Tailwind CSS, mobile-first PWA (max-width 430px)
- Backend: FastAPI + MongoDB + JWT auth + LinkedIn OAuth + Google Sign-In
- Zero backend API signature changes are allowed — only new routes may be added
- Existing feature: one-time LinkedIn post from the frontend

**Expected end behaviour:**
1. Homepage has quick-post buttons (LinkedIn, Pinterest, YouTube) + a subscription upgrade card
2. If not subscribed → clicking "Schedule Posts" shows a paywall
3. Subscribe (dummy payment) → feature unlocked
4. User picks platform, duration (week/month), sees 5-7 trending topics, selects or types custom topics
5. System assigns best posting times, saves a content calendar to DB
6. Nightly cron job: night before each posting day, sends push notification with content preview
7. User taps Yes → post is published automatically on the scheduled time
8. User taps No / ignores → that day is skipped; notification repeats for next day
9. Optional: user can enable full auto-post mode (no notification needed)

---

## PHASE 1 — Homepage Redesign (PhonePe-style UI)

### Goal
Replace the current homepage with a PhonePe-inspired grid of quick-action buttons (one per platform) and a subscription upgrade card below. Free users can use one-time posting. Premium users see additional "Schedule" section.

### Agent Prompt — Phase 1

```
You are working on a Next.js App Router PWA (max-width 430px, TypeScript, Tailwind CSS).
The current homepage is at src/app/page.tsx (or src/app/(home)/page.tsx — check the actual path first).

TASK: Redesign the homepage to match a PhonePe-style quick-action grid layout.

EXPECTED BEHAVIOUR:
The homepage has two visual sections:
1. Quick-action grid: large icon-buttons, one per social platform the user can post to right now (one-time post). Platforms: LinkedIn, Pinterest, YouTube, Twitter/X. Each button shows the platform logo (use a simple SVG or emoji placeholder for now), the platform name, and a subtitle like "Post now". Clicking routes to the existing one-time post flow for that platform.
2. Subscription card: below the grid. A visually distinct card with a "Pro" or crown icon, a short pitch line ("Schedule posts on autopilot"), and an "Upgrade" CTA button. Clicking this routes to /subscribe.

DESIGN RULES:
- Mobile-first, max-width 430px container, centered
- Primary colour is already defined in the project — use it for CTA buttons
- Platform buttons should be in a 2×2 grid, each button ~160px tall, rounded corners, subtle border
- Subscription card has a gradient or premium-feel background (use existing Tailwind classes)
- All existing navigation and auth logic must remain untouched

WHAT TO CHECK FIRST:
- Read src/app/page.tsx to understand the current structure
- Check if there is a components/ folder and existing Button, Card components to reuse
- Check tailwind.config.ts for existing colour tokens

DO NOT:
- Break existing auth redirect logic
- Remove any existing API calls on the page
- Change any route paths other than adding /subscribe

OUTPUT: Updated page.tsx only. If you need a new sub-component, create it in src/components/home/.
```

---

## PHASE 2 — Dummy Payment Flow + Subscription Gate

### Goal
Create a /subscribe page with a pricing UI and a dummy checkout. On "pay", mark the user as subscribed in the DB. All premium routes check subscription status. No real payment gateway needed yet.

### Agent Prompt — Phase 2A: Backend — Subscription Model

```
You are working on a FastAPI backend with MongoDB and JWT auth.
Zero changes to existing API signatures are allowed. Only add new routes.

TASK: Add subscription support to the user model and create subscription endpoints.

SCHEMA CHANGE — users collection:
Add these fields to the existing user document (do NOT remove any existing fields):
  - subscription_status: str  → "free" | "pro"   (default: "free")
  - subscription_started_at: datetime | None       (default: None)
  - subscription_expires_at: datetime | None       (default: None)

NEW ENDPOINTS to add (prefix: /api/subscription):

POST /api/subscription/activate
  - Auth required (JWT)
  - Body: { "plan": "pro_monthly" }  (ignore plan for now, just activate)
  - Action: Set subscription_status="pro", subscription_started_at=now(), subscription_expires_at=now()+30days
  - Response: { "status": "activated", "expires_at": "<iso_date>" }

GET /api/subscription/status
  - Auth required (JWT)
  - Response: { "subscription_status": "free"|"pro", "expires_at": "<iso_date>|null" }

MIDDLEWARE: Create a dependency function check_subscription(current_user) that raises HTTP 403
with {"detail": "subscription_required"} if the user's subscription_status != "pro".
This dependency will be imported in future premium route files.

WHAT TO CHECK FIRST:
- Find where the User model/schema is defined and how MongoDB updates are done
- Find how JWT auth dependency is implemented — reuse the exact same pattern
- Do not change the login/signup/auth routes

OUTPUT: New file src/routers/subscription.py + updated user schema + the check_subscription dependency in src/dependencies.py (or wherever auth deps live).
```

### Agent Prompt — Phase 2B: Frontend — Subscribe Page + Gate

```
You are working on a Next.js App Router PWA (max-width 430px, TypeScript, Tailwind CSS).

TASK: Create a /subscribe page and add a subscription gate component.

1. PAGE: src/app/subscribe/page.tsx
   - Show a simple pricing card: "Pro Plan — ₹199/month" (or $9.99, match what makes sense)
   - List 3-4 benefits: Scheduled posts, Auto-posting, Content calendar, Trending topic research
   - A single "Subscribe Now" button
   - On button click: call POST /api/subscription/activate (with JWT from localStorage/cookie — use the same auth pattern as other API calls in the project)
   - Show a loading state while the API call is in progress
   - On success: show a success screen ("You're Pro! 🎉") and redirect to /dashboard (or homepage) after 2 seconds
   - On error: show an error toast/message

2. COMPONENT: src/components/SubscriptionGate.tsx
   - Props: { children: React.ReactNode }
   - On mount, call GET /api/subscription/status
   - If status === "pro": render children
   - If status === "free": render a locked UI — show a lock icon, the text "This is a Pro feature", and a button "Upgrade to Pro" that routes to /subscribe
   - Show a skeleton/loading state while fetching

WHAT TO CHECK FIRST:
- How are API calls made in the project (fetch, axios, custom hook)? Use the same pattern
- How is the JWT token stored and attached to requests? Use the exact same pattern
- Check if there's a toast/notification system already in use

DO NOT change any auth logic. Do NOT add a payment SDK — this is a dummy flow.

OUTPUT: subscribe/page.tsx + SubscriptionGate.tsx component.
```

---

## PHASE 3 — Database Schema for Scheduling

### Goal
Add MongoDB collections for storing scheduled calendars, topic assignments, and notification state.

### Agent Prompt — Phase 3

```
You are working on a FastAPI backend with MongoDB.

TASK: Define and document the MongoDB schema for the scheduling feature. Create Pydantic models and MongoDB index setup for these new collections.

COLLECTION 1: scheduled_calendars
Each document represents one scheduling session a user created.
Fields:
  - _id: ObjectId
  - user_id: str (references users._id)
  - platform: str  → "linkedin" | "pinterest" | "youtube" | "twitter"
  - created_at: datetime
  - duration_days: int  → 7 or 30
  - auto_post: bool  → False by default (requires approval); True = post without asking
  - status: str → "active" | "paused" | "completed"
  - posting_times: list[str]  → list of "HH:MM" strings (best times per day, stored as strings)

COLLECTION 2: calendar_entries
Each document is one day's post in a calendar.
Fields:
  - _id: ObjectId
  - calendar_id: str (references scheduled_calendars._id)
  - user_id: str
  - scheduled_date: date (YYYY-MM-DD)
  - scheduled_time: str ("HH:MM")
  - topic: str
  - platform: str
  - status: str → "pending" | "approved" | "denied" | "posted" | "failed"
  - notification_sent: bool (default False)
  - notified_at: datetime | None
  - posted_at: datetime | None
  - content_draft: str | None (will be filled later by content generation)
  - image_url: str | None (future — image gen)

COLLECTION 3: user_preferences (optional but recommended)
  - _id: ObjectId
  - user_id: str (unique)
  - preferred_topics: list[str]  → user's own topic list
  - preferred_platforms: list[str]
  - timezone: str  → default "Asia/Kolkata"
  - notification_token: str | None  → FCM push token

TASKS:
1. Create Pydantic models (Request + Response + DB models) for all three collections in src/models/scheduling.py
2. Add MongoDB index creation in the app startup (or a separate init script): index user_id on all collections, index scheduled_date on calendar_entries, unique index user_id on user_preferences
3. Create a short example showing how to insert and query a calendar_entry document

WHAT TO CHECK FIRST:
- How are other MongoDB models structured in this project (find an existing model file)
- What MongoDB driver is used (Motor async or PyMongo sync) — use the exact same driver

OUTPUT: src/models/scheduling.py + any index initialization additions.
```

---

## PHASE 4 — Trending Topics Research API

### Goal
Backend endpoint that searches trending topics relevant to a given platform and returns 5-7 suggestions. Uses web scraping or free APIs (no paid APIs required — Google Trends RSS, Twitter trends via scraping, or hardcoded platform-specific heuristics as fallback).

### Agent Prompt — Phase 4

```
You are working on a FastAPI backend.

TASK: Create a topics research endpoint that finds trending topics for a given social media platform.

NEW ENDPOINT:
GET /api/topics/trending?platform=linkedin&count=7
  - Auth required (JWT) + subscription required (use check_subscription dependency from Phase 2)
  - Query params: platform (str), count (int, default 7, max 10)
  - Returns: { "topics": [ { "title": str, "description": str, "source": str } ] }

IMPLEMENTATION APPROACH (in priority order):
1. Try Google Trends RSS (no auth needed): https://trends.google.com/trends/trendingsearches/daily/rss?geo=IN
   - Parse the RSS XML, extract <title> and <ht:approx_traffic> items
   - Filter/rank by relevance to the platform context
2. If Google Trends fails, try fetching trending hashtags from:
   - For LinkedIn: search Google for "trending LinkedIn topics this week" — scrape top 5 titles from results using requests + BeautifulSoup
   - For Twitter/X: use the Nitter public instance RSS if available, else fallback
3. Final fallback: return a curated static list of 10 high-engagement topics (e.g. "AI in the workplace", "Remote work culture", "Startup funding trends", "Mental health at work", "Sustainable business") — rotate them randomly so each call feels fresh

FILTERING by platform:
- linkedin: professional, career, B2B, industry news, leadership
- pinterest: lifestyle, home decor, fashion, DIY, recipes
- youtube: entertainment, tech reviews, how-to, gaming, vlogging
- twitter: current events, memes, politics, pop culture, sports

RESPONSE FORMAT per topic:
  { "title": "AI replacing jobs debate", "description": "Hot discussion around automation and workforce", "source": "google_trends" | "scraped" | "curated" }

WHAT TO CHECK FIRST:
- Check if requests and beautifulsoup4 are already in requirements.txt — if not, add them
- Check if there's an httpx or aiohttp available for async requests — prefer async
- Make the entire function async with a 5-second timeout so it never blocks

CACHING: Cache the response in-memory (use a simple dict with timestamp) for 1 hour per platform so we don't hit external sources on every call.

OUTPUT: src/routers/topics.py. Register it in main.py.
```

---

## PHASE 5 — Schedule Post Frontend Flow

### Goal
Build the full scheduling UI: platform selector → duration picker → topic display → user selects/types → auto-post toggle → confirm → call backend to save calendar.

### Agent Prompt — Phase 5

```
You are working on a Next.js App Router PWA (max-width 430px, TypeScript, Tailwind CSS).

TASK: Build the full multi-step schedule post flow. Wrap the entire page with SubscriptionGate from Phase 2.

PAGE: src/app/schedule/page.tsx
This is a multi-step form (use local state to track step, no URL param changes needed):

STEP 1 — Platform selector
  - Show 4 platform cards in a 2×2 grid: LinkedIn, Pinterest, YouTube, Twitter
  - Each card has an icon placeholder + name
  - User taps one → highlight it, move to Step 2

STEP 2 — Duration selector
  - Show two options: "This Week (7 days)" and "This Month (30 days)"
  - Tap to select, then show a "Find Trending Topics" button at the bottom

STEP 3 — Topic selection (loading then results)
  - On entering this step, call GET /api/topics/trending?platform={selected}&count=7
  - Show a loading skeleton while fetching
  - Display returned topics as selectable chips/cards
  - User can select up to 5 topics from the list
  - Below the list: a text input "Add your own topic" with an "Add" button — adds the custom topic to a "Your topics" list
  - A counter shows how many topics are selected
  - "Build My Calendar" CTA button (disabled until at least 1 topic selected)

STEP 4 — Auto-post toggle + confirm
  - Large toggle: "Auto-post without asking me" (default OFF)
  - When OFF: explain "We'll send you a notification the night before each post for approval"
  - When ON: explain "Posts will go live automatically at the best time. You can pause anytime."
  - Show a summary card:
      Platform: LinkedIn
      Duration: 7 days
      Topics: [chip list]
      Mode: Auto-post / Approval
  - "Confirm & Schedule" button

ON CONFIRM:
  - Call POST /api/schedule/create with body:
    { platform, duration_days, topics: string[], auto_post: boolean }
  - Show a success screen: "Your content calendar is set! We'll handle the rest."
  - Navigate to /schedule/calendar (Phase 6 — can be a stub page for now)

BACK NAVIGATION: Each step has a back arrow to go to the previous step. Step 1 back goes to homepage.

WHAT TO CHECK FIRST:
- Find how multi-step forms or wizard UIs are done in this project (or implement fresh if none)
- Find how API calls with auth are made — reuse the exact same pattern
- Check if there's a Toast/Snackbar component for error handling

OUTPUT: src/app/schedule/page.tsx + any new sub-components in src/components/schedule/.
```

---

## PHASE 6 — Calendar Generation Backend

### Goal
Backend endpoint that receives the schedule config, assigns best posting times for each day, creates calendar_entries in MongoDB, and returns the content calendar to the frontend.

### Agent Prompt — Phase 6

```
You are working on a FastAPI backend with MongoDB.

TASK: Create the schedule creation endpoint and the best-time assignment logic.

BEST POSTING TIMES (hardcoded research data — do NOT use external API for now):
LinkedIn:  ["08:00", "12:00", "17:00", "18:00"]  # Tue-Thu best, Mon-Fri acceptable
Pinterest: ["20:00", "21:00", "14:00", "15:00"]  # Evenings + weekend afternoons
YouTube:   ["15:00", "16:00", "20:00"]            # Afternoons and evenings
Twitter:   ["09:00", "12:00", "15:00", "18:00"]   # Spread through day

Store these in a config dict at the top of the file so they are easy to update later.

NEW ENDPOINT:
POST /api/schedule/create
  - Auth required + subscription required
  - Body: { "platform": str, "duration_days": int, "topics": list[str], "auto_post": bool }
  - Action:
      1. Create a scheduled_calendars document in MongoDB
      2. For each day from tomorrow up to duration_days:
           - Pick a posting time from the platform's best_times list (rotate through them)
           - Assign one topic from the topics list (cycle through topics if days > topics count)
           - Create a calendar_entry document with status="pending"
      3. Return the full calendar to the frontend
  - Response:
      {
        "calendar_id": str,
        "entries": [
          {
            "id": str,
            "date": "YYYY-MM-DD",
            "time": "HH:MM",
            "topic": str,
            "platform": str,
            "status": "pending"
          }
        ]
      }

GET /api/schedule/calendar
  - Auth required + subscription required
  - Returns all calendar_entries for the current user, ordered by scheduled_date ASC
  - Group by calendar_id in response

GET /api/schedule/calendar/{entry_id}/approve
  - Auth required
  - Sets calendar_entry status to "approved"
  - Returns { "status": "approved" }

GET /api/schedule/calendar/{entry_id}/deny
  - Auth required
  - Sets calendar_entry status to "denied"
  - Returns { "status": "denied" }

WHAT TO CHECK FIRST:
- Find how other routers insert documents into MongoDB — use the exact same pattern
- Find the Pydantic models created in Phase 3 and import them

OUTPUT: src/routers/schedule.py. Register in main.py.
```

---

## PHASE 7 — Content Calendar Frontend View

### Goal
A calendar view page showing the user's scheduled posts for the week/month. Each entry shows date, time, platform, topic, and approval status. User can approve/deny from here too.

### Agent Prompt — Phase 7

```
You are working on a Next.js App Router PWA (max-width 430px, TypeScript, Tailwind CSS).

TASK: Build the content calendar view page.

PAGE: src/app/schedule/calendar/page.tsx
  - Wrap with SubscriptionGate
  - On mount, fetch GET /api/schedule/calendar
  - Show a loading skeleton while fetching

DISPLAY:
  - Group entries by week. Each week is a collapsible section.
  - Each entry card shows:
      [Platform icon] Monday, 14 Apr · 08:00
      Topic: "AI replacing jobs debate"
      Status badge: Pending / Approved / Denied / Posted
      If status is "pending": show two buttons — ✓ Approve and ✗ Deny
  - Status badges use colour coding:
      pending → amber/yellow
      approved → blue
      denied → red/muted
      posted → green

ON APPROVE CLICK:
  - Call GET /api/schedule/calendar/{entry_id}/approve
  - Update the entry's status in local state to "approved" (optimistic update)

ON DENY CLICK:
  - Call GET /api/schedule/calendar/{entry_id}/deny
  - Update the entry's status in local state to "denied"

EMPTY STATE: If no calendar entries exist, show a friendly illustration placeholder and a "Set up your schedule" button routing to /schedule.

HEADER: Show a summary strip at the top:
  "7 posts scheduled · 2 approved · 1 denied"

WHAT TO CHECK FIRST:
- Check how list/card components are already used in the project
- Check if there's a date formatting utility (date-fns, dayjs) — use it if available, else use native Intl.DateTimeFormat

OUTPUT: src/app/schedule/calendar/page.tsx + any sub-components in src/components/calendar/.
```

---

## PHASE 8 — Push Notification + Nightly Approval Flow

### Goal
Backend cron job that runs every night, finds all pending calendar entries for the next day, and sends a push notification to the user with content preview. Handles FCM integration. Frontend handles notification tap → opens approve/deny screen.

### Agent Prompt — Phase 8A: Backend Cron + FCM

```
You are working on a FastAPI backend with MongoDB.

TASK: Implement the nightly notification scheduler and FCM push notification sending.

DEPENDENCIES to add to requirements.txt (if not present):
  - apscheduler
  - firebase-admin

SETUP:
1. Initialize Firebase Admin SDK using a service account JSON (path from env var FIREBASE_CREDENTIALS_PATH or GOOGLE_APPLICATION_CREDENTIALS).
   Create src/services/notifications.py with a send_push_notification(token: str, title: str, body: str, data: dict) function.

2. Create a background scheduler in src/scheduler.py:
   - Use APScheduler AsyncIOScheduler
   - Register it to start on FastAPI startup and shutdown on app shutdown
   - Schedule one job: nightly_notification_job() — runs daily at 21:00 (9 PM) IST

3. nightly_notification_job() logic:
   a. Find tomorrow's date (in Asia/Kolkata timezone)
   b. Query calendar_entries where:
        scheduled_date == tomorrow
        status == "pending"
        notification_sent == False
   c. For each entry:
        - Get the user's FCM token from user_preferences.notification_token
        - Skip if token is None
        - Send push notification:
            Title: "Ready to post tomorrow?"
            Body: f"Topic: {entry.topic} on {entry.platform.capitalize()} at {entry.scheduled_time}"
            Data: { "entry_id": str(entry._id), "action": "schedule_approval" }
        - Set entry.notification_sent = True, entry.notified_at = now()

NEW ENDPOINT:
POST /api/notifications/register-token
  - Auth required
  - Body: { "token": str }
  - Upsert user_preferences document for the user, set notification_token = token
  - Response: { "registered": true }

WHAT TO CHECK FIRST:
- Find where FastAPI startup/shutdown events are handled (lifespan or @app.on_event)
- Find how environment variables are loaded (dotenv, os.environ) — use the same pattern
- Check if firebase-admin is already in requirements.txt

OUTPUT: src/services/notifications.py + src/scheduler.py + updated main.py lifespan + src/routers/notifications.py.
```

### Agent Prompt — Phase 8B: Frontend — FCM Token Registration + Notification Handler

```
You are working on a Next.js App Router PWA (max-width 430px, TypeScript, Tailwind CSS).

TASK: Register the user's FCM push token after login and handle notification taps.

1. FCM SETUP:
   - Add firebase to package.json if not present: npm install firebase
   - Create src/lib/firebase.ts that initialises the Firebase app using env vars:
       NEXT_PUBLIC_FIREBASE_API_KEY, NEXT_PUBLIC_FIREBASE_PROJECT_ID,
       NEXT_PUBLIC_FIREBASE_MESSAGING_SENDER_ID, NEXT_PUBLIC_FIREBASE_APP_ID,
       NEXT_PUBLIC_FIREBASE_VAPID_KEY
   - Create public/firebase-messaging-sw.js (service worker for background messages)
     This file should import and initialise Firebase messaging and handle onBackgroundMessage.
   - Add a function getFCMToken() in src/lib/firebase.ts that requests notification permission
     and returns the FCM registration token.

2. TOKEN REGISTRATION:
   - In the main layout (src/app/layout.tsx) or a client component that wraps the app:
     After the user is authenticated, call getFCMToken() and POST the token to
     /api/notifications/register-token. Only do this once per session (use sessionStorage flag).
   - Handle the case where the user denies notification permission gracefully — do not block the app.

3. FOREGROUND NOTIFICATION HANDLER:
   - Use Firebase onMessage to handle notifications when the app is open.
   - Show a custom in-app toast/banner with:
       "Ready to post tomorrow? [Topic] on [Platform]"
       Two buttons: "Approve" and "Skip"
   - Approve button: call /api/schedule/calendar/{entry_id}/approve (entry_id from notification data)
   - Skip button: call /api/schedule/calendar/{entry_id}/deny

4. BACKGROUND NOTIFICATION TAP:
   - When the user taps a background notification, it should open the app and navigate to
     /schedule/calendar so the user can see and act on the pending entry.
   - Use the notification's data.entry_id if needed to scroll/highlight that specific entry.

WHAT TO CHECK FIRST:
- Check if firebase is already in package.json
- Check if there's a next.config.js/ts with any service worker or PWA config (next-pwa, etc.)
- Respect any existing auth/session management — do not touch those files

OUTPUT: src/lib/firebase.ts + public/firebase-messaging-sw.js + updated layout with token registration.
```

---

## PHASE 9 — Auto-Posting Backend Job

### Goal
A second scheduled job that runs at each entry's scheduled_time, checks if auto_post is enabled or if the user has approved, and publishes the post to the relevant platform.

### Agent Prompt — Phase 9

```
You are working on a FastAPI backend with MongoDB.

TASK: Implement the auto-posting job that publishes content at the scheduled time.

ADD TO src/scheduler.py — a second job:

posting_job() — runs every 5 minutes (to check if any post is due):
  Logic:
  a. Get current datetime in Asia/Kolkata timezone
  b. Query calendar_entries where:
       scheduled_date == today
       scheduled_time between (now - 5 min) and (now + 5 min)  [5-minute window]
       status IN ["approved", "pending"]  — pending only if auto_post is True on the calendar
  c. For each entry:
       - Get the parent scheduled_calendar to check auto_post flag
       - If auto_post is True OR entry.status == "approved":
           * Call the appropriate platform post function (see below)
           * On success: set entry.status = "posted", entry.posted_at = now()
           * On failure: set entry.status = "failed", log the error
       - Else (pending, not auto_post): skip — waiting for user approval

PLATFORM POST FUNCTIONS (create src/services/platform_poster.py):

post_to_linkedin(user_id: str, content: str) → bool
  - Fetch the user's LinkedIn access token from the user document
  - Call the LinkedIn Share API v2 (or UGC Post API)
  - For now, if no access token exists: log a warning and return False
  - Return True on success

post_to_pinterest(user_id: str, content: str, image_url: str | None) → bool
  - Placeholder implementation: log "Would post to Pinterest: {content}" and return True
  - Pinterest API integration is deferred to a future phase

post_to_youtube(user_id: str, content: str) → bool
  - Placeholder: log + return True (YouTube requires video — placeholder only)

CONTENT GENERATION (minimal for now — full AI generation is a future phase):
  Since image and content generation are deferred, use this template for the post content:
  f"🔥 Trending today: {entry.topic}\n\n[Auto-posted by your scheduler]\n\n#trending #{entry.platform}"

IMPORTANT: The 5-minute window check must be idempotent — a post that was already set to "posted"
will not match the query (status filter excludes "posted"), so it cannot be double-posted.

WHAT TO CHECK FIRST:
- Find how the LinkedIn OAuth access token is stored for the user (existing auth flow)
- Find if there's an existing LinkedIn API call anywhere in the codebase — reuse that HTTP client setup

OUTPUT: src/services/platform_poster.py + updated src/scheduler.py with the posting_job.
```

---

## EXECUTION ORDER SUMMARY

| Phase | What | Status | Notes |
|-------|------|--------|-------|
| Phase 1 | Homepage redesign | ✅ Done | 2×2 platform grid + Pro card |
| Phase 2A | Backend subscription model + endpoints | ✅ Done | User model + /subscription routes |
| Phase 2B | Frontend subscribe page + gate component | ✅ Done | /subscribe page + SubscriptionGate |
| Phase 3 | MongoDB schema + Pydantic models | ✅ Done | scheduling.py + indexes |
| Phase 4 | Trending topics research API | ✅ Done | /topics/trending endpoint |
| Phase 5 | Schedule post multi-step frontend | ✅ Done | 4-step wizard + SubscriptionGate |
| Phase 6 | Calendar generation backend | ✅ Done | /schedule/create, /calendar endpoints |
| Phase 7 | Calendar view frontend | ✅ Done | /schedule/calendar page |
| Phase 8A | Backend cron + FCM notification sender | ✅ Done | scheduler.py + notifications.py |
| Phase 8B | Frontend FCM token + notification handler | Pending | - |
| Phase 9 | Auto-posting job | ✅ Done | platform_poster.py (integrated in scheduler) |

**Last updated:** April 5, 2026
**Current phase:** Phase 7 complete - Ready for Phase 8

---

## COMPLETED PHASES DETAIL

### Phase 1 - Homepage Redesign ✅
- Updated `website/src/app/page.tsx`
- 2×2 platform grid (LinkedIn, Pinterest, YouTube, X/Twitter)
- Pro upgrade card linking to /subscribe
- "Schedule Posts" button for Pro users
- "Coming soon" badges for unreleased platforms

### Phase 2A - Backend Subscription ✅
- Updated `app/models/user.py` - added subscription field
- Created `app/routers/subscription.py`:
  - POST /api/v1/subscription/activate
  - GET /api/v1/subscription/status
- Added `check_subscription` dependency in `app/utils/dependencies.py`
- Registered router in `app/main.py`

### Phase 2B - Frontend Subscribe ✅
- Created `website/src/lib/subscription.ts` - subscription service
- Updated `website/src/lib/api-config.ts` - added subscription endpoints
- Created `website/src/components/SubscriptionGate.tsx`
- Created `website/src/app/subscribe/page.tsx`

### Phase 3 - Database Schema ✅
- Created `app/models/scheduling.py` with Pydantic models
- Added MongoDB indexes in `app/main.py`:
  - scheduled_calendars (user_id, status)
  - calendar_entries (user_id, calendar_id, scheduled_date, compound)
  - user_preferences (unique user_id)

### Phase 4 - Trending Topics API ✅
- Created `app/routers/topics.py`:
  - GET /api/v1/topics/trending?platform=...&count=...
- Uses check_subscription dependency
- In-memory caching (1 hour TTL)
- Google Trends RSS + curated fallback
- Added beautifulsoup4 to requirements.txt

### Phase 5 - Schedule Post Frontend ✅
- Created `website/src/app/schedule/page.tsx`
- 4-step wizard:
  - Step 1: Platform selector (2×2 grid)
  - Step 2: Duration selector (7 or 30 days)
  - Step 3: Topic selection (fetch trending + custom topics)
  - Step 4: Auto-post toggle + confirm
- Wrapped with SubscriptionGate
- Created `website/src/lib/schedule.ts` - schedule service

### Phase 6 - Calendar Generation Backend ✅
- Created `app/routers/schedule.py`:
  - POST /api/v1/schedule/create - Create schedule with entries
  - GET /api/v1/schedule/calendar - Get all user entries
  - GET /api/v1/schedule/calendar/{entry_id}/approve - Approve entry
  - GET /api/v1/schedule/calendar/{entry_id}/deny - Deny entry
- Best posting times configuration from scheduling.py
- Registered router in main.py

### Phase 7 - Calendar View Frontend ✅
- Created `website/src/app/schedule/calendar/page.tsx`
- Shows all scheduled posts with status badges
- Approve/Deny buttons for pending entries
- Stats bar showing counts
- Empty state with "Set up your schedule" CTA

### Phase 8A - Backend Cron + FCM Notification ✅
- Created `app/services/notifications.py`:
  - Firebase Admin SDK initialization
  - send_push_notification() function
- Created `app/services/platform_poster.py`:
  - post_to_linkedin(), post_to_pinterest(), post_to_youtube(), post_to_twitter()
  - Placeholder implementations (actual API calls deferred)
- Created `app/scheduler.py`:
  - AsyncIOScheduler with APScheduler
  - nightly_notification_job() - runs daily at 21:00 IST
  - posting_job() - runs every 5 minutes
- Created `app/routers/notifications.py`:
  - POST /api/v1/notifications/register-token
- Added Firebase config to `app/config.py`
- Added APScheduler and firebase-admin to requirements.txt
- Updated `app/main.py` to start/stop scheduler on app lifecycle

### Phase 9 - Auto-Posting Job ✅
- Integrated into scheduler.py
- posting_job checks for due entries every 5 minutes
- Posts if auto_post is enabled OR entry is approved
- Updates entry status to "posted" or "failed"

---

## WHAT IS DEFERRED (Future phases, not now)

- AI-generated post copy (Claude/Gemini API)
- AI-generated images (Freepik or DALL-E)
- Real payment gateway (Stripe/Razorpay)
- Pinterest, YouTube full API integration
- Multi-account support
- Analytics dashboard for scheduled posts
- Content calendar edit (reschedule/change topic)
