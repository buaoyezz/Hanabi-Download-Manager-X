# Contributing to Hanabi Download Manager X

[中文版](CONTRIBUTING_CN.md)

Thank you for your interest in contributing to Hanabi Download Manager X! We welcome all forms of contributions.

## Ways to Contribute

- Report bugs
- Suggest new features
- Improve documentation
- Submit code fixes or new features
- Translate documentation or UI

## Development Setup

### Prerequisites

- Flutter SDK 3.0.0+
- Dart SDK 3.0.0+
- Git
- Visual Studio Code (recommended) or Android Studio

### Clone Repository

```bash
git clone https://github.com/buaoyezz/hanabi-download-manager-x.git
cd hanabi-download-manager-x
```

### Install Dependencies

```bash
flutter pub get
```

### Run Development Build

```bash
flutter run -d windows
```

## Code Standards

### Dart Code Style

Follow [Effective Dart](https://dart.dev/guides/language/effective-dart) guidelines:

- Use `lowerCamelCase` for variables and methods
- Use `UpperCamelCase` for classes and enums
- Use `snake_case` for libraries and files
- Keep lines under 80 characters (recommended)
- Format code with `dartfmt`

### Commit Convention

Use [Conventional Commits](https://www.conventionalcommits.org/) format:

```
<type>(<scope>): <subject>

<body>

<footer>
```

Types:
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation update
- `style`: Code formatting
- `refactor`: Code refactoring
- `perf`: Performance optimization
- `test`: Testing related
- `chore`: Build/toolchain updates

Example:
```
feat(download): add multi-threaded download support

- Implement dynamic segmentation algorithm
- Add thread count configuration option
- Optimize memory usage

Closes #123
```

## Submitting Pull Requests

### 1. Fork Repository

Click the "Fork" button in the top right to fork the repository to your account.

### 2. Create Branch

```bash
git checkout -b feature/your-feature-name
```

Branch naming:
- `feature/xxx` - New features
- `fix/xxx` - Bug fixes
- `docs/xxx` - Documentation updates
- `refactor/xxx` - Code refactoring

### 3. Commit Code

```bash
git add .
git commit -m "feat: add new feature"
git push origin feature/your-feature-name
```

### 4. Create Pull Request

1. Visit your forked repository
2. Click "New Pull Request"
3. Fill in PR title and description
4. Wait for code review

## PR Checklist

Before submitting PR, confirm:

- [ ] Code follows project standards
- [ ] All tests pass
- [ ] Added necessary comments
- [ ] Updated related documentation
- [ ] Commit messages are clear
- [ ] No merge conflicts

## Reporting Bugs

Use [GitHub Issues](https://github.com/buaoyezz/hanabi-download-manager-x/issues) to report bugs.

Please provide:

- OS version
- Flutter version
- App version
- Steps to reproduce
- Expected behavior
- Actual behavior
- Error logs (if any)
- Screenshots (if any)

## Feature Requests

Use [GitHub Issues](https://github.com/buaoyezz/hanabi-download-manager-x/issues) for feature requests.

Please describe:

- Feature description
- Use case
- Expected outcome
- Possible implementation (optional)

## Documentation Contributions

Documentation is located at:

- `README.md` - English documentation
- `README_CN.md` - Chinese documentation
- `HowToUse.md` - Usage guide
- `lib/l10n/` - Localization files

## Community Guidelines

- Respect others, communicate kindly
- Provide constructive feedback
- Accept different viewpoints
- Focus on the project itself

## License Agreement

By submitting code, you agree to license it under GPL-3.0.

## Contact

- GitHub Issues: [Submit Issue](https://github.com/buaoyezz/hanabi-download-manager-x/issues)
- Email: [Contact Author](mailto:support@zzbuaoye.net)
