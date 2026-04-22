# Clean Architecture for Flutter

This reference defines the standard Clean Architecture structure for generated projects.

## Core Layers

1.  **Domain** (Inner layer, Pure Dart)
    - **Entities**: Business objects (e.g., `User`).
    - **Repositories**: Interfaces defining data operations (e.g., `IAuthRepository`).
    - **UseCases**: Specific business logic units (e.g., `LoginUseCase`).
2.  **Data** (Middle layer, implementations)
    - **DataSources**: Remote (API) or Local (DB) data fetchers.
    - **DTOs**: Data Transfer Objects (parsing JSON).
    - **Repositories**: Implementations of Domain Repositories.
3.  **Presentation** (Outer layer, Flutter)
    - **State Management**: Providers/Cubits/BLoCs.
    - **Widgets**: Reusable UI components.
    - **Screens/Pages**: Full views.

## Recommended Folder Structure

```
lib/
├── config/             # Routes, Themes, Constants
│   ├── routes/
│   ├── theme/
│   └── constants.dart
├── core/               # Shared utilities across features
│   ├── error/          # Failures, Exceptions
│   ├── network/        # Dio client, Interceptors
│   ├── usecase/        # Base UseCase class
│   └── utils/
├── features/           # Feature-based organization
│   ├── auth/
│   │   ├── data/
│   │   │   ├── datasources/
│   │   │   ├── models/ (DTOs)
│   │   │   └── repositories/
│   │   ├── domain/
│   │   │   ├── entities/
│   │   │   ├── repositories/ (Interfaces)
│   │   │   └── usecases/
│   │   └── presentation/
│   │       ├── providers/ (or bloc/)
│   │       ├── widgets/
│   │       └── screens/
│   └── home/
│       └── ...
├── main.dart
└── app.dart
```

## Dependency Rules

- **Domain** depends on NOTHING.
- **Data** depends on **Domain**.
- **Presentation** depends on **Domain**.
- **Presentation** NEVER imports **Data** directly (use DI).
