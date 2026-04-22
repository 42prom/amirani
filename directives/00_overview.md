# Directive 00 — Project Overview & Vision

## Project Name

**Amirani** — AI-Powered Smart Health & Gym Ecosystem Platform (Flagship Tier)

## Core Philosophy

This is NOT a gym app. This is a **Smart Adaptive Health Operating System**.

The system must act simultaneously as:

- A personal AI coach
- A dietitian & calorie advisor
- A workout planner
- A health monitor
- A motivational companion
- A gym management platform
- A smart access control system
- A predictive behavioral engine

> Every screen, every interaction, every notification must reinforce the feeling:
> **"This app understands me and acts on my behalf."**

---

## User Roles

| Role        | ID            | Description                                                             |
| ----------- | ------------- | ----------------------------------------------------------------------- |
| Super Admin | `SUPER_ADMIN` | Platform owner. (Web Only) Manages gyms, billing tiers.                 |
| Gym Owner   | `GYM_OWNER`   | Manages gym(s). (Web Only) Sets inventory, trainers.                    |
| Trainer     | `TRAINER`     | Assigned to members. Can view/edit member plans and stats.              |
| Gym Member  | `GYM_MEMBER`  | Linked to a gym. Has active subscription. Full AI coaching.             |
| Home User   | `HOME_USER`   | No gym linked. Bodyweight/home workout + full AI coaching. Can upgrade. |

---

### User Roles & Access

| Role            | Access Platform | Registration Mode       |
| :-------------- | :-------------- | :---------------------- |
| **Super Admin** | Web Dashboard   | System Pre-configured   |
| **Gym Owner**   | Web Dashboard   | Created by Super Admin  |
| **Trainer**     | Web Dashboard   | Created by Gym Owner    |
| **Gym Member**  | Mobile App      | Self-Register / Invited |
| **Home User**   | Mobile App      | Self-Register           |

> [!IMPORTANT]
> **Registration Logic**: Only `GYM_MEMBER` and `HOME_USER` roles can self-register via the mobile application. `GYM_OWNER` and `TRAINER` accounts MUST be created manually through the Web Administrative Dashboard by a superior role.

## Platforms

- **Mobile (Flutter)**: iOS + Android (Gym Members & Home Users only)
- **Web (Next.js)**: Admin & Super Admin dashboard — served locally via `npm run dev` in `admin/`
- **Backend (Node.js/TypeScript)**: Core API — served locally via `npm run dev` in `backend/`
- **Infrastructure**: PostgreSQL + Redis via Docker Compose (`docker-compose.yml`)
- **Public Tunnel**: Cloudflared tunnel exposes the local backend to the internet for mobile device access

---

## Running Services (Development)

| Service    | Location   | Command              | Notes                                   |
| ---------- | ---------- | -------------------- | --------------------------------------- |
| Backend    | `backend/` | `npm run dev`        | Node.js/TS API on port 3000             |
| Admin      | `admin/`   | `npm run dev`        | Next.js dashboard on port 3001          |
| Mobile     | `mobile/`  | `flutter run`        | Flutter iOS/Android app                 |
| DB + Cache | root       | `docker compose up`  | PostgreSQL + Redis via docker-compose   |
| Tunnel     | root       | `cloudflared tunnel run` | Exposes backend publicly for mobile |

---

## AI Adaptation Surface

The AI must continuously adapt based on:

- Missed workouts
- User fatigue & recovery signals
- Sleep input (manual or wearable API)
- Calorie intake vs target
- Subscription status
- Attendance frequency
- Body progress logs (weight, measurements)
- Gym equipment availability
- User motivation score input

---

## AI Pipeline Architecture

Plans are generated via a **BullMQ async job queue** on the backend:

1. Mobile sends generation request → backend enqueues an AI job.
2. Backend responds immediately with `{ status: "QUEUED", jobId }`.
3. Mobile **polls** `/ai/status/:jobId/:type` with exponential backoff (max 60 attempts, 10s cap).
4. On `COMPLETED`, backend returns the full AI-generated plan JSON.
5. Mobile parses and persists the plan to **Hive** (encrypted offline cache).
6. The plan is anchored to **Monday of the current week** to ensure calendar alignment.

> [!IMPORTANT]
> **Plan Structure**: AI generates a **7-day template** (`days[]` array). The mobile client repeats this template across **4 weeks** to build a `MonthlyDietPlanEntity` or `MonthlyWorkoutPlanEntity`.

---

## Quality Standard

This must be a **flagship, scalable, AI-native, next-generation** smart health ecosystem.
No shortcuts. No MVP compromises on UX. Every screen must feel premium.

---

## Key Constraints for Agents

- Never mix module styles (each module has its own design pattern — see `01_ui_ux.md`)
- Always consult `01_ui_ux.md` before writing any widget
- Always consult `02_architecture.md` before creating any new file or class
- AI engine orchestration logic always goes in `core/services/ai_orchestration_service.dart` — never inline in UI
- AI strategy pattern: `AIStrategy.offline` (mock), `AIStrategy.api` (BullMQ backend), `AIStrategy.directAI` (DeepSeek direct)
- Door access logic must use adapter pattern — never hardcode a specific door system
- Plan data models use `freezed` + `hive_flutter` for type-safe Hive persistence
