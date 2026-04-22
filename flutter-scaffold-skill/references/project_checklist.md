# Project Setup Checklist

After scaffolding the project, perform the following steps:

## Initial Setup

- [ ] Run `flutter pub get` to install dependencies.
- [ ] Run `dart run build_runner build --delete-conflicting-outputs` to generate code (Freezed, JSON, etc.).
- [ ] Create `.env` file from `.env.example` if applicable.

## Verification

- [ ] Run `flutter analyze` and ensure zero lint errors.
- [ ] Run `flutter test` to ensure base tests pass.
- [ ] Run `flutter run` on a simulator/emulator to verify the app starts.

## Development

- [ ] Rename the app bundle ID if necessary: `flutter pub run change_app_package_name:main com.new.name`.
- [ ] Update `assets/` with real images/fonts.
- [ ] Configure CI/CD variables (e.g., in GitHub Secrets).

## Troubleshooting

- If build runner fails, try `flutter clean` then `flutter pub get`.
- If iOS pod issues occur, `cd ios && pod install --repo-update`.
