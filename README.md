![HoverCapture — hover, hotkey and paste](docs/assets/readme-banner.png)

# HoverCapture

[简体中文](README.zh-CN.md) · English

Point at a Mac window. Press one shortcut. Get a screenshot of that window, saved as a PNG and ready to paste.

HoverCapture is a small native macOS menu bar app. It does not need Hammerspoon, a browser extension, or a background command-line service.

## 0.2.2 RC3 — Tahoe Dock transparency candidate

[Download RC3 (build 7)](https://github.com/GESANGTAJIE/HoverCapture/releases/tag/v0.2.2-rc.3). **Affected-device acceptance is still pending. Homebrew remains on 0.2.1.** RC2 diagnostics confirmed that a full-display Dock window was being selected ahead of Finder; its title/sharing metadata differed from RC1's assumptions.

RC3 inspects transparency near the pointer only when a full-display, layer-20 Dock surface blocks selection. Transparent pixels allow selection to continue; visible Dock content, unavailable evidence and pointer movement during the check retain screen fallback. This uses existing Screen Recording access, without Accessibility permission. The temporary Dock image is neither saved nor copied. Ordinary windows, menus and other overlays retain their selection rules.

To verify: keep Dock visible and hold the pointer still while capturing. Finder's center should produce `Window-`; a visible Dock icon should produce `Screen-`. If either fails, select **Copy Last Capture Diagnosis** and share its text (`appVersion=0.2.2 build=7`, including `dockProbe` lines). The report includes application identifiers, coordinates and probe outcomes, but no screenshot pixels, window titles or document paths. It remains in memory, is never uploaded automatically, and copying it replaces clipboard content. Copy Batch restores retained screenshots.

Temporary workaround: enable System Settings → Desktop & Dock → Automatically hide and show the Dock, wait until it hides, then capture over an ordinary window. No permission reset is needed for this workaround.

## 0.2.1 preview

Fixes shortcut recovery after a startup conflict and cancellation of login items awaiting approval. Packaging now always rebuilds the current source, preventing stale apps from being shipped under a new version label. Homebrew installation is available through our own tap (see below).

### Batch and interface update: 0.2.0

Version 0.2.0 adds a configurable screenshot batch for pasting several captures together, a manual Chinese/English language selector, and a refreshed settings window with the HoverCapture logo, brand colors, and Lucide icons. The default batch capacity is **1**, preserving the single-image workflow.

See [the testing record](docs/TESTING.md) for the checks actually completed. The user confirmed that one paste inserted all three numbered sample images, in order, in both ChatGPT and WeChat. Other apps and versions may accept fewer clipboard items.

### Earlier visual update: 0.1.1

Version 0.1.1 updates the color app icon, the menu bar icon that follows the system's light and dark appearance, and the README banner. Screenshot behavior is unchanged.

For 0.1.1, all 27 selection tests and both architecture builds passed. The new assets and desktop launch were checked. That rebuilt app needed Screen Recording permission again on the test Mac; capture and clipboard were not retested.

### Earlier functional baseline: 0.1.0

The following checks were completed for **0.1.0** through **2026-10-12** on **macOS 15.7.2, Apple Silicon**. They remain an earlier functional baseline; current-version results are recorded separately in [docs/TESTING.md](docs/TESTING.md):

- **27 selection-logic tests passed, 0 failed**, with successful `arm64` and `x86_64` compilation.
- A physical press of the default shortcut captured an ordinary window, saved its PNG in the default folder, and copied the same image to the clipboard.
- A customized shortcut captured the single display from empty desktop and saved into a chosen folder containing Chinese characters and spaces.
- App startup, settings layout, permission recovery, and persistence of a changed shortcut and folder across a restart were checked.
- GitHub CI generated both **DMG and ZIP** packages on 2026-10-11; local checksum and archive-integrity checks passed.

Overlapping windows, dialogs and popups, Dock/menu fallback, first-install authorization, multiple displays, Intel execution, and launch at login are **still awaiting acceptance testing**. See [the testing record and checklist](docs/TESTING.md) for evidence and remaining scope.

## What it does

- Captures the topmost supported app window under the pointer, without clicking or bringing it to the front.
- Captures the **display containing the pointer** when the pointer is over the desktop, Dock, or menu area.
- Saves to a folder you choose; the default is `~/Downloads/WindowShots`.
- Copies the same image to the clipboard, ready for **Command–V** in an app that accepts images.
- Optionally keeps the latest **1–20 screenshots** in a batch, ordered by capture time, for one paste in apps that accept multiple images or files.
- Uses **Control–Option–Command–S** (`⌃⌥⌘S`) by default, with a customizable global shortcut.
- Excludes window shadows, the pointer, and separately attached child windows from a window capture.
- Offers optional launch at login and a persistent language choice: **Follow System**, **简体中文**, or **English**.
- Uses the HoverCapture logo and brand palette: black `#0E0D0C`, orange `#FF6B2C`, and warm white `#F7F7F5`.
- Processes screenshots locally, with no accounts, analytics, or image uploads.

## Requirements

- **macOS 14.2 or newer.**
- Apple Silicon or Intel Mac. The universal build contains both `arm64` and `x86_64` binaries; availability of both architectures is not a claim that every Mac configuration has been tested.
- Screen Recording permission for HoverCapture.

No additional runtime dependencies are required. Accessibility, Input Monitoring, microphone, and camera permission are not required for the app's screenshot workflow.

## Install

### Homebrew

With [Homebrew](https://brew.sh/) already installed:

```sh
brew install --cask gesangtajie/tap/hovercapture
```

This uses our [own tap](https://github.com/GESANGTAJIE/homebrew-tap), not the official Homebrew Cask repository. It downloads the versioned universal release and verifies its SHA-256. It does not bypass Gatekeeper or grant Screen Recording. If you already installed the app manually, quit it and move the old app out of Applications before installing with Homebrew; do not delete your screenshots or preferences.

### DMG or ZIP

Release packages are distributed through the repository's [Releases page](https://github.com/GESANGTAJIE/HoverCapture/releases). If a packaged release is not available, see [Build from source](#build-from-source).

1. Download the universal `.dmg` file and open it.
2. Drag **HoverCapture.app** into **Applications**.
3. Eject the disk image and launch HoverCapture from Applications.
4. Find the capture icon in the menu bar. HoverCapture does not keep a Dock icon.

The `.zip` package is an alternative: unzip it and move the app into Applications before opening it.

### Current signing status

This preview is **ad-hoc signed, without a Developer ID certificate or Apple notarization**, including the Homebrew download. A downloaded copy may be blocked by Gatekeeper.

After checking that your download comes from this repository and deciding to trust it, try opening the app once, then use **System Settings → Privacy & Security → Open Anyway** for HoverCapture. Managed Macs may restrict this option. Do not disable Gatekeeper or remove quarantine from unrelated files. [Apple's explanation](https://support.apple.com/en-us/102445)

### First-run permission

1. Open HoverCapture's settings and use its screen recording permission controls.
2. In **System Settings → Privacy & Security → Screen Recording** (called **Screen & System Audio Recording** on some versions), enable HoverCapture's screen access.
3. Quit and reopen HoverCapture if macOS requests it, or if the permission status has not refreshed.

The system's permission category includes audio in its name on some versions; HoverCapture captures still images and does not record audio. macOS may also ask for access when saving into a protected folder such as Downloads or Documents. [Apple's permission guide](https://support.apple.com/guide/mac-help/control-access-screen-system-audio-recording-mchld6aa7d23/mac)

## Use

1. Move the pointer onto a visible part of the window you want.
2. Press **⌃⌥⌘S** once.
3. Paste the image with **⌘V**, or open the PNG in your screenshot folder.

A successful capture briefly changes the menu bar icon to a checkmark. Files are named with `Window-` or `Screen-`, a timestamp, and a short unique suffix; existing files are not intentionally overwritten.

The pointer's position matters; the keyboard-focused window does not have to be the target. Leave the pointer on empty desktop to capture that entire display instead. A display capture includes the other visible windows, desktop, Dock, and menu bar on that display.

Open **Settings** from the menu bar icon. Under **Save location**, use **Choose Folder…** to select a destination such as `Documents/WindowShots`; **Open Screenshots** opens the current destination in Finder. Use the **Capture shortcut** control to change the shortcut. You do not need to edit code. Enable **Launch HoverCapture at login** if you want it to be available after signing in.

Choose a shortcut that does not conflict with another app or a macOS shortcut. If a shortcut cannot be registered, HoverCapture reports the problem; choose another combination.

To change it, click the current shortcut and press a new key combination containing Control, Option, or Command. Press Escape to cancel.

If you previously installed the Hammerspoon configuration, disable its old binding or choose a different shortcut before running both tools.

### Capture several images for one paste

Set **Capture batch** to a number from **1 to 20**. Each new screenshot is saved as a PNG and added to the group; the oldest is removed from the group when it exceeds the limit. For example, with a capacity of 3, capturing A, B, C, then D leaves B, C, D ready to paste, in that order. The saved A file remains on disk.

The current group is copied automatically after each capture. **Copy Batch** copies it again, **Copy Latest Only** copies just the newest image, and **Clear** starts an empty group. Pasting does not consume the group. Lowering the capacity drops its oldest entries. A settings change or Clear will not overwrite new clipboard content copied in another app.

HoverCapture supplies each item as PNG data and, when saving succeeded, a file reference. An app that supports multi-image or multi-file paste can accept the group with **⌘V**; another app may accept only its first image or treat the group as file attachments. On the test Mac, the user confirmed all three numbered sample images appeared in order after one paste in ChatGPT and WeChat. This does not establish compatibility with every version. If needed, use **Copy Latest Only**, or select the saved PNGs in the destination app's attachment picker.

The capacity is remembered after restart. The group itself stays in memory and resets when HoverCapture quits; saved PNGs are never deleted by clearing or resizing it. The system clipboard may retain the last copied images after the app exits.

### Choose the interface language

In **Interface language**, choose **Follow System**, **简体中文**, or **English**. Changes apply immediately to HoverCapture without restarting and are remembered for the next launch. Follow System uses Chinese when the primary system language is Chinese, otherwise English; macOS-owned dialogs follow macOS language settings.

## Exactly what gets captured

| Situation | Result or limitation |
| --- | --- |
| Ordinary app window | The window itself, without surrounding desktop, other windows, or its outer shadow. |
| Overlapping windows | The frontmost supported window at the pointer is selected. Point at an exposed part of a lower window to select it. ScreenCaptureKit can capture its available window content without compositing an overlapping window over it. |
| Completely covered window | Cannot be selected by hovering; expose some of it first. |
| Floating panel or independent dialog | May be captured separately if macOS exposes it as a supported window. |
| Attached child window or sheet | The parent capture does not intentionally include separate child windows. A child can only be captured separately if it is exposed as a supported candidate. |
| Popup drawn inside a webpage or app's own window | It is part of that window's pixels and appears in the screenshot. |
| Desktop, Dock, menus, and unsupported system overlays | Falls back to the display under the pointer. This includes everything currently visible on that display. |
| HoverCapture's own settings window | Falls back to the display under the pointer. Move the pointer to another app to capture that app's window. |
| Multiple displays | Fallback captures one display, not a stitched image of all displays. A window capture targets the selected window. |
| Transparent windows and rounded corners | May produce transparent pixels. Hit testing uses rectangular window bounds, not the transparency of each pixel. |
| Minimized, hidden, or other-Space windows | Not available for selection by hover. Switch to the relevant Space or restore the window first. |
| Full-screen app | Can be a target if macOS exposes it in the current Space. System overlays and secure surfaces may affect selection or capture. |
| DRM video, password/security UI, and protected content | May be blank, unavailable, or fail to capture. HoverCapture does not bypass macOS or app protections. |

Window identities, geometry, and pixels are supplied by macOS. Unusual apps and overlays do not always behave like ordinary windows. The target is selected when the shortcut is handled; moving the pointer afterward does not change it. A window that closes or becomes unavailable during capture produces an error instead of silently switching to a full-display capture. Try again after it settles.

## Privacy and files

HoverCapture does not upload screenshots, contact a server, collect analytics, or require an account. It uses Apple's ScreenCaptureKit to obtain a still image, writes PNG data to the chosen folder, and keeps up to the configured number of captures in memory for copying to the system clipboard.

Capturing or using a Copy control replaces the previous clipboard content with an image or group. Clipboard items include PNG data and, for saved captures, references to their local files. Other software that reads the clipboard can access this content, and system features such as Universal Clipboard may share it according to your macOS settings. A cloud-synced destination folder can also sync screenshots through its own service; HoverCapture does not control that service.

Settings are stored in macOS preferences under the application identifier `com.gesangtajie.HoverCapture`. Screenshot files remain in the folder you select. Uninstalling the app does not delete them.

## Troubleshooting

| Symptom | What to check |
| --- | --- |
| No Dock icon | Expected: use the menu bar icon. |
| Shortcut does nothing | Confirm HoverCapture is running, check its configured shortcut, and remove conflicting bindings in other apps. |
| Permission error or missing windows | Enable Screen Recording for the installed copy, then quit and reopen it. If the system toggle is already on but the app says **Permission needed**, follow the recovery steps below. |
| Capture works, saving fails | Choose a writable folder and check disk space and folder permission. A copied image can still be pasted when the app reports that only saving failed. |
| File saved, clipboard failed | Open the saved PNG. The app reports partial failure instead of treating the whole operation as successful. |
| Wrong capture area | Check the pointer position and the table above. Dock, menu, or unsupported overlay fallback deliberately captures the whole pointer display. |
| Pasting produces nothing | Paste into an app that accepts images; plain-text fields do not. Check whether another app replaced the clipboard. |
| Only one image pastes from a batch | The receiving app may only read the first clipboard item. Use **Copy Latest Only** for a single image, or attach the saved PNGs through that app's file picker. |
| Black or incomplete content | Check permission, try an ordinary window, and consider protected-content restrictions. |
| Launch at login needs approval | Check the login items controls in System Settings. Install in Applications before enabling it. |

### System permission is on, but the app says “Permission needed”

This mismatch was reproduced with an older ad-hoc signed permission entry on macOS 15.7.2. During 0.1.0 testing, the following app-specific recovery restored the **Allowed** status:

1. Open **System Settings → Privacy & Security → Screen Recording** or **Screen & System Audio Recording**.
2. Select **HoverCapture** and use the minus/remove button to remove its old entry. Leave other apps' permissions unchanged.
3. Use the plus/add button and select the **exact HoverCapture.app you intend to run**—normally the copy in Applications. If testing a local build, select that build instead of an older installed or downloaded copy.
4. Enable HoverCapture's screen access, then choose **Quit & Reopen** when prompted. Otherwise, quit that app completely and reopen the same copy.
5. Open HoverCapture settings and confirm that Screen Recording now says **Allowed**.

This only refreshes HoverCapture's own permission entry. It does not require disabling system protections or resetting other apps' permissions. A status of **Allowed** confirms this recovery step; verify actual capture separately with the physical shortcut and an image paste.

Report reproducible problems through [GitHub Issues](https://github.com/GESANGTAJIE/HoverCapture/issues). Include your macOS version, Mac architecture, app version, display arrangement, target app, and the exact error. Remove private content from any screenshot before sharing it.

## Update and uninstall

**Update:** quit HoverCapture from its menu (closing Settings is not quitting). For a manual installation, replace the app in Applications and reopen that same copy. For Homebrew:

```sh
brew update
brew upgrade --cask gesangtajie/tap/hovercapture
```

Existing preferences and saved screenshots remain. Test one capture after updating. If Screen Recording still works, do not remove its grant. If the system switch is enabled but the app says Permission needed, remove only HoverCapture's old entry in Privacy & Security, add the exact newly installed app, and choose Quit & Reopen. A complete uninstall or deletion of settings/screenshots is unnecessary. Ad-hoc builds may need this after updates; Homebrew does not change that limitation. Recheck Launch at login as well.

**Uninstall:** turn off Launch at login, quit HoverCapture, and move the app from Applications to the Trash. Remove its Screen Recording entry in System Settings if desired. Saved screenshots and preferences are retained unless you remove them separately.

For a Homebrew installation, quit the app and use `brew uninstall --cask hovercapture` instead of moving it manually. This tap deliberately provides no destructive cleanup of screenshots/preferences or automatic permission resets.

## Build from source

You need a Mac, Apple's Xcode Command Line Tools with a compatible Swift compiler, and a macOS SDK that includes the macOS 14.2 ScreenCaptureKit APIs. No third-party packages are needed.

From a checkout of this repository:

```sh
./scripts/test.sh
./scripts/package.sh
```

The package script always builds the current source first. The app is built at `build/HoverCapture.app`; for a build without packaging, use `./scripts/build.sh`. The package script produces:

```text
dist/HoverCapture-0.2.2-universal.dmg
dist/HoverCapture-0.2.2-universal.zip
dist/SHA256SUMS.txt
```

In a restricted environment where creating a disk image is unavailable, package the app as a ZIP instead:

```sh
./scripts/package.sh --zip-only
```

This creates the universal `.zip` and its `SHA256SUMS.txt` without attempting to create a DMG. Users can unzip it and move the app into Applications using the same installation steps above.

The build script creates a universal app bundle and applies an ad-hoc signature. This is not Developer ID signing or notarization. Do not describe an ad-hoc build as notarized when redistributing it.

The app uses native AppKit for its menu and settings, ScreenCaptureKit for screenshots, the system global-hotkey API for the shortcut, and ServiceManagement for optional launch at login. Selection logic is tested separately from screen recording so that its cases can run without granting capture permission.

### Source layout

| Path | Responsibility |
| --- | --- |
| `Sources/main.swift` | Native application entry point. |
| `Sources/AppDelegate.swift` | Menu bar, settings, permissions, and app lifecycle. |
| `Sources/AppTheme.swift` | Brand colors, typography, and bundled interface icons. |
| `Sources/AppLanguage.swift` | Persisted interface-language choice. |
| `Sources/HotKeyController.swift` | Global shortcut registration and cleanup. |
| `Sources/CaptureSelection.swift` | Window hit testing and display fallback. |
| `Sources/CaptureEngine.swift` | ScreenCaptureKit capture and PNG saving. |
| `Sources/CaptureBatch.swift` | Bounded capture group and ordered clipboard output. |
| `Tests/SelectionTests.swift` | Selection tests that do not capture the screen. |
| `Tests/BatchTests.swift`, `Tests/LanguageTests.swift` | Batch behavior, clipboard output, and language preferences. |
| `scripts/` | Local test, build, and packaging commands. |

For an additional startup check, run `build/HoverCapture.app/Contents/MacOS/HoverCapture --smoke-test`. This checks application/menu/shortcut startup; it does not take a screenshot or verify capture permission.

See [the testing guide](docs/TESTING.md) for automated checks and the manual release checklist. Passing selection tests or compiling successfully does not prove that real screen capture, permissions, or every display layout work on a given Mac.

## Co-authors

- **ChesterGe** — product direction, visual design, and project maintenance. GitHub: [GESANGTAJIE](https://github.com/GESANGTAJIE).
- **GPT (OpenAI)** — AI co-author, contributing to implementation and documentation.

## Contributing and license

Bug reports and focused pull requests are welcome. See [CONTRIBUTING.md](CONTRIBUTING.md).

HoverCapture is released under the [MIT License](LICENSE).

Interface icons come from [Lucide](https://lucide.dev/icons/), with its ISC and inherited Feather MIT notices preserved in the [icon license](https://github.com/GESANGTAJIE/HoverCapture/blob/main/Resources/Icons/LICENSE) and distributed app resources.

## Apple API references

- [ScreenCaptureKit](https://developer.apple.com/documentation/screencapturekit)
- [SCScreenshotManager](https://developer.apple.com/documentation/screencapturekit/scscreenshotmanager)
- [SMAppService](https://developer.apple.com/documentation/servicemanagement/smappservice)
