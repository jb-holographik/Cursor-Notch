# Cursor Notch

A tiny native macOS menu bar utility. When a Cursor Agent is working, it shows Cursor’s own 3×3 animated dots on the MacBook notch. When the Agent finishes, the island morphs into:

```
✓ Cursor
Task finished
```

No network, no account, no telemetry. Agent state stays on the machine.

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

The overlay is a non-activating `NSPanel`. It does not modify Apple’s Dynamic Island.

- If a display reports a hardware notch (`safeAreaInsets.top > 20`), the island is centered on that display, tucked under the notch.
- If no notched display exists (clamshell, Studio Display, VM), the island is centered on the top edge of the main screen.

Display sleep, wake, and configuration changes re-layout the panel. The overlay prefers the built-in notched screen when an external monitor is connected.

## States

1. **Idle** — nothing on the notch.
2. **Working** — 3×3 circular dots (Cursor’s session-bar dot-matrix). Stays up for the whole task. Disable this in Settings if you only want completion.
3. **Completed** — checkmark + “Cursor” / “Task finished” for ~3 seconds, then fade out.

A new task during completion returns immediately to WORKING. Completion waits until every tracked conversation has stopped. Quitting Cursor clears the overlay. Clicking the island activates Cursor.

The working animation is a 3×3 grid of circular dots with a diagonal opacity/scale wave (cycle ≈ 1.05s). That matches Cursor’s documented “dot-matrix” Agent indicator next to the conversation name, not a spinner or progress bar.

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
