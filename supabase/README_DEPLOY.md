Deploying Supabase Edge Functions and running migrations

Prereqs:
- Install `supabase` CLI: https://supabase.com/docs/guides/cli
- Authenticate: `supabase login`

1) Run DB migration (apply SQL):

You can run the SQL file directly from Supabase SQL editor or use the CLI:

```bash
# From project root
supabase db remote set <YOUR_DB_CONN_STRING>
supabase db push --file supabase/migrations/001_create_password_resets.sql
```

Or open the SQL file and paste into the SQL editor in the Supabase dashboard and run it.

2) Deploy Edge Functions:

```bash
# build & deploy
supabase functions deploy send-reset --project-ref fhsqvuyzoptmkpapxyfl
supabase functions deploy complete-reset --project-ref fhsqvuyzoptmkpapxyfl
```

3) Set required secrets (service role key + email provider key + frontend url):

```bash
supabase secrets set SUPABASE_SERVICE_ROLE_KEY="<SERVICE_ROLE_KEY>" --project-ref fhsqvuyzoptmkpapxyfl
supabase secrets set SENDGRID_API_KEY="<SENDGRID_API_KEY>" --project-ref fhsqvuyzoptmkpapxyfl
supabase secrets set FROM_EMAIL="no-reply@yourdomain.com" --project-ref fhsqvuyzoptmkpapxyfl
supabase secrets set FRONTEND_RESET_URL="https://your-firebase-site.web.app" --project-ref fhsqvuyzoptmkpapxyfl
```

4) Test the functions locally (optional):

```bash
# Start functions emulator
supabase start
# Invoke function locally
supabase functions invoke send-reset --project-ref fhsqvuyzoptmkpapxyfl --payload '{"email":"you@example.com"}'
```

Notes:
- Keep `SUPABASE_SERVICE_ROLE_KEY` secret. Do not commit it to git.
- Adjust `project-ref` to your Supabase project id if different.
- If you use a different email provider replace `SENDGRID_API_KEY` with appropriate env keys.
