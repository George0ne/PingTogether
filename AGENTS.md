# Working on PingTogether

This is a native macOS desktop-overlay utility, not a web app, browser extension, or game mod. Start with README.md for the user experience. Keep user-facing text concise and primarily Chinese.

## Stack and entry points

- Objective-C with ARC; `src/main.m` currently contains the application.
- AppKit: menu-bar accessory application and borderless nonactivating NSPanel overlays.
- Carbon: registered global hotkeys. Do not replace these with keyboard recording or a broad event tap without a demonstrated need.
- AVFoundation: WAV playback. CoreAudio is used only to inspect the default output device and mute state.
- No third-party runtime dependencies, telemetry, document parsing, screen capture, server, or network transport.
- `build.sh` compiles arm64 + x86_64, minimum macOS 12, creates AppIcon.icns from the bundled question-mark PNG, and ad-hoc signs the app.
- `package.sh` builds, self-tests, verifies the signature, packages a read-only DMG, and writes SHA-256.

## Important code landmarks

Search by symbol rather than relying on line numbers:

- `Selection`: eight-way angular hit testing and center cancellation.
- `HoldState`, `BeginHold`, `EndHold`, `CancelHold`: press/repeat/release/cancel lifecycle.
- `WheelView`: wheel rendering and local interaction.
- `MarkView`: texture-based ping animation.
- `SelectionView`, `DragRect`, `ValidHighlight`: drag-to-highlight capture.
- `EmphasisView`, `EmphasisAlpha`: subtle highlight rendering and lifetime.
- `AppDelegate`: global hotkeys, panel lifecycle, mute menu, audio and packaging-facing CLI entry points.
- `HotKeyHandler`, `beginHeldWheel`, `releaseHeldWheel`: global hold-to-select behavior.
- `playSound`, `OutputStatus`, `testSound`: audio startup, retention and diagnostics.
- `SelfTest`: current deterministic assertions.

## Preserve these interaction contracts

1. Hold Option+Q to open the wheel at the pointer. Move to select; release either Q or Option to send at the original anchor.
2. Pressing and holding must not repeatedly reopen the wheel. Escape cancels until a fresh press; multiple release paths must not double-send.
3. Center release cancels. Mouse movement outside the wheel should still select a direction. Re-evaluate the pointer at release.
4. Control+Option+Q directly sends a question mark.
5. Option+A enters highlight mode once; a mouse drag creates a screen-space rectangle, then sends a question mark near it. An accidental click does nothing.
6. Highlights last exactly 6 seconds, fading during the final 0.75 seconds. Option+X clears immediately. A new highlight replaces the old one.
7. Capture panels intercept input only while selecting. Finished pings and highlights MUST ignore mouse events.
8. Selection mode can be cancelled with Escape/right-click and times out after 30 seconds. Display-layout changes clear transient highlight state.
9. Do not change system audio devices, volume, mute state, privacy permissions, or startup items automatically.
10. No document anchoring currently exists. Never claim highlights track PDF scrolling or that friend synchronization is implemented.

## Build and validate

```sh
bash build.sh
build/PingTogether.app/Contents/MacOS/PingTogether --self-test
codesign --verify --deep build/PingTogether.app
bash package.sh
```

Build with warnings treated as errors. The self-test covers gesture state, angular selection, highlight geometry/clipping/expiry, bundled texture decoding and all eight WAV files. A passing test is not proof of physical speaker output or successful live screen sharing.

For audio work, run `--test-audio` (audible) and report what was actually observed. For UI changes, render and inspect relevant native previews, then manually test interactions where possible:

```sh
build/PingTogether.app/Contents/MacOS/PingTogether --render-preview /tmp/wheel.png
build/PingTogether.app/Contents/MacOS/PingTogether --render-mark /tmp/mark.png 0.35
build/PingTogether.app/Contents/MacOS/PingTogether --render-emphasis /tmp/emphasis.png
```

Manual checks should match the change: cross-app shortcut, release/cancel, rapid repeated pings, selection in both directions, click-through after completion, display edges, multiple displays/fullscreen, mute and screen-sharing capture. Do not claim unperformed checks. Avoid repeatedly playing audio unnecessarily.

## Packaging and documentation

- Keep build outputs, DMGs, local paths, logs, credentials and temporary files out of source commits. Attach installers to GitHub Releases.
- Build and sign in a temporary directory; cloud-synced folders may inject Finder metadata that causes strict signing checks to fail.
- Release files should include the App, Applications link, 使用说明.txt and 素材来源.txt.
- Keep version numbers, shortcuts, duration constants, menu/help text, README and 使用说明.txt consistent.
- Do not claim Developer ID signing, Apple notarization, or Intel runtime verification unless performed. Universal binary compilation alone does not prove execution on both CPU families.
- Never delete the only source copy before verifying a complete remote copy. Keep the installed `/Applications/PingTogether.app` intact during source-only work.

## Assets and scope

Read `assets/SOURCES.md` before changing assets. Preserve upstream attribution, original source URLs and hashes. Riot-owned images and sounds are not covered by the upstream repository's MIT license. Do not silently label the entire repository MIT or claim authorization that has not been established.

Prefer targeted native changes over framework migrations. Friend synchronization, persistent document annotations, arbitrary shortcut configuration, auto-updates and notarization are future work, not current features. If adding synchronization, screen coordinates alone cannot align differently scrolled documents.
