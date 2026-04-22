# Backend Troubleshooting Guide

## Common Problems & Fixes

---

### 1. Login returns `{"error":"Internal server error"}` (HTTP 500)

**Cause:** The backend is running from stale compiled `dist/` files (not the latest source changes).

**Fix:**
```bash
cd backend

# Kill whatever is on port 3085
npx kill-port 3085

# Rebuild from source and restart
npm run build && npm start
# OR for dev with auto-reload:
npm run dev
```

**Why it happens:** `npm start` runs `node dist/index.js`. If you changed `src/` files but didn't run `npm run build`, the compiled output is out of date and crashes on startup (bad imports, wrong field names, etc.), which causes every request to return 500.

---

### 2. Login returns `{"error":"Too many auth attempts..."}` (HTTP 429)

**Cause:** `express-rate-limit` in-memory store — 20 auth attempts per IP per 15 minutes.

**Fix options (pick one):**
```bash
# Option A: Restart the backend process (resets in-memory store)
npx kill-port 3085 && npm run dev

# Option B: Wait 15 minutes for the window to expire

# Option C: During dev, increase the limit temporarily in src/index.ts:
#   max: 200  (instead of 20)
```

**Note:** Redis `FLUSHALL` does NOT fix this — express-rate-limit uses in-memory store, not Redis. Redis is only used for AI rate limiting.

---

### 3. Backend crashes on startup — TypeScript compilation errors

**Symptom:** `npm run dev` keeps restarting, or `npm run build` fails.

**Fix:**
```bash
cd backend
npm run build 2>&1 | grep "error TS"
```

Common errors we've hit before:
- `exerciseType does not exist` → use `primaryMuscle` + `secondaryMuscles`
- `profile.gym does not exist` → use `profile.gymId` (no `.gym` relation in resolveProfile)
- `EPERM: unlink query_engine-windows.dll.node` → can't run `npx prisma generate` while server is running; stop server first

---

### 4. Prisma field type errors (`(prisma.X as any)` workaround needed)

**Cause:** Schema was migrated but `npx prisma generate` couldn't run (DLL locked by running server).

**Fix:**
```bash
# 1. Stop the backend server
npx kill-port 3085

# 2. Regenerate Prisma client
npx prisma generate

# 3. Remove any (prisma.X as any) casts in the code

# 4. Restart
npm run dev
```

---

### 5. Quick checklist when backend behaves unexpectedly

```bash
# Is it running?
curl http://localhost:3085/

# Is the DB reachable?
node -e "const {PrismaClient}=require('@prisma/client');const p=new PrismaClient();p.user.count().then(n=>{console.log('DB OK, users:',n);p.\$disconnect()})"

# Are the seed users there?
# (run from backend/ dir)
node -e "const {PrismaClient}=require('@prisma/client');const p=new PrismaClient();p.user.findMany({select:{email:true,role:true}}).then(u=>{console.log(JSON.stringify(u,null,2));p.\$disconnect()})"

# What port is the backend on?
netstat -ano | grep 3085
```

---

### 6. Full reset (nuclear option)

```bash
cd backend

# Stop server
npx kill-port 3085

# Regenerate Prisma
npx prisma generate

# Re-run migrations
npx prisma migrate deploy

# Re-seed
npx ts-node prisma/seed.ts

# Build and start
npm run build && npm run dev
```

---

## Quick Login Accounts (after seeding)

| Button | Email | Password | Role |
|--------|-------|----------|------|
| Super Admin | super@amirani.dev | SuperAdmin123! | SUPER_ADMIN |
| Gym Owner | owner@amirani.dev | GymOwner123! | GYM_OWNER |
| Branch Admin | branch@amirani.dev | BranchAdmin123! | BRANCH_ADMIN |
| Trainer | trainer@amirani.dev | Trainer123! | TRAINER |

Test all at once:
```bash
for creds in "super@amirani.dev:SuperAdmin123!" "owner@amirani.dev:GymOwner123!" "branch@amirani.dev:BranchAdmin123!" "trainer@amirani.dev:Trainer123!"; do
  email="${creds%%:*}"; pass="${creds##*:}"
  result=$(curl -s -X POST http://localhost:3085/api/auth/login \
    -H "Content-Type: application/json" \
    -d "{\"email\":\"$email\",\"password\":\"$pass\"}")
  echo "$email: $(echo $result | grep -o '"role":"[^"]*"')"
  sleep 1
done
```

---

## Port Reference

| Service | Port |
|---------|------|
| Backend API | 3085 |
| Admin Next.js | 3000 (default) |
| Redis (Docker) | 6375 |
| PostgreSQL | 5432 (default) |
