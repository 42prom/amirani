---
name: flutter-scaffold
description: Generates production-ready Flutter project scaffolds using Clean Architecture. Use this skill when the user wants to start a new Flutter project, create a new app from scratch, or needs a comprehensive project structure setup.
---

# Flutter Scaffold Skill

**Always follow these rules to reduce common LLM coding mistakes.**

1. **Think Before Coding**
   - State assumptions explicitly. If uncertain, ask.
   - Present multiple interpretations if they exist — never choose silently.
   - If a simpler approach exists, say so and push back when warranted.
   - Surface tradeoffs clearly.

2. **Simplicity First**
   - Minimum code that solves the problem. Nothing speculative.
   - No features, abstractions, or “future-proofing” beyond what was explicitly requested.
   - No error handling for impossible scenarios.
   - If you write 200 lines and it could be 50, rewrite it.
   - Ask: “Would a senior engineer call this overcomplicated?”

3. **Surgical Changes**
   - Touch only what the user requested.
   - Never refactor, improve, or reformat unrelated code.
   - Match existing style and naming conventions exactly.
   - Clean up only your own mess (unused imports, variables, etc. created by your changes).
   - If you notice unrelated dead code, mention it — never delete it unless asked.

4. **Goal-Driven Execution**
   - Turn every task into verifiable success criteria.
   - For multi-step work, provide a brief numbered plan with explicit verification steps.
   - Loop independently until success criteria are met.

## Process

1. **Analyze Brief**  
   Extract: target platforms, storage needs, branding, backend integration, timeline, and any specific preferences.

2. **Clarify (Minimal Questions Only)**  
   Ask the absolute minimum number of questions needed to proceed. Example: “Riverpod or BLoC for state management?”

3. **Generate & Present Plan**  
   Before any code, clearly state the plan referencing:
   - Clean Architecture (see `clean_architecture.md`)
   - State Management: Riverpod (default) or BLoC
   - Routing: go_router
   - Networking: Dio (+ Retrofit if requested)
   - Models: freezed + json_serializable
   - DI: get_it + injectable or pure Riverpod providers

4. **Execute Scaffolding** (Surgical & Verifiable)
5. **Finalize & Handoff**

## Rules

- Null Safety: Strict.
- Lints: `flutter_lints` or `very_good_analysis`.
- Naming: snake_case for files/folders, PascalCase for classes.
- Performance: Use `const` constructors wherever possible.
- Accessibility: Include proper Semantics and standard tap targets.

## Steps to Generate

### Step 1: Pubspec & Configuration

Search for latest stable versions of:

- `flutter_riverpod` / `flutter_bloc`
- `go_router`
- `dio`
- `freezed`, `freezed_annotation`, `json_serializable`, `json_annotation`
- `get_it`, `injectable` (only if using)
- `flutter_lints`

Generate a complete `pubspec.yaml`.

### Step 2: Folder Structure

Create the exact directory tree defined in `clean_architecture.md`.

### Step 3: Core Boilerplate

Provide only these files:

- `lib/main.dart` (entry point + DI setup)
- `lib/app.dart` (MaterialApp + router + theme)
- `lib/core/` utilities (exceptions, failures, base UseCase)

### Step 4: Feature Example

Implement **exactly one** complete feature (usually Auth or Home) with all three layers:

- Domain (Entity, Repository interface, UseCase)
- Data (DTO, Repository impl, DataSource)
- Presentation (State/Controller, Screen, Widgets)

### Step 5: Testing & CI

- Create matching `test/` folder structure.
- Provide one basic unit test example.
- Outline a minimal GitHub Actions CI workflow.

### Step 6: Handoff

Present the complete “Next Steps” checklist from `project_checklist.md`.

## Final Notes

- All generated code must be production-ready, null-safe, and follow the Clean Architecture dependency rules strictly.
- When in doubt: **simpler is better**.
- Always verify success criteria before claiming completion.
