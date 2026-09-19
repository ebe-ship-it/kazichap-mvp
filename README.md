# KaziChap — refined MVP, v0.2.0

A Tanzania-focused marketplace where customers post jobs or contact providers, providers apply for nearby work, and both participants coordinate through chat and a match page.

**Start here:** this is a Next.js application, not a single `index.html` file. Vercel hosts the app. Supabase provides accounts, PostgreSQL/PostGIS, row-level security and Realtime. Google Maps provides the map display.

**Verification status:** the included validation tests and source checks ran successfully. Dependency installation was blocked by an HTTP 403 from the npm registry in the editing environment. A Next.js production build, TypeScript check, live Supabase tests and browser tests of the running app could not be completed there. Follow the gates below before inviting users. This package does not claim a verified production deployment.

## What changed

- Added confirmation-email and PKCE callback routes, password reset, resend confirmation and safe local redirects.
- Added setup, loading, error and not-found pages. Missing credentials no longer need to crash the public landing page.
- Refined the black/red interface, mobile layouts, keyboard focus, form labels, reduced-motion behaviour and modal forms.
- Added refreshed dashboards, posted-job management, application status, cancellation before a match starts and clear empty/error states.
- Fixed fixed-price application defaults and added validation for Tanzania mobile numbers, rates and locations.
- Added hourly billing: provider proposes minutes, customer approves, then both confirm direct payment. The app now distinguishes a rate from a total.
- Added explicit opt-in live location, stop-sharing controls, stale-position hiding and removal on match closure.
- Hardened RPC authorization, professional-verification checks, application locking, duplicate inquiries and database privileges.
- Added a fresh-project bootstrap, an upgrade migration, setup diagnostics, validation tests and a database regression script.

## What is and is not connected

| Feature | Implementation |
| --- | --- |
| Customer/provider signup and login | Supabase email/password authentication |
| Nearby discovery | Saved coordinates, PostGIS distance queries, approximate distance results |
| Job posts and applications | Database-backed records and validated RPCs |
| Chat | Supabase messages, Realtime, polling recovery; latest 300 messages displayed |
| Match states | Requested → accepted → in progress → completed → paid; pre-start cancellation |
| Live map | Google Maps with opt-in coordinates while the match page is open |
| Hourly bill | Provider proposes minutes; customer approves time and amount |
| Payments | **Manual acknowledgement only. No funds are collected, transferred or held.** |
| Reviews | One customer review per paid match; aggregate worker rating |
| Doctor/Nurse verification | Administrator-controlled flag. No automated NIDA, OCR, liveness or register checks |
| Background tracking / push / SMS | Not implemented |
| Disputes, moderation and refunds | No management interface included |

Online availability is a provider-controlled setting, not a guarantee that their browser is open. Signing out sets providers offline, but closing a tab does not. A provider should switch offline when unavailable. Discovery and dashboard lists are capped at 50 nearby results / 100 jobs or matches / 200 applications in this MVP. Older data remains in the database.

## 1. Extract the project correctly on Windows

1. Download `KaziChap-Refined-MVP.zip`.
2. Right-click it → **Extract All** → choose a short folder such as `C:\Projects`.
3. Open the extracted `kazichap-mvp` folder. You must see `package.json`, `README.md`, `app`, `components`, `lib` and `supabase` together.
4. Do not run commands from inside the ZIP viewer.
5. Do not deploy the unrelated Windows shortcut from the original upload. It is excluded from this package.

The project root is the folder containing `package.json`. All commands below run from that folder unless a step explicitly says otherwise.

## 2. Install the tools

1. Install **Node.js 24 LTS** from [Node.js downloads](https://nodejs.org/en/download). Keep npm selected in the installer.
2. Install Git from [Git for Windows](https://git-scm.com/downloads/win). GitHub Desktop can be used instead, as described later.
3. Close old terminals and open a new **Command Prompt**.
4. Check:

```bat
node --version
npm --version
git --version
```

Node should start with `v24.`. This project specifies `24.x`, matching Vercel's supported Node runtime. [Vercel Node.js versions](https://vercel.com/docs/functions/runtimes/node-js/node-js-versions)

If PowerShell says `npm.ps1 cannot be loaded`, use Command Prompt or type `npm.cmd` in place of `npm`. You do not need to change your computer's execution policy.

## 3. Create your Supabase project

1. Sign in at [Supabase](https://supabase.com/dashboard).
2. Create a project in your organization. Choose a suitable available region and set a strong database password.
3. Wait for the project to finish provisioning.
4. Open the project's **SQL Editor**.
5. Choose the correct path below. Do not run both paths.

### Path A — new project with no KaziChap tables

1. Open `supabase/bootstrap.sql` in VS Code or Notepad.
2. Select all its contents and copy them.
3. In Supabase SQL Editor, create a new query and paste the entire file.
4. Click **Run**. This creates the original schema and applies all refinements in one transaction.
5. Success should show no SQL errors.
6. In **Table Editor**, confirm you can see `profiles`, `jobs`, `applications`, `engagements`, `conversations`, `messages`, `engagement_locations`, `reviews` and `private_contacts`.
7. Check the `engagements` table includes `billable_minutes`, `time_approved` and `total_amount_tzs`.

Do not run `001_init.sql` and `002_refinements.sql` again after bootstrap. Bootstrap already contains both. Do not use this path on a database that contains KaziChap data.

### Path B — project already initialized with the original 001 migration

1. Take a database backup using your project's available backup/export process.
2. Open `supabase/migrations/002_refinements.sql`.
3. Paste the whole file into a new SQL Editor query and click **Run**.
4. Check the three new `engagements` columns listed above.
5. Deploy the refined app together with this migration. The older app's payment RPC signature is changed by the upgrade.

The upgrade preserves accounts, jobs, messages and reviews. It deliberately deletes stored coordinates for matches that are no longer active. Input constraints are added as `NOT VALID` so pre-existing records are retained; new or updated records must satisfy them. Old records with invalid names, rates or coordinates may need correction before an update. Old paid hourly records do not have invented billable minutes or totals.

Do not rerun the original `001_init.sql`: its original policies are not designed to be applied twice. If you are unsure whether 001 ran, check whether the tables above already exist before running anything.

### If PostGIS was already installed elsewhere

The app expects PostGIS in the `extensions` schema. For a fresh project, bootstrap handles this. If SQL reports a missing `extensions.geography` type or PostGIS function on an existing project, inspect the installed extension schema first:

```sql
select e.extname, n.nspname as extension_schema
from pg_extension e
join pg_namespace n on n.oid = e.extnamespace
where e.extname = 'postgis';
```

Do not drop PostGIS from a database containing spatial data. Resolve the schema mismatch with your database administrator or use a fresh project for the pilot.

## 4. Copy the two Supabase browser credentials

1. In your Supabase project, use **Connect** or **Project Settings → API / API Keys** to locate the project URL and keys. Labels may vary.
2. Copy the project URL: it looks like `https://abcdefgh.supabase.co`.
3. Copy a modern **publishable** key starting with `sb_publishable_`.
4. Do not copy the database password, `sb_secret_` key or legacy `service_role` key.
5. This refined package expects a modern publishable key. Create one in API Keys if your project currently only shows legacy keys.

The publishable key is intentionally used by the browser. Database permissions and row-level security determine which records each logged-in user can access. The server helper and proxy follow Supabase's SSR cookie flow. [Supabase SSR setup](https://supabase.com/docs/guides/auth/server-side/creating-a-client?queryGroups=framework&framework=nextjs)

## 5. Configure authentication and the email templates

These steps matter. The original upload had no confirmation route, and a default email link can take users through a different callback flow.

1. In Supabase, open **Authentication → Sign In / Providers → Email** (or the corresponding Email provider screen).
2. Enable email signup and keep **Confirm email** enabled for the real app.
3. Open **Authentication → URL Configuration**.
4. For local testing, set **Site URL** to `http://localhost:3000`.
5. Add these exact local **Redirect URLs**:

```text
http://localhost:3000/auth/confirm
http://localhost:3000/auth/callback
http://localhost:3000/reset-password
```

6. Open **Authentication → Email Templates → Confirm signup**.
7. Set the email subject to `Confirm your KaziChap account`.
8. Replace the confirmation-link portion, or the full body, with:

```html
<h2>Welcome to KaziChap</h2>
<p>Confirm your email address to finish setting up your account.</p>
<p><a href="{{ .RedirectTo }}?token_hash={{ .TokenHash }}&type=email">Confirm my email</a></p>
```

9. Save the template.
10. Open the **Reset password** email template.
11. Set its subject to `Reset your KaziChap password` and use:

```html
<h2>Reset your password</h2>
<p><a href="{{ .RedirectTo }}?token_hash={{ .TokenHash }}&type=recovery">Choose a new password</a></p>
<p>If you did not request this, you can ignore this email.</p>
```

12. Save the template. Leave the `{{ ... }}` placeholders exactly as written.
13. The app passes `/auth/confirm` as `emailRedirectTo` / `redirectTo`. The template supplies the token hash and correct type. Successful recovery goes to `/reset-password`; signup confirmation goes to location onboarding.
14. For real users, configure an email provider under **Authentication → SMTP Settings**, verify your sender domain and test delivery. Supabase's default email service has delivery restrictions and rate limits. Check your project's current mail settings; do not assume unrestricted signup emails.

Use a separate Supabase project for development and production where possible. Redirects to a deployed preview require that preview's URL to be added explicitly. Prefer the stable production domain for emails.

## 6. Configure Google Maps

You may first test accounts, jobs and chat without a Maps key. The map shows a helpful fallback until configured.

1. Open [Google Cloud Console](https://console.cloud.google.com/).
2. Create or select a project and attach the required billing account.
3. Open **APIs & Services → Library**.
4. Enable **Maps JavaScript API**.
5. Go to **APIs & Services → Credentials → Create credentials → API key**.
6. Open the new key's settings.
7. Set application restrictions to **Websites / HTTP referrers**.
8. Add `http://localhost:3000/*` for local development.
9. Under API restrictions, restrict this key to **Maps JavaScript API**.
10. Save and copy the key.
11. In **Google Maps Platform → Map Management**, create a **JavaScript Map ID** for the production map and copy it.
12. Use that ID for `NEXT_PUBLIC_GOOGLE_MAP_ID`. `DEMO_MAP_ID` is suitable for initial development, not the production setup.

Advanced markers require a map ID. This app does not require Places, Routes or Directions APIs. [Google's advanced-marker setup](https://developers.google.com/maps/documentation/javascript/advanced-markers/start)

## 7. Set up the app locally

In Command Prompt, change to the extracted folder. Adjust this example to your actual location:

```bat
cd /d "C:\Projects\kazichap-mvp"
dir package.json
copy .env.example .env.local
notepad .env.local
```

Replace the placeholders and save:

```env
NEXT_PUBLIC_SUPABASE_URL=https://YOUR_ACTUAL_PROJECT.supabase.co
NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY=sb_publishable_YOUR_ACTUAL_KEY
NEXT_PUBLIC_GOOGLE_MAPS_API_KEY=YOUR_ACTUAL_GOOGLE_MAPS_KEY
NEXT_PUBLIC_GOOGLE_MAP_ID=YOUR_ACTUAL_JAVASCRIPT_MAP_ID
```

Do not include quotation marks, semicolons or trailing commas. `NEXT_PUBLIC_` names are case-sensitive. Never commit `.env.local`.

Then run these commands **one at a time**:

```bat
npm install
npm run doctor
npm test
npm run typecheck
npm run build
npm run dev
```

- `npm install` must finish successfully. It generates `package-lock.json`, which you should commit with the source. The editing environment could not generate a trustworthy lockfile, so none was fabricated.
- `doctor` checks configuration, imports and file presence without printing keys.
- `npm test` runs focused validation tests; these do not prove database correctness.
- `typecheck` must have no TypeScript errors.
- `build` must finish with no errors before deployment.
- `dev` starts the local server. Open [localhost:3000](http://localhost:3000).
- To stop it, press **Ctrl+C** in that terminal.

For a production-mode local check, stop `dev`, then run:

```bat
npm run build
npm run start
```

Open the same localhost URL. A second process cannot use port 3000 while the first is running.

`npm run check` runs the doctor, validation tests, typecheck and build sequentially once configuration and dependencies are installed.

If your registry reports `No matching version found`, stop and verify the named version in `package.json`. Core exact versions from the supplied project were retained but could not be resolved here. Do not blindly replace everything with `latest`. Use compatible available releases, regenerate the lockfile, then rerun typecheck and build.

## 8. Put the source on GitHub

Create an account at [GitHub](https://github.com/) if needed. Use a private repository while preparing the pilot.

### Option A — GitHub Desktop

1. Install and sign in to [GitHub Desktop](https://desktop.github.com/).
2. Choose **File → Add local repository** and select the folder containing `package.json`.
3. If it says this is not a Git repository, use its **create a repository here** option. Make sure it does not create an extra empty nested folder.
4. Review the files listed for the first commit. Include `app`, `components`, `lib`, `supabase`, `scripts`, `tests`, `.env.example`, config files, `README.md` and the generated lockfile.
5. Confirm `.env.local`, `node_modules` and `.next` are absent from the commit list.
6. Enter `KaziChap refined MVP` as the summary and commit.
7. Click **Publish repository**, use a name such as `kazichap-mvp`, and keep it private.
8. Open the repository on GitHub. Check that `package.json` is visible on its main page.

### Option B — Command Prompt and Git

1. Create a new empty repository on GitHub named `kazichap-mvp`. Do not initialize it with a README, license or gitignore; this project already has files.
2. Copy the repository's HTTPS URL.
3. In the local project root, run:

```bat
git init
git add .
git status
```

4. Inspect the staged names. Ensure no real credentials are included.
5. Run:

```bat
git commit -m "KaziChap refined MVP"
git branch -M main
```

6. Replace `YOUR_USERNAME` below with your actual GitHub username, then run:

```bat
git remote add origin https://github.com/YOUR_USERNAME/kazichap-mvp.git
git push -u origin main
```

If Git asks who you are, set your actual name and email using `git config --global user.name` and `git config --global user.email`, then repeat the commit. If a remote called `origin` already exists, inspect `git remote -v` before changing it. Do not force-push over another project.

## 9. Deploy on Vercel — exact settings

1. Sign in at [Vercel](https://vercel.com/dashboard), preferably using the GitHub account above.
2. Choose the intended Vercel team/account.
3. Click **Add New → Project**.
4. Under **Import Git Repository**, connect GitHub if necessary.
5. Give Vercel access to the `kazichap-mvp` repository. If you only grant selected-repository access, explicitly select this repository.
6. Find the repository and click **Import**.
7. Use a project name such as `kazichap-mvp` (availability may require a different name).
8. Check the following:

| Vercel setting | Value |
| --- | --- |
| Framework Preset | **Next.js** |
| Root Directory | `./` if `package.json` is on the repository's main page |
| Root Directory if the repository has an outer folder | Select the nested `kazichap-mvp` folder containing `package.json` |
| Node.js Version | **24.x**, also specified in `package.json` |
| Build Command | `npm run build` |
| Output Directory | Leave the Next.js default; do not enter `out`, `dist` or `public` |
| Install Command | Leave automatic, or use `npm ci` after committing the generated lockfile |
| Production Branch | `main` |

Next.js runs natively on Vercel. This package does not need a static export or custom rewrite file. [Next.js on Vercel](https://vercel.com/docs/frameworks/full-stack/nextjs)

9. Expand **Environment Variables** before clicking Deploy.
10. Add these **four separate rows**. Copy your actual values from `.env.local`; do not upload the `.env.local` file:

| Name | Value to paste |
| --- | --- |
| `NEXT_PUBLIC_SUPABASE_URL` | Your Supabase HTTPS project URL |
| `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY` | Your `sb_publishable_...` key |
| `NEXT_PUBLIC_GOOGLE_MAPS_API_KEY` | Your restricted Maps JavaScript API key |
| `NEXT_PUBLIC_GOOGLE_MAP_ID` | Your JavaScript Map ID |

11. Enable each for **Production**. Add **Preview** and **Development** only with the appropriate project credentials; separate development data is preferable.
12. Click **Deploy**.
13. Watch the build log. If it fails, open the first real error in the log and use the troubleshooting section below. A green validation test alone is not a successful deployment.
14. Once the status is **Ready**, open the assigned production URL and copy it. A sample is `https://kazichap-mvp.vercel.app`; use the exact URL Vercel assigned to you.

If you add or change environment variables after a deployment, open **Deployments**, choose the relevant deployment's menu, then **Redeploy**. Browser `NEXT_PUBLIC_` variables are embedded during the build; saving a value does not change an already-built browser bundle. [Vercel environment variables](https://vercel.com/docs/environment-variables)

## 10. Finish domain configuration before signing up real users

Suppose your actual production URL is `https://kazichap-mvp.vercel.app`. Replace this example with your real URL everywhere below.

### Supabase

1. Open **Authentication → URL Configuration**.
2. Change **Site URL** to `https://kazichap-mvp.vercel.app`.
3. Add these **Redirect URLs**:

```text
https://kazichap-mvp.vercel.app/auth/confirm
https://kazichap-mvp.vercel.app/auth/callback
https://kazichap-mvp.vercel.app/reset-password
```

4. Save. Keep localhost entries only for the environment where you intend to test locally.
5. For an explicitly used Vercel preview, add that preview's exact equivalents. Production-domain settings do not automatically authorize every preview URL.

### Google Cloud

1. Open the Maps key's restrictions.
2. Add `https://kazichap-mvp.vercel.app/*` as an allowed website referrer.
3. Save and allow time for configuration propagation.
4. If you add a custom domain later, add both its actual apex and `www` variants if you use both.
5. Do not grant `https://*.vercel.app/*` to every Vercel website.

### Optional custom domain

1. In Vercel, open **Project → Settings → Domains**.
2. Add your domain and follow the exact DNS records Vercel displays.
3. Wait for DNS verification and HTTPS readiness.
4. Repeat the Supabase Site URL/redirect steps and Maps referrer steps for the new domain.
5. Verify confirmation and reset emails again after switching domains.

## 11. Test the deployed app with two accounts

Use a test Supabase project first. Open a normal browser window for the customer and Incognito (or another browser/profile) for the provider. Use two email inboxes you can receive mail at. Use a normal trade category such as Plumber initially.

1. Provider: choose **I'm ready to work**, create a Plumber profile at **15,000 TZS/hr**, confirm email and allow location.
2. Provider: click **Go online**.
3. Customer: choose **I need a hand**, create an account, confirm email and save a location within 15 km of the provider.
4. Customer: find the provider under Plumber and send an inquiry.
5. Provider: the inquiry should appear on the dashboard within about 10 seconds. Open chat and reply.
6. Confirm messages appear in both windows without reloading. Polling recovers within about 5 seconds if Realtime disconnects.
7. Provider: accept the inquiry. Both open the match.
8. Each participant clicks **Share my live location** only if desired. Confirm both labelled markers appear after updates. Denying GPS must leave chat and match controls usable.
9. Stop sharing in one window. Its stored coordinate should be removed; the other window updates on its next refresh.
10. Start the job. Only then should the completion button appear.
11. Confirm completion in each account. One confirmation alone must not close the job.
12. After both confirmations, the match becomes completed and the live map stops showing positions.
13. Provider: open the payment page and propose **90 minutes**.
14. Both pages should display **22,500 TZS** at 15,000 TZS/hr.
15. Customer: approve the 90 minutes. If the provider changes the proposal before payment, approval must reset and the customer must approve again.
16. In the **test database only**, exercise manual payment acknowledgements. In real use, click these buttons only after an actual direct payment and actual receipt.
17. Customer marks payment sent. Provider confirms receipt. Both see `paid`.
18. Customer submits a review. Reload the page: it should not permit another review.
19. Repeat through the job-posting path: customer posts a fixed **20,000 TZS** job → provider submits an offer → customer accepts. The fixed application form must default to the job's fixed amount, and no hourly-time approval is required.
20. Try cancellation of an open job and cancellation of a requested/accepted match. Cancellation must not be available once work has started.
21. Open a private match/chat link while signed out. You should be sent to login, then return to the safe local destination after sign-in.
22. Sign in as an unrelated third test account and try those links. Access must be denied and no coordinates/messages shown.
23. Test **Forgot password** and **Resend confirmation email**, including an expired link.
24. Test at phone width and with keyboard navigation. Press Escape to close a modal while it is idle.

Run `supabase/tests/regression.sql` in the SQL Editor of your test project after applying the schema. It creates temporary test accounts and records inside a transaction and rolls everything back. Inspect the assertions and final rollback result. This script was supplied but could not be executed against PostgreSQL in the editing environment.

## 12. Verify Doctor / Nurse profiles manually

These categories are blocked from discovery, applications and acceptance until verified. The app does not perform the verification itself.

1. Review the person's credentials through your real administrative process.
2. Find the provider UUID under Supabase **Authentication → Users** or `profiles`.
3. In SQL Editor, replace the placeholder UUID below and run this only after verification:

```sql
update public.profiles
set is_verified = true,
    verification_status = 'verified',
    updated_at = now()
where id = 'REPLACE_WITH_PROVIDER_UUID'::uuid
  and role = 'provider'
  and service_category in ('Doctor', 'Nurse');
```

4. Reload that provider's dashboard and confirm they can go online.
5. To revoke verification, set `is_verified=false`, `verification_status='rejected'` and `is_online=false` for the correct provider.

Ordinary users cannot set these flags through a table update. Do not add a public verification toggle to work around this gate.

## 13. Troubleshooting

| Symptom | What to check |
| --- | --- |
| `npm` is not recognized | Install Node.js 24, reopen Command Prompt and check `node --version`. |
| `package.json` not found | You are in the wrong directory. Run `dir` and move to the extracted folder containing the file. |
| npm install HTTP 403 | Registry/network access is blocked or denied. Resolve the access issue and rerun; do not call the app tested until install and build succeed. |
| `No matching version found` | Verify the exact named dependency is published and compatible. Retained supplied core versions were not install-verified here. |
| Vercel says no Next.js framework found | The selected Root Directory must contain this `package.json`. |
| Vercel build fails on TypeScript | Fix the first reported type error and rerun local typecheck/build. Do not disable type errors. |
| Landing works but account pages say setup incomplete | Add real Supabase URL and modern publishable key in the correct Vercel environment, then redeploy. |
| Supabase function/table not found | Apply bootstrap for a fresh project or 002 for an initialized project. Ensure the URL/key belong to that same project. |
| `billable_minutes` or `total_amount_tzs` missing | The refined database migration has not been applied to the connected project. |
| `Database error saving new user` | Check SQL Editor/migration success, Postgres logs and signup metadata; inspect whether old incompatible tables already existed. |
| No confirmation email | Check spam, SMTP configuration, delivery restrictions, rate limits and the entered email. |
| Confirmation/reset link fails | Check the exact email templates, `/auth/confirm` redirect allowlist, token expiry and current origin. Request a fresh email after fixing settings. |
| `permission denied` / RLS error | Confirm the signed-in role owns the action, 002 ran completely, and the source queries use permitted columns. Do not disable RLS. |
| No nearby providers | Provider must be online, have saved GPS, match the category and be within 15 km. Professional categories need verification. |
| No nearby jobs | Provider must have GPS, matching service and eligibility, with an open job within 20 km. |
| Location denied | Allow location in browser site settings and device settings. Use HTTPS in production or localhost locally. |
| Google map is blank or fails | Check Maps JavaScript API, billing, valid Map ID and exact local/production website restrictions. Consult the browser console for Google's specific error. |
| Payment button absent | Both sides must complete the job. Hourly jobs require a provider time proposal and customer approval. |
| Changes do not appear | Commit/push the changed code, wait for the new Vercel deployment, then refresh. Changed public environment values require a new build. |
| Old hourly payment has no total | Historical paid records lack billable-time data. The upgrade preserves this uncertainty instead of inventing totals. |

## 14. Updating after your first deployment

1. Edit the local source.
2. Run `npm run check`.
3. If dependencies changed, commit the updated `package.json` **and** `package-lock.json`.
4. Commit and push to GitHub. Vercel's Git integration builds updates automatically.
5. Apply any explicitly included new database migration according to its instructions. A Vercel deployment does not run Supabase migrations automatically.
6. Confirm the new production deployment is Ready and rerun the affected two-account test steps.

## Files you should know

```text
app/                         Pages, client screens, auth handlers and fallback pages
components/                  Dashboards, forms, dialogs, brand and map
lib/supabase/                Browser/server clients and authenticated proxy logic
lib/validation.ts            Input, redirect and payment-calculation helpers
proxy.ts                     Route matching and session protection
supabase/bootstrap.sql       Fresh empty project setup: 001 + 002
supabase/migrations/001_init.sql   Original schema, retained for upgrade history
supabase/migrations/002_refinements.sql  Existing-project upgrade
supabase/tests/regression.sql Transactional database regression checks
scripts/doctor.mjs           Setup/source preflight (does not print keys)
tests/validation.test.mjs    Focused executable validation tests
.env.example                Blank environment template
README.md                   This launch guide
docs/REVIEW.md              Findings, fixes and remaining verification limits
```

Keep `.env.local`, `node_modules` and `.next` out of Git. Keep `.env.example` and the generated lockfile in Git. This MVP still needs an operational support/dispute process, monitoring, abuse controls and completed live integration testing before a wider public rollout.
