# Clipboard Mage — Marketing Site

Static site, zero dependencies, no build step. Host the folder anywhere
(GitHub Pages, Netlify, S3, a potato).

## Preview locally

```bash
python3 -m http.server 8000
# → http://localhost:8000
```

## Wiring up the DMG download

There are two download links, both marked with `TODO` comments in `index.html`:

1. **Hero button** — `<a class="btn btn-primary" href="#download">` currently
   scrolls to the download section; point it at the DMG directly if you prefer.
2. **Main download button** — `<a ... id="dmg-link" href="#">`. Replace `href="#"`
   with the real DMG URL (e.g. the GitHub release asset). While the href is `#`,
   clicking it shows a friendly "coming soon" message instead of a dead link.

## Structure

```
index.html    — all content & copy
css/style.css — theme (night sky / violet / gold), fully responsive
js/main.js    — hero demo animation, star field, download placeholder
```

The hero demo scenarios (clipboard text → spell → streamed result) live at the
top of `js/main.js` — edit the `scenarios` array to change them.

© 2026 Wandering Ghost LLC — wanderingghost.us
