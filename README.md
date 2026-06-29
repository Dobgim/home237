# Home237 — Website

The marketing & landing website for **Home237**, the Cameroon property-rental platform.
Static, dependency-free (HTML + CSS + vanilla JS) — hosts anywhere, loads instantly.

## ✨ What's inside
- **Hero** with an animated app mockup, matching the app's blue/navy/green theme.
- **Modern role picker** — visitors choose **Tenant** or **Landlord** (interactive cards, remembers the choice).
- **"Mobile app coming soon"** section with a *Notify me* email capture and Play Store / App Store "coming soon" badges.
- **Features**, **How it works**, **Cities**, and a **footer** — all responsive, with scroll-reveal animations.

## 🚀 Run / preview locally
It's static — just open `index.html` in a browser. For a local server (recommended so paths behave like production):

```bash
# Python
python -m http.server 5500
# then visit http://localhost:5500
```

## 🌐 Deploy (host it today)
Any static host works — pick one:
- **GitHub Pages:** push this folder to a repo → Settings → Pages → deploy from `main` / root.
- **Netlify / Vercel:** drag-and-drop the folder, or connect the repo. No build command, publish directory = `/`.

## 📱 The actual app (bundled)
The real **Flutter web app** is bundled in [`/app/`](app/) next to this page — same code, sign-up,
sign-in and Tenant/Landlord roles as the mobile app. So **one deploy serves both**: the landing page at
`/` and the live app at `/app/`. The role cards send users to `app/?role=tenant|landlord`.

> Rebuilt with `flutter build web --release` from the Home237 project, copied to `app/`, with
> `<base href="./">` so it works at the `/app/` sub-path on any host.

## ⚙️ Configure
- **Role buttons:** `WEB_APP_URL` in `script.js` is set to `"app/"` (the bundled app). Point it at a
  different URL (e.g. `https://app.home237.com/`) if you ever host the app separately.
- **Notify-me emails:** currently stored in the visitor's `localStorage`. To collect them for real, set
  `NOTIFY_ENDPOINT` in `script.js` to a [Formspree](https://formspree.io) URL (or similar).

## 🎨 Theme
Colours mirror the app: blue `#3B82F6`, navy `#0A1628`, green `#10B981`, slate text.
All defined as CSS variables at the top of `styles.css` — change them in one place.

## 📁 Files
```
index.html    — page markup (all sections)
styles.css    — theme + layout + responsive + animations
script.js     — nav, role picker, notify form, scroll reveals
app/          — the bundled Flutter web app (the real product, served at /app/)
```
