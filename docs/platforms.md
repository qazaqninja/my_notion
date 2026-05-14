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

### Vault persistence across launches

The current implementation stores only the vault *path* in
`shared_preferences`. The macOS sandbox doesn't keep the user-granted
file-access bookmark across launches without `applicationsBookmark` API
work — so auto-restore intentionally bails to the picker if access is
denied (silently clears the stale pref).

For full session continuity (open vault → quit → relaunch → vault still
open), the next iteration should:
1. After a successful pick, request a security-scoped bookmark URL via
   `NSURL.bookmarkData(options:.withSecurityScope)`.
2. Store the bookmark bytes (base64) in `shared_preferences`.
3. On launch, resolve via `NSURL(byResolvingBookmarkData:...)` and call
   `startAccessingSecurityScopedResource()` before reindexing.

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
