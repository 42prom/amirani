### PHASE 0: Foundation & Hygiene (Start Here — Do This First)

These are the immediate files/folders that block everything else.

1. **backend/** (root level)
   - Delete or move ALL these files (debug pollution):
     analyze*failure.ts, check-trainers.ts, check_ai_config.ts, check_audit.js, check_audit_v2.js, check_db.ts, check_oauth_db_state.ts, check_queue.ts, check_recent.ts, check_user.ts, compile_errors*.txt, convert_logs.ts, count_db.ts, debug_oauth.ts, debug_stack.txt, diagnose_db.ts, drain_queue.ts, error_out.json, errors.txt, final_stack_debug.txt, inspect_diet*.ts, inspect_queue.ts, list_gyms.js, login.json, oauth*_.txt, prisma*error.txt, probe_db.js, recalculate_test.ts, repair_log.txt, restore_oauth.ts, roles_out.txt, roles_output.txt, scan_db.ts, scan_logs.js, scan_users.ts, simulate_sync.ts, socket_errors.txt, test*_.ts, test_login_roles.js, test_photo_fix.ts, ts_errors.txt, tsc_errors.txt, validate*.txt, verify*.ts, verify_fcm.ts, verify_linkage.ts, verify_sync.ts, etc. (≈100 files)
   - Action: Move them into the already-existing `backend/scripts/debug/` folder (or delete if you prefer).
   - Why: This is the #1 premium-quality blocker.

2. **backend/.gitignore**
   - Add rules for logs, temp files, debug folder, etc.

3. **docker-compose.yml** (root)
   - Currently minimal (only postgres + redis).
   - Must completely rewrite it to include backend, admin, gateway, healthchecks, networks, volumes, .env support.

4. **.env.example** (create new at root)
   - All environment variables (DATABASE_URL, REDIS_URL, JWT_SECRET, Stripe keys, etc.).

5. **BACKEND_TROUBLESHOOT.md** (root)
   - Delete or archive it after fixes — it should no longer be needed.

6. **README.md** (root)
   - Replace the generic Flutter starter text with full architecture overview, setup instructions, and roadmap status.

### PHASE 1: Stable MVP — Key Files to Create/Edit

7. **backend/src/** (entire folder)
   - `index.ts` → Add Redis rate limiting, Pino logging, global error middleware, /health endpoint.
   - Create new folders: `src/middleware/`, `src/utils/`, `src/jobs/` (for BullMQ).
   - `src/config/` → Rate limit config, JWT config.

8. **backend/prisma/**
   - `schema.prisma` → Add indexes on high-traffic fields + new models for Tasks, Points, Badges, ChallengeRooms, Gamification (when we reach Phase 2).
   - `migrations/` and `seed.ts` → Update for new schema.

9. **gateway/amirani_gateway.py** + **gateway/config.example.json**
   - Replace plain api_key with JWT + hardware registration + offline cache.

10. **mobile/lib/** (entire Flutter structure)
    - Completely restructure into clean architecture:
      - `mobile/lib/core/` (network, language, storage)
      - `mobile/lib/features/` (auth, gym, workout, diet, door_access, tasks, gamification, challenge_rooms, etc.)
      - `mobile/lib/shared/` (widgets, theme)
    - language.md spec must be implemented here first (dynamic i18n).

### PHASE 2–5: Flagship & New Features (Task/Points/Challenge Rooms)

11. **New files/folders to create** (AI will generate these):
    - `backend/src/modules/tasks/`
    - `backend/src/modules/gamification/` (points, badges, leaderboards)
    - `backend/src/modules/challenge-rooms/`
    - `mobile/lib/features/tasks/`, `mobile/lib/features/gamification/`, `mobile/lib/features/challenge-rooms/`

12. **Key existing files that will be heavily extended**:
    - `backend/src/modules/workout/`, `diet/`, `progress/` (these already have some stubs)
    - `backend/src/modules/membership/` and `payment/` (for rewards tied to points)
    - Prisma schema (add Task, UserTask, PointsTransaction, ChallengeRoom, RoomParticipant, etc.)

### Summary: Priority Order (What You Should Touch Right Now)

| Priority | File / Folder              | Action                         | Why It Matters          |
| -------- | -------------------------- | ------------------------------ | ----------------------- |
| 1        | backend/ root debug files  | Move to scripts/debug/         | Clean the repo          |
| 2        | docker-compose.yml         | Full rewrite                   | One-command run         |
| 3        | backend/src/index.ts       | Add logging + Redis rate limit | Fix 500s & 429s         |
| 4        | .env.example + README.md   | Create                         | Professional setup      |
| 5        | mobile/lib/ structure      | Full clean architecture        | Real mobile app         |
| 6        | gateway/amirani_gateway.py | JWT + offline                  | Secure door system      |
| 7        | prisma/schema.prisma       | Add indexes + new models       | Future-proof data layer |
