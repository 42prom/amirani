---
name: flutter-scaffold
description: Generates production-ready Flutter project scaffolds using Clean Architecture. Use this skill when the user wants to start a new Flutter project, create a new app from scratch, or needs a comprehensive project structure setup.
---

# Flutter Scaffold Skill

This skill guides the creation of a production-ready Flutter application using Clean Architecture and best practices.

## Process

1.  **Analyze Brief**: storage, target platfor---
    name: flutter-scaffold
    description: Generates production-ready Flutter project scaffolds using Clean Architecture. Use this skill when the user wants to start a new Flutter project, create a new app from scratch, or needs a comprehensive project structure setup.

---

# Flutter Scaffold Skill

This skill guides the creation of a production-ready Flutter application using Clean Architecture and best practices.

## Process

1.  **Analyze Brief**: storage, target platforms, branding, backend, timeline.
2.  **Clarify**: Ask _minimum_ necessary questions if critical info is missing (e.g., "Riverpod or BLoC?").
3.  **Generate Plan**:
    - **Architecture**: Clean Architecture (Data, Domain, Presentation).
    - **State Management**: Riverpod (default) or BLoC.
    - **Routing**: go_router.
    - **Networking**: Dio + Retrofit (or raw Dio).
    - **Models**: freezed + json_serializable.
    - **DI**: get_it + injectable (or Riverpod providers).
4.  **Execute Scaffolding**:
    - Define Folder Structure (see `references/clean_architecture.md`).
    - Create `pubspec.yaml` (Check web for latest stable versions).
    - Create Core Files (`main.dart`, `app.dart`, `theme/`).
5.  **Finalize**:
    - Output setup commands (see `references/project_checklist.md`).

## Rules

- **Null Safety**: Strict.
- **Lints**: `flutter_lints` or `very_good_analysis`.
- **Naming**: consistent snake_case for files, PascalCase for classes.
- **Performance**: Use `const` constructors everywhere possible.
- **Accessibility**: Semantics, standard tap targets.

## Steps to Generate

### Step 1: Pubspec & Configuration

Search for the latest versions of:

- `flutter_riverpod` / `flutter_bloc`
- `go_router`
- `dio`
- `freezed`, `freezed_annotation`, `json_serializable`, `json_annotation`
- `get_it`, `injectable` (if using)
- `flutter_lints`

Generate `pubspec.yaml`.

### Step 2: Folder Structure

Generate the directory tree based on `references/clean_architecture.md`.

### Step 3: Core Boilerplate

Provide code for:

- `lib/main.dart` (Entry point, DI setup)
- `lib/app.dart` (MaterialApp, Router config, Theme)
- `lib/core/` (Exceptions, Failures, UseCase interface)

### Step 4: Feature Example

Implement one feature (e.g., Auth or Home) with:

- Domain: Entity, Repository Interface, UseCase.
- Data: DTO, Repository Impl, DataSource.
- Presentation: State/Controller, Screen/UI.

### Step 5: Testing & CI

- Setup `test/` folder structure.
- Provide a basic unit test example.
- Outline a CI workflow (GitHub Actions).

### Step 6: Handoff

Present the "Next Steps" checklist from `references/project_checklist.md`..
ms, branding, backend, timeline. 2. **Clarify**: Ask _minimum_ necessary questions if critical info is missing (e.g., "Riverpod or BLoC?"). 3. **Generate Plan**: - **Architecture**: Clean Architecture (Data, Domain, Presentation). - **State Management**: Riverpod (default) or BLoC. - **Routing**: go_router. - **Networking**: Dio + Retrofit (or raw Dio). - **Models**: freezed + json_serializable. - **DI**: get_it + injectable (or Riverpod providers). 4. **Execute Scaffolding**: - Define Folder Structure (see `references/clean_architecture.md`). - Create `pubspec.yaml` (Check web for latest stable versions). - Create Core Files (`main.dart`, `app.dart`, `theme/`). 5. **Finalize**: - Output setup commands (see `references/project_checklist.md`).

## Rules

- **Null Safety**: Strict.
- **Lints**: `flutter_lints` or `very_good_analysis`.
- **Naming**: consistent snake_case for files, PascalCase for classes.
- **Performance**: Use `const` constructors everywhere possible.
- **Accessibility**: Semantics, standard tap targets.

## Steps to Generate

### Step 1: Pubspec & Configuration

Search for the latest versions of:

- `flutter_riverpod` / `flutter_bloc`
- `go_router`
- `dio`
- `freezed`, `freezed_annotation`, `json_serializable`, `json_annotation`
- `get_it`, `injectable` (if using)
- `flutter_lints`

Generate `pubspec.yaml`.

### Step 2: Folder Structure

Generate the directory tree based on `references/clean_architecture.md`.

### Step 3: Core Boilerplate

Provide code for:

- `lib/main.dart` (Entry point, DI setup)
- `lib/app.dart` (MaterialApp, Router config, Theme)
- `lib/core/` (Exceptions, Failures, UseCase interface)

### Step 4: Feature Example

Implement one feature (e.g., Auth or Home) with:

- Domain: Entity, Repository Interface, UseCase.
- Data: DTO, Repository Impl, DataSource.
- Presentation: State/Controller, Screen/UI.

### Step 5: Testing & CI

- Setup `test/` folder structure.
- Provide a basic unit test example.
- Outline a CI workflow (GitHub Actions).

### Step 6: Handoff

Present the "Next Steps" checklist from `references/project_checklist.md`..
