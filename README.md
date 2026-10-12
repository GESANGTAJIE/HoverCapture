# HoverCapture

[简体中文](README.zh-CN.md) · English

Point at a Mac window. Press one shortcut. Get a screenshot of that window, saved as a PNG and ready to paste.

HoverCapture is a small native macOS menu bar app. It does not need Hammerspoon, a browser extension, or a background command-line service.

## 0.1.0 preview status

This is an early preview. Checks confirmed through **2026-10-12** on **macOS 15.7.2, Apple Silicon**:

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
- Uses **Control–Option–Command–S** (`⌃⌥⌘S`) by default, with a customizable global shortcut.
- Excludes window shadows, the pointer, and separately attached child windows from a window capture.
- Offers optional launch at login and an interface that follows the system language: Chinese or English.
- Processes screenshots locally, with no accounts, analytics, or image uploads.

## Requirements

- **macOS 14.2 or newer.**
- Apple Silicon or Intel Mac. The universal build contains both `arm64` and `x86_64` binaries; availability of both architectures is not a claim that every Mac configuration has been tested.
- Screen Recording permission for HoverCapture.

No additional runtime dependencies are required. Accessibility, Input Monitoring, microphone, and camera permission are not required for the app's screenshot workflow.

## Install

Release packages are distributed through the repository's [Releases page](https://github.com/GESANGTAJIE/HoverCapture/releases). If a packaged release is not available, see [Build from source](#build-from-source).

1. Download the universal `.dmg` file and open it.
2. Drag **HoverCapture.app** into **Applications**.
3. Eject the disk image and launch HoverCapture from Applications.
4. Find the capture icon in the menu bar. HoverCapture does not keep a Dock icon.

The `.zip` package is an alternative: unzip it and move the app into Applications before opening it.

### Current signing status

The initial build is **ad-hoc signed, without a Developer ID certificate or Apple notarization**. A downloaded copy may be blocked by Gatekeeper.

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

Open **Settings** from the menu bar icon. Under **Save location**, use **Choose…** to select a destination such as `Documents/WindowShots`; **Open Folder** opens the current destination in Finder. Use the **Keyboard shortcut** control to change the shortcut. You do not need to edit code. Enable **Launch at login** if you want HoverCapture to be available after signing in.

Choose a shortcut that does not conflict with another app or a macOS shortcut. If a shortcut cannot be registered, HoverCapture reports the problem; choose another combination.

To change it, click the current shortcut and press a new key combination containing Control, Option, or Command. Press Escape to cancel.

If you previously installed the Hammerspoon configuration, disable its old binding or choose a different shortcut before running both tools.

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

HoverCapture does not upload screenshots, contact a server, collect analytics, or require an account. It uses Apple's ScreenCaptureKit to obtain a still image, writes PNG data to the chosen folder, and writes the image to the system clipboard.

Clipboard content replaces the previous clipboard item. Other software that reads the clipboard can access it, and system features such as Universal Clipboard may share it according to your macOS settings. A cloud-synced destination folder can also sync screenshots through its own service; HoverCapture does not control that service.

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
| Black or incomplete content | Check permission, try an ordinary window, and consider protected-content restrictions. |
| Launch at login needs approval | Check the login items controls in System Settings. Install in Applications before enabling it. |

### System permission is on, but the app says “Permission needed”

This mismatch was reproduced with an older ad-hoc signed permission entry on macOS 15.7.2. For the current build, the following app-specific recovery restored the **Allowed** status:

1. Open **System Settings → Privacy & Security → Screen Recording** or **Screen & System Audio Recording**.
2. Select **HoverCapture** and use the minus/remove button to remove its old entry. Leave other apps' permissions unchanged.
3. Use the plus/add button and select the **exact HoverCapture.app you intend to run**—normally the copy in Applications. If testing a local build, select that build instead of an older installed or downloaded copy.
4. Enable HoverCapture's screen access, then choose **Quit & Reopen** when prompted. Otherwise, quit that app completely and reopen the same copy.
5. Open HoverCapture settings and confirm that Screen Recording now says **Allowed**.

This only refreshes HoverCapture's own permission entry. It does not require disabling system protections or resetting other apps' permissions. A status of **Allowed** confirms this recovery step; verify actual capture separately with the physical shortcut and an image paste.

Report reproducible problems through [GitHub Issues](https://github.com/GESANGTAJIE/HoverCapture/issues). Include your macOS version, Mac architecture, app version, display arrangement, target app, and the exact error. Remove private content from any screenshot before sharing it.

## Update and uninstall

**Update:** quit HoverCapture from its menu, replace the app in Applications, and reopen it. Existing preferences and screenshots remain. Recheck Screen Recording and Launch at login after replacing an ad-hoc signed build.

**Uninstall:** turn off Launch at login, quit HoverCapture, and move the app from Applications to the Trash. Remove its Screen Recording entry in System Settings if desired. Saved screenshots and preferences are retained unless you remove them separately.

## Build from source

You need a Mac, Apple's Xcode Command Line Tools with a compatible Swift compiler, and a macOS SDK that includes the macOS 14.2 ScreenCaptureKit APIs. No third-party packages are needed.

From a checkout of this repository:

```sh
./scripts/test.sh
./scripts/build.sh
./scripts/package.sh
```

The app is built at `build/HoverCapture.app`. The package script produces:

```text
dist/HoverCapture-0.1.0-universal.dmg
dist/HoverCapture-0.1.0-universal.zip
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
| `Sources/HotKeyController.swift` | Global shortcut registration and cleanup. |
| `Sources/CaptureSelection.swift` | Window hit testing and display fallback. |
| `Sources/CaptureEngine.swift` | ScreenCaptureKit capture, PNG saving, and clipboard output. |
| `Tests/SelectionTests.swift` | Selection tests that do not capture the screen. |
| `scripts/` | Local test, build, and packaging commands. |

For an additional startup check, run `build/HoverCapture.app/Contents/MacOS/HoverCapture --smoke-test`. This checks application/menu/shortcut startup; it does not take a screenshot or verify capture permission.

See [the testing guide](docs/TESTING.md) for automated checks and the manual release checklist. Passing selection tests or compiling successfully does not prove that real screen capture, permissions, or every display layout work on a given Mac.

## Contributing and license

Bug reports and focused pull requests are welcome. See [CONTRIBUTING.md](CONTRIBUTING.md).

HoverCapture is released under the [MIT License](LICENSE).

## Apple API references

- [ScreenCaptureKit](https://developer.apple.com/documentation/screencapturekit)
- [SCScreenshotManager](https://developer.apple.com/documentation/screencapturekit/scscreenshotmanager)
- [SMAppService](https://developer.apple.com/documentation/servicemanagement/smappservice)
