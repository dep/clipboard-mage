# Clipboard Genie — Design Spec

**Date:** 2026-07-08
**Status:** Approved for planning

## Overview

Clipboard Genie is a macOS menu bar app. A global hotkey (or, optionally, any copy)
opens a pretty centered floating panel showing the current clipboard text. The user
types a transformation instruction (e.g. "clean up and format this text into
markdown"), presses Enter, and the result streams live into the preview pane via the
Anthropic API (Sonnet). Enter on an empty instruction accepts the result into the
clipboard and closes the panel; typing another instruction re-transforms the current
preview. Iteration continues until accept (Enter) or dismiss (Esc).

## Decisions Made

- **Name:** Clipboard Genie (repo directory remains `magic-clipboard`)
- **Stack:** Native Swift 5.9+ / SwiftUI, macOS 14.0 minimum
- **Project system:** XcodeGen (`project.yml`) + `xcodebuild`, ad-hoc signing for
  local dev — mirrors the Synapse Meetings setup
- **Distribution:** Developer ID signed + notarized DMG, shared with friends
- **Updates:** Sparkle 2 from day one (appcast.xml on main, EdDSA-signed DMGs on
  GitHub releases), same flow as Synapse Meetings' `EXPORT-SIGNED-APP.md`
- **AI response:** SSE streaming — tokens render into the preview pane live
- **Auto-appear on copy:** full modal with keyboard focus on every text copy
  (user-toggleable in Settings, default off)
- **Panel tech:** borderless floating `NSPanel` hosting SwiftUI (Spotlight-style)
- **Hotkey:** `KeyboardShortcuts` (sindresorhus, SPM) — global hotkey +
  shortcut-recorder settings UI. Default shortcut: ⌃⌥⌘C
- **API key storage:** macOS Keychain only — never UserDefaults or plaintext
- **Model:** latest Claude Sonnet via the Anthropic Messages API (verify exact
  model id against current API docs at implementation time)

## Architecture

Five small units, each independently understandable and testable:

### 1. App shell (`ClipboardGenieApp`)
- `MenuBarExtra` with a genie/wand template icon
- Menu items: Open Genie, Settings…, Check for Updates… (Sparkle), Quit
- `LSUIElement = true` (no Dock icon)
- Owns wiring: hotkey → panel, clipboard watcher → panel, Sparkle updater

### 2. GeniePanel (`PanelController` + `GenieView`)
- Borderless, floating, centered `NSPanel` (`.nonactivatingPanel` styled like
  Spotlight): appears over full-screen apps, takes keyboard focus, dismisses on
  Esc or click-outside
- Layout, top to bottom:
  - **Preview pane** — scrollable text view showing clipboard text, then the
    streamed result (replacing the preview content as tokens arrive)
  - **Instruction textarea** — auto-focused on open; placeholder like
    "How should I transform this?"
- Native material blur background, rounded corners, subtle shadow
- State machine: `idle → streaming → result` (re-enterable), plus
  `noApiKey`, `emptyClipboard`, and `error` presentation states

### 3. ClipboardService
- Reads current clipboard text (`NSPasteboard.general`) when the panel opens
- Watches `changeCount` on a ~0.5s timer when auto-appear is enabled;
  triggers panel open on new *text* content
- Suppresses self-triggering: remembers the changeCount produced by its own
  write-on-accept and ignores it
- Writes accepted text to the clipboard

### 4. GenieEngine
- Anthropic Messages API client using `URLSession` with SSE streaming
  (`stream: true`), no third-party SDK
- System prompt: transform-only contract — "Return ONLY the transformed text,
  no commentary, no preamble."
- Per panel-session conversation: first request = clipboard text + instruction;
  subsequent instructions transform the **current preview text** (iteration:
  "make it markdown" → "now shorter"). Conversation resets each panel open.
- Emits an `AsyncSequence` of text deltas for the view to render
- Errors surface as typed cases: missing key, HTTP/auth failure, network,
  malformed stream

### 5. Settings (`SettingsView`)
- Standard SwiftUI `Settings` scene, three controls:
  - Shortcut recorder (`KeyboardShortcuts.Recorder`)
  - Anthropic API key field (writes to Keychain; shows masked value when set)
  - "Auto-appear on copy" toggle (UserDefaults)

## Interaction Flow

1. Hotkey pressed (or text copied while auto-appear on) → panel opens centered,
   clipboard text in preview, cursor in textarea
2. Type instruction, press **Enter** → request streams; result replaces preview;
   textarea clears. **Shift+Enter** inserts a newline in the instruction.
3. **Enter with empty textarea** while a result is showing → accept: result is
   written to clipboard, panel closes, brief "✓ Copied" confirmation
4. Typing another instruction and pressing Enter re-transforms the current
   preview (unlimited iterations)
5. **Esc** (or click outside) → panel closes, clipboard untouched
6. Pressing Enter with an empty textarea when *no* result exists yet does nothing

## Error Handling

- **No API key:** preview pane shows a friendly call-to-action with an
  "Open Settings" button; instruction submission disabled
- **API/network error:** error message renders inline in the preview area;
  original clipboard text is preserved and restorable (a failed transform never
  loses the source text)
- **Empty or non-text clipboard:** "nothing to transform" empty state
- **Stream interrupted mid-response:** partial text discarded, error shown,
  previous preview text restored

## Testing

- **Unit tests:** GenieEngine (request construction, SSE parsing via stubbed
  `URLProtocol`, error mapping) and ClipboardService (changeCount detection,
  self-copy suppression)
- **Manual QA checklist:** hotkey open, auto-appear toggle, streaming render,
  accept-to-clipboard, iterate, Esc, Settings persistence, Keychain round-trip

## Release

Adapted clone of Synapse Meetings' `EXPORT-SIGNED-APP.md`: archive with Developer
ID overrides → export → codesign verify → notarize + staple → `create-dmg` →
Sparkle `sign_update` → appcast.xml on main → GitHub release. Credentials come
from the existing `.env` (`APPLE_EMAIL`, `APPLE_APP_PASSWORD`), team `299R8V27FZ`.

## Out of Scope (v1)

- Auto-paste into the frontmost app after accept
- Clipboard history
- Non-text clipboard content (images, files)
- Prompt presets / saved commands
- Model picker
