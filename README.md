# Cursor Notch

A tiny native macOS menu bar utility that turns the MacBook notch into a Cursor Agent status indicator.

- The left wing shows the official Cursor app icon.
- The right wing shows Cursor's exact `sine_3x3` animation while an Agent is working.
- The animation becomes a green checkmark when the task completes.

No network, no account, no telemetry. Agent state stays on the machine.

## Install

Download `Cursor-Notch.zip` from the [latest release](https://github.com/jb-holographik/Cursor-Notch/releases/latest), unzip it, and move `Cursor Notch.app` to Applications.

The release is ad-hoc signed rather than notarized. On first launch, right-click the app and choose **Open** if macOS blocks it.

## Requirements

- macOS 14+
- Xcode 16+ (Swift 6)
- Cursor (optional for the preview buttons; required for live Agent events)

## Build

Run these commands from **this repository’s root** — the folder that contains `Scripts/` and `CursorNotch.xcodeproj`. They will fail from your home directory (`~`).

```sh
cd /path/to/this/repo
ls Scripts/build.sh CursorNotch.xcodeproj
chmod +x Scripts/build.sh
./Scripts/build.sh
open dist/Cursor\ Notch.app
```

If you do not have the project on disk yet, clone it first, then `cd` into the clone.

Or open `CursorNotch.xcodeproj` in Xcode and run the **CursorNotch** scheme.

You need Xcode (or at least the developer command-line tools with the macOS SDK). The app is a menu bar extra (`LSUIElement`), so it has no Dock icon.

## How Agent state is detected

Cursor’s supported extension point is user-level **hooks** (`~/.cursor/hooks.json`). This is the same path used by Agents Notch / AgentNotch, AgentPulse, and similar notch apps. The app does **not** scrape the UI, take screenshots, or poll Cursor’s process.

On first launch Cursor Notch:

1. Looks for Cursor (`com.todesktop.230313mzl4w4u92`, `com.anysphere.cursor`, or `Cursor.app`).
2. Copies `cursor-notch-hook.py` to `~/Library/Application Support/CursorNotch/`.
3. Merges observer-only entries into `~/.cursor/hooks.json` without removing other hooks.

Hook events:

| Cursor hook | Notch |
| --- | --- |
| `beforeSubmitPrompt` | WORKING |
| `preToolUse` / `postToolUse` / `postToolUseFailure` | stay WORKING |
| `stop` / `sessionEnd` | COMPLETED after a 700ms debounce |

`stop` can fire between model turns. The debounce waits for the next prompt or tool event so an in-progress Agent is not marked finished too early. `loop_limit` is set to `null` so Cursor does not disable the stop hook after five turns.

The hook script reads JSON on stdin, writes one line to a local Unix socket, prints `{}`, and exits 0 even if Cursor Notch is not running.

No extra macOS permission is required. Restart Cursor once if a session that was already running does not notify.

## Notch placement

The overlay is a non-activating `NSPanel`. It does not modify the physical notch.

- On a notched display, one pure-black surface spans the physical camera housing and two compact wings. It sits flush with the top edge and uses the screen's reported auxiliary areas to match the real notch width.
- Without a hardware notch (clamshell, Studio Display, VM), the same status becomes a compact rounded island at the top center of the main screen.

Display sleep, wake, and configuration changes re-layout the panel. The overlay prefers the built-in notched screen when an external monitor is connected.

## States

1. **Idle** — nothing on the notch.
2. **Working** — Cursor icon on the left, animated dots on the right. Stays up for the whole task. Disable this in Settings if you only want completion.
3. **Completed** — Cursor icon on the left, green checkmark on the right for ~3 seconds, then fade out.

A new task during completion returns immediately to WORKING. Completion waits until every tracked conversation has stopped. Quitting Cursor clears the overlay. Clicking the island activates Cursor.

The working indicator reproduces Cursor's bundled `DotGridLoader` with the `sine_3x3` preset: eight discrete frames at 175ms each, for a 1.4-second loop.

## Menu

- Cursor Notch
- ✓ Cursor detected / ⚠ Cursor not detected
- Test working animation (runs until you choose Stop working animation)
- Test completion notification
- Settings
- Quit

Settings: launch at login (`SMAppService`), notification duration, sound, working indicator on/off.

## Privacy

Events contain only hook name, conversation id, generation id, and status. Task text is not forwarded. Nothing leaves the Mac.
