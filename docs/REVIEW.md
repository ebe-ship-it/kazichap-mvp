# KaziChap source review and validation record

Review target: the complete uploaded `kazichap-mvp` source, supplied in the second non-empty project ZIP. Refined source version: 0.2.0. This is a new deliverable; the upload is retained as the original reference.

## Findings addressed

| Original finding | Change |
| --- | --- |
| No confirmation or password recovery routes | Added server confirmation/PKCE handlers, login resend, password-reset flow and exact email templates in README |
| Browser client initialization assumed credentials always existed | Added configuration checks, setup page and server wrappers for account-dependent routes |
| Proxy refreshed cookies but did not protect account routes | Added claims-based route protection, cookie forwarding and safe login redirects |
| Dashboards only loaded once | Added visible-tab polling, focus refresh and explicit loading/error feedback |
| Worker applications and direct inquiries used browser prompts | Added labelled modal forms, amount limits, fixed-price defaults and duplicate handling |
| Customer could not manage listed job posts | Added posted-job list and cancellation while open |
| One-to-one chat could hide sent messages without a functioning Realtime stream | Added reload after send, polling recovery and length limits |
| Match and payment state did not reliably refresh for the other participant | Added match subscriptions plus polling; payment polls while visible |
| Live GPS attempted updates for requested/closed matches and silently swallowed errors | Added explicit opt-in, active-state gating, stop controls, throttling and visible GPS errors |
| Stored location remained readable after match completion | Restricted RLS to active matches and added closure cleanup trigger |
| Payment screen treated hourly rate as final amount | Added database-generated total from proposed minutes, customer approval and expected-value checks |
| Direct inquiry skipped professional verification | Checked eligibility when opening and accepting inquiries and at job start |
| Application policy allowed arbitrary initial status on direct inserts | Removed direct inserts and added role/category/verification validation in apply RPC |
| Hiring did not require pending application; concurrent hires could deadlock | Rechecked application state and standardized job-before-application lock order |
| PUBLIC-only function revocation could leave explicit default anonymous grants | Explicitly revoked PUBLIC, anon and authenticated execution, then granted intended authenticated RPCs |
| Broad table privileges were left to project defaults | Added explicit column/table grants with RPC-only writes for controlled transitions |
| Simultaneous reviews could produce stale aggregate ratings | Serialized updates with a provider row lock |
| API dependency declarations included unconstrained latest versions | Bounded those versions, added Node 24 requirement and lockfile instructions |
| Supplied setup guide omitted critical Vercel, SMTP and callback steps | Added detailed Windows, Supabase, email, Maps, GitHub and Vercel instructions |

## Checks actually executed

- Archive extracted and all application source/configuration files inspected.
- Eight Node validation tests passed, covering phone normalization, amount validation, coordinate limits, hourly totals and external-redirect rejection.
- Source preflight passed for local imports and literal Supabase RPC references.
- JSON configuration parsed successfully.
- Final ZIP checked for expected source files and exclusion of credentials/build/dependency directories.

## Checks blocked or not performed

- The npm registry returned HTTP 403 in this environment. Package installation/version resolution and a reliable lockfile could not be completed.
- TypeScript compilation was attempted but `tsc` was unavailable because dependencies could not be installed.
- Next.js production build and browser testing of a running app were unavailable for the same reason.
- No live Supabase project credentials were supplied. SQL migration execution, RLS regression execution, confirmation email delivery, Realtime and two-account end-to-end flows remain unverified.
- Google Maps rendering/billing/key restrictions were not tested with a real key.
- No Vercel deployment was created or claimed.

Do not interpret the local validation tests as proof that the app builds or that the migration executes. Run the README gates with a test Supabase project before public use. The included transactional SQL regression script exercises database behaviours; it is not an executed result from this review.

## Remaining MVP limits

- Manual payment acknowledgements only; no mobile-money integration or escrow.
- No automated identity or professional verification, admin UI, dispute/report/block flow, push, background GPS or offline mode.
- Availability is a manual toggle. Closed tabs do not automatically turn providers offline.
- Discovery uses saved coordinates and approximate distance; users can update their own service location. This is not an anti-stalking or location-attestation system.
- Explicit stop-sharing and match closure delete location rows. Navigating away attempts cleanup; abrupt device/network loss can prevent that request. Old markers are hidden in the UI, but active-match rows can remain until closure or a successful cleanup.
- Histories are capped in the MVP UI; no pagination/search for older records yet.
- New constraints apply to new/updated rows; existing rows are retained using NOT VALID constraints.
- No infrastructure-level rate limiting, monitoring, moderation or formal security assessment was completed.
