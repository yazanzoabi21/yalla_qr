Hosting and deploy instructions for the reset page

1) Install Firebase CLI (if not already):

```bash
npm install -g firebase-tools
```

2) Login and init (one-time):

```bash
firebase login
cd hosting
firebase init hosting
# When prompted, choose an existing project or create new.
# Set public directory to `public` and do NOT configure as SPA (we already have rewrites)
```

3) Before deploying, edit `hosting/public/reset_password.html` and set `SUPABASE_ANON_KEY` to your project's anon key.

4) Deploy:

```bash
cd hosting
firebase deploy --only hosting
```

5) After deploy, set `FRONTEND_RESET_URL` (used by your `send-reset` Edge Function) to the deployed URL, for example `https://your-firebase-site.web.app`.

Alternative: You can host `hosting/public` on any static host (GitHub Pages, Vercel, Netlify). Ensure the reset page is served over HTTPS and that `FRONTEND_RESET_URL` points to it.
