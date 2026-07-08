# Arcane Panel Restyle — Design Spec

**Date:** 2026-07-08 · **Status:** Approved (user pre-approved implementation and delegated execution)

Restyle the floating panel to match the marketing site (`marketing-site/css/style.css`)
and the user's reference screenshot. Panel only; always dark; Settings stays native.
No logic changes — `GenieSession`, engine, clipboard, hotkey untouched; all 25 tests stay green.

## Palette (from style.css, verbatim)

bg `#130E26` (~94% opacity over blur), bg-deep `#0A0716`, ink `#F2EEFC`, ink-dim `#B6AED0`,
ink-faint `#7E74A3`, violet `#A78BFA`, violet-glow `#7C5CFF`, gold `#FFD57A`,
border `violet @ 0.18`, border-bright `violet @ 0.38`, radius `18`.

## Layout

1. **Header** — 🪄 + "Clipboard Mage" (semibold, ink @ 0.85); right-aligned capsule status
   pill: gold `STREAMING…` (tracking 1.5) while streaming, violet `↩ TO ACCEPT` when a
   result is ready, hidden otherwise. Replaces the old bottom hint bar.
2. **Preview** — monospaced 13pt, ink on the dark fill with a subtle centered violet
   radial glow; empty state in ink-faint; streaming indicator "The mage is casting…" in gold.
3. **Input row** — gold `sparkle` icon; plain TextField (rounded 15pt, ink, violet caret,
   ink-faint prompt); right side: bordered `↩` button (submits) when idle, gold-outlined
   capsule `Stop` while streaming.
4. **Error bar** — bg-deep glass, gold warning icon, violet "Open Settings" text button;
   same `contains("Settings")` trigger as before.
5. **Always dark** — `.preferredColorScheme(.dark)` on the view and
   `NSAppearance(named: .darkAqua)` on the panel.

## Files

- New `ClipboardGenie/Views/MageTheme.swift` (palette constants only)
- Rewrite `ClipboardGenie/Views/GenieView.swift` (visual only; same session API usage,
  including the `.onChange(of: isStreaming)` refocus)
- `ClipboardGenie/PanelController.swift`: pin `appearance = NSAppearance(named: .darkAqua)`

## Out of scope

Settings restyle, light variant, animations/particles, app icon.
