---
summary: "Windows porting plan, stacked PR boundaries, and the local verification strategy."
read_when:
  - working on the Windows port
  - deciding whether a change belongs in the shared core or a platform shell
  - running the Windows port locally or in CI
---

# Windows porting plan

## Goal

Keep the existing macOS app intact while adding a Windows build that reuses the
usage parsers, companion rules, save format, and network clients. Windows is a
second application shell, not a second set of business rules.

The first supported Windows milestone is deliberately smaller than the macOS
feature set:

- read local usage logs
- show today's combined token count
- show a static companion image in a tray popup
- preserve and restore the existing companion save format

Floating pets, animated GIFs, official limit credentials, notifications, login
startup, and self-update follow after the headless path is stable.

## Current platform boundary

The current package is macOS-only because the executable target includes
AppKit, SwiftUI, UserNotifications, Security, ServiceManagement, and ImageIO
code in one module. Removing the macOS platform declaration alone would not
produce a Windows build.

The port must keep these responsibilities behind platform boundaries:

| Shared responsibility | Platform-specific implementation |
| --- | --- |
| usage parsing and aggregation | local filesystem roots and process environment |
| companion state and progression | application-data directory and notifications |
| save import/export | file picker and confirmation UI |
| image data and frame timing | image decoder and window/tray rendering |
| official credentials | macOS Keychain or Windows Credential Manager |
| login startup | ServiceManagement or Windows Startup Task |
| update action | `NSWorkspace`/Homebrew or a Windows installer/updater |

## Stacked PR sequence

Each PR should build on the previous branch and stay runnable on macOS. The
stack is kept in the personal fork `ite476/PokeTokenBar`; the upstream
repository is not a PR target.

1. **Porting plan and boundary**
   - this document
   - agreed Windows MVP and verification commands

2. **Portable runtime foundation**
   - centralize application-data, cache, log, and temporary paths
   - make provider roots and binary lookup injectable
   - keep macOS defaults unchanged

3. **Headless Windows runner**
   - add a Windows-compatible Swift executable target
   - exercise usage parsing, aggregation, save loading, and companion updates
   - run the same smoke command locally and on a Windows GitHub Actions runner

4. **Windows tray shell**
   - add the tray icon and a small popup using Swift/Win32 or WinUI bindings
   - connect it to the shared runner without moving business rules into UI code

5. **Feature parity**
   - sprite and GIF handling
   - floating pet
   - credentials, notifications, startup, and update delivery

## Verification strategy

### macOS baseline

Run these commands on every stack branch before pushing:

```bash
swift build
swift test
```

Use an isolated state directory when manually exercising the app or a smoke
runner so local companion progress is not overwritten:

```bash
PTB_STATE_DIR="$(mktemp -d)/state" swift test
```

The existing `PTB_STATE_DIR` override is the first development safety boundary;
the Windows path provider should preserve the same behavior.

### Windows headless runner

After the headless runner lands, the intended Windows command is:

```powershell
$env:PTB_STATE_DIR = Join-Path $env:TEMP "PokeTokenBar-state"
swift test
swift run PokeTokenBarWindows --once
```

The `--once` mode must read a snapshot, print provider totals and the combined
total, update the companion state, and exit. A one-shot command is easier to
debug than a tray process and becomes the common local/CI smoke test.

### Windows UI runner

The tray shell should be started only after the headless command passes. Its
first manual test should use a fixture directory or an explicit provider-root
override, not a user's live CLI logs. UI checks should cover tray creation,
popup open/close, refresh, and clean exit before adding animation or startup
registration.

## Out of scope for the first Windows milestone

- changing the macOS UI or release flow
- adding a Windows-specific usage provider without an upstream format check
- silently reading or migrating credentials
- claiming Windows support before Windows CI and a real local smoke run pass
