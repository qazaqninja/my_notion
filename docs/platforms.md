# Platform support

Quill targets all five Flutter desktop/mobile platforms. Status as of v0.1.0:

| Platform | Build verified | Tested | Notes |
|---|:-:|:-:|---|
| **macOS** | ✅ | ✅ | Primary dev target. Live tested end-to-end via the picker → sidebar → editor → palette flow. Entitlements at `macos/Runner/{Debug,Release}.entitlements`. |
| **iOS** | ✅ | — | `flutter build ios --no-codesign --debug` produces `Runner.app`. Mobile shell (drawer + tab bar) engages on iPhone widths. |
| **Android** | ⏳ | — | Code is structurally portable; needs `flutter build apk` on a host with Android SDK. |
| **Linux** | ⏳ | — | `flutter build linux` requires a Linux host. CI (GitHub Actions ubuntu-latest) is the practical path. |
| **Windows** | ⏳ | — | `flutter build windows` requires a Windows host. CI (windows-latest) is the practical path. |

## Platform-specific notes

### macOS entitlements

The app runs in App Sandbox. Required entitlements (both Debug and Release):

```xml
<key>com.apple.security.app-sandbox</key><true/>
<key>com.apple.security.network.client</key><true/>           <!-- future sync -->
<key>com.apple.security.files.user-selected.read-write</key><true/>  <!-- vault picker -->
<key>com.apple.security.files.bookmarks.app-scope</key><true/>       <!-- vault persistence -->
```

Debug also needs `com.apple.security.cs.allow-jit` (the Dart VM) and
`com.apple.security.network.server` (the VM Service).

### Vault persistence across launches (C2)

Shipped at M1236-M1238 of the 1m-loop plan. Cross-launch sandbox access is
preserved via a security-scoped bookmark MethodChannel:

1. **Pick**: after `FilePicker.platform.getDirectoryPath(...)` returns a
   path, `VaultBloc._onPick` calls `SecurityScopedBookmarks.save(path)`.
   Swift side (`macos/Runner/AppDelegate.swift`) runs
   `URL.bookmarkData(.withSecurityScope, …)` and returns the Base64
   bytes; Dart stores them under SharedPreferences key `vault.bookmark`.
2. **Restore**: `VaultBloc.tryRestore` reads `vault.bookmark` first. If
   present, calls `SecurityScopedBookmarks.resolve(...)` which on the
   Swift side runs `URL(resolvingBookmarkData:.withSecurityScope, …)`,
   fires `startAccessingSecurityScopedResource()`, and returns the
   resolved path. The path goes into a `LoadFromPath` event and the
   indexer runs against a folder the sandbox accepts.
3. **Fallback**: if no bookmark is stored (non-macOS host or save
   failed) or `resolve()` returns null (stale bookmark), the raw
   `vault.path` is used. Existing PathAccessException → clear-prefs
   behaviour in `_onLoad` still applies.

Manual verification (per macOS build):
- Pick a vault outside `~/Documents` (e.g. `~/Desktop/Quill-test/`).
- Quit the app (Cmd+Q, not just window close).
- Relaunch: the vault opens directly without the picker. If the bookmark
  fails (deleted folder, etc.), the picker re-appears with no error.

### File-reveal

`Properties Panel → Reveal in Finder` should call:
- macOS: `open -R <path>`
- Linux: `xdg-open` on the parent directory
- Windows: `explorer.exe /select,<path>`

These are placeholders in v1 (the panel rows are visual). The Process
calls are straightforward to wire up — left as a follow-up.

### Fonts

Fonts are vendored in `assets/fonts/` (InterVariable.ttf + JetBrains
Mono Regular/Medium/Bold). No `google_fonts` runtime fetch is needed,
which keeps the app working without network and inside sandboxes that
block outbound HTTPS.

### Notifications (B4)

Reminders set via the editor kebab's `reminder:` frontmatter field
schedule OS-level notifications via `flutter_local_notifications` (added
at M1224). Per-platform setup:

**iOS / macOS**: `DarwinInitializationSettings()` (in
`lib/features/reminders/data/datasources/notification_scheduler.dart`)
requests alert + sound + badge permissions automatically the first time
the scheduler `init()`s. No Info.plist key required — the user receives
the system permission prompt on first launch when a reminder is
scheduled. On macOS, the entitlement
`com.apple.security.cs.allow-jit` (already present) is sufficient; no
additional sandbox capability is needed.

**Android**: `<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>`
is declared in `android/app/src/main/AndroidManifest.xml` and is
required on Android 13 (API 33+) for any notification dispatch. The
runtime permission prompt is triggered by the plugin when
`scheduler.init()` runs.

The scheduler uses `AndroidScheduleMode.inexactAllowWhileIdle`, which
does *not* require `SCHEDULE_EXACT_ALARM` (an Android 14+ special
permission). Reminders may fire up to several minutes late under
aggressive doze — acceptable for human-scale "midnight reminder"
semantics; users wanting precise minute-level scheduling can install a
companion app.

**Linux / Windows**: The plugin is no-op on these platforms in v20.x.
The `RemindersBloc` still records the in-memory state so the UI badge
counts correctly, but no actual OS notification fires. Cross-platform
reminders would need a backend daemon (Phase E V2).
