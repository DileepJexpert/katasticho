# Katasticho ERP

## Start the web app on Windows

From this directory, use the recovery-safe launcher instead of a long port-specific command:

```powershell
.\run-dev-web.ps1
```

For a full Chrome/DWDS cache reset, run:

```powershell
.\reset-chrome-dwds.ps1
```

It preserves existing Chrome windows, clears stale Dart debug processes, uses Flutter's automatically selected web port, and disables experimental web hot reload. If Chrome still cannot attach its DWDS debugger, start the app with the built-in web server and open the URL printed by Flutter:

```powershell
.\run-dev-web.ps1 -Device web-server
```

Use `-Device edge` if Microsoft Edge is preferred.

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
