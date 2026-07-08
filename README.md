# Clipboard Mage 🧙

A macOS menu bar app. Hit a hotkey (default **⌃⌥⌘C**), see your clipboard in a
pretty floating panel, tell the mage how to transform it ("clean this up into
markdown"), watch the result stream in, press **Enter** to accept it into your
clipboard — or keep iterating with more instructions.

## Features
- Global hotkey summons a Spotlight-style panel with your current clipboard text
- Transformations powered by Claude (Anthropic API, Sonnet) with live streaming
- Iterate: each new instruction transforms the current result
- Optional "auto-appear on copy" mode
- API key stored in the macOS Keychain
- Auto-updates via Sparkle

## Setup
1. Download the latest DMG from Releases and drag to Applications.
2. Open Settings from the menu bar icon and paste your Anthropic API key
   (get one at https://platform.claude.com).
3. Copy some text, press ⌃⌥⌘C, and make a wish.

## Development
```sh
brew install xcodegen
xcodegen generate
open ClipboardGenie.xcodeproj
```

Releases: see `.agents/commands/EXPORT-SIGNED-APP.md`.
