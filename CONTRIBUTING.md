# Contributing to Lava App

## Development Setup

1. Install Flutter 3.24+ and Dart 3.5+
2. Clone repo: `git clone <repo-url>`
3. Install dependencies: `flutter pub get`
4. Run code generation: `flutter pub run build_runner build`
5. Verify setup: `flutter analyze && flutter test`

## Project Structure

```
lib/
├── main.dart                     # App entry point
├── app/                          # App-level configuration
│   ├── router.dart               # go_router routes
│   ├── theme.dart                # Material theme
│   └── providers.dart            # Global providers
├── shared/                       # Shared Kernel
│   ├── di/                       # Dependency injection
│   ├── storage/                  # KV storage abstraction
│   ├── logger/                   # Logging
│   ├── http/                     # HTTP client (Dio)
│   └── event_bus/                # App event bus
└── features/
    └── device/                   # Device feature module
        ├── domain/               # Domain layer
        │   ├── entities/         # Data classes (Freezed)
        │   ├── interfaces/       # Abstract interfaces
        │   └── value_objects/    # Value objects
        ├── data/                 # Data layer
        │   ├── adapters/         # SDK adapters
        │   ├── repositories/     # Repository impls
        │   └── models/           # Aggregate roots
        ├── application/          # Provider layer
        │   └── providers/        # Riverpod providers
        └── presentation/         # UI layer
            ├── pages/            # Full pages
            └── widgets/          # Reusable widgets
```

## Architecture

- **Clean Architecture** with Vertical Slice per feature
- **Riverpod** for state management
- **Adapter pattern** for SDK integration
- **8-state connection state machine** for device connections

## Code Style

- Follow [Effective Dart](https://dart.dev/guides/language/effective-dart)
- Use `freezed` for immutable data classes
- Document public APIs with `///` comments
- Run `flutter analyze` before committing

## Testing

- Domain layer: 100% coverage target
- Data layer: >70% coverage target
- Provider layer: >80% coverage target

## Commit Convention

Use [Conventional Commits](https://www.conventionalcommits.org/):
- `feat:` new feature
- `fix:` bug fix
- `docs:` documentation
- `test:` tests
- `refactor:` code restructuring
- `chore:` maintenance
