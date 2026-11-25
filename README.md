# Made & Found

A persistent multi-artisan handmade marketplace implemented from [SRS-plan.md](SRS-plan.md).

Next.js App Router, React, TypeScript, Tailwind, shadcn-style Radix primitives, scoped MUI tables, Zod, Drizzle, and PostgreSQL. The storefront uses an ivory, forest-green, and clay palette, editorial serif headings, responsive photography, and dedicated account, studio, and administration workspaces.

## Run locally

Requires Node.js 24 and npm. On Windows PowerShell, use `npm.cmd` if execution policy prevents `npm.ps1` from running.

```powershell
npm.cmd install
Copy-Item .env.example .env.local
npm.cmd run db:seed
npm.cmd run dev
```

Open **http://localhost:3000**. The local database is already initialized in this workspace.

Generated demonstration credentials are in **`.data/demo-credentials.txt`**. This ignored local file contains a customer, three artisans, and an administrator. Passwords are generated during the first seed; no public default password is embedded in the application. Seed runs are idempotent and never reset existing accounts. To choose credentials before the first seed, set `DEMO_PASSWORD`, `ADMIN_EMAIL`, and `ADMIN_PASSWORD` in `.env.local`.

The seed creates five categories, three approved studios, sixteen public products, two pending listings, an address, a wishlist entry, a promotion, and a homepage campaign. It intentionally does not fabricate captured payments, sales, or buyer reviews. HTTP verification creates clearly named local verification records.

## Test checkout without payment credentials

Local development now enables a clearly labeled demonstration checkout. With `npm run dev`, no Stripe or PayPal keys are needed:

1. Register or sign in, then open **Account → Profile → Open development inbox** (also linked from checkout). Open the latest verification message and verify your email. With no sender configured, these messages are local previews, not deliveries to Yopmail.
2. Open **Account → Payment methods** and connect **Demo Visa** or **Demo PayPal**. Connections persist to your account; you can choose a default and disconnect them. No real financial account is linked, and no real card number is collected.
3. Add items and an address, select a connected demo method at checkout, and choose **Continue to demo review**.
4. Choose **Confirm demo order — no charge**. The persisted order is marked `simulated`, remains separate from financial reports/settlements and verified-purchase reviews, and supports test seller fulfillment. Cancelling a pending demo checkout releases reserved inventory.

Set `DEMO_MODE=false` to disable this flow and require configured sandbox providers. An explicit `DEMO_MODE=true` also enables demonstrations when running the production build, as in the local Docker setup. Never present demonstration connections as real provider authorizations.

**Logout** is visible in the header and account/studio/admin workspace. It revokes the current database session and clears client navigation state.

## Docker Compose

Requires Docker Desktop (with Linux containers) or Docker Engine with Compose. Docker is not installed in the implementation environment, so actual container startup has not been verified here. YAML/service wiring is covered by an automated test, and CI includes Compose validation and image builds.

Stop any process already using port 3000, then run:

```powershell
docker compose up --build
```

- Marketplace: **http://localhost:3000**
- Mailpit email inbox: **http://localhost:8025**
- PostgreSQL: internal Compose network only, with a durable named volume.
- A one-shot initialization service migrates and seeds before the app starts. A separate worker processes email/expiry jobs every 30 seconds after the app is healthy. Registration and other mutations also trigger email processing automatically.
- Product uploads and Mailpit messages have named volumes. Containers run the application as a non-root user. Local services bind only to loopback.

On the first Docker seed, customer/three artisan passwords default to `LocalDemoCraft2026!`; the administrator `admin@madeandfound.local` uses `LocalDemoAdmin2026!`. Set `DEMO_PASSWORD`, `ADMIN_EMAIL`, `ADMIN_PASSWORD`, `POSTGRES_PASSWORD`, and `JOBS_SECRET` before first startup to override these local-demo values. Existing database volumes retain their accounts and passwords. This is a separate database from the host's `.data/marketplace.pglite` archive.

```powershell
docker compose logs -f app worker
docker compose down
```

`down` preserves volumes. The supplied Compose file is a local demonstration setup. For a public deployment, disable `DEMO_MODE`, use HTTPS, replace development credentials/secrets, and configure actual providers and object storage.

Mailpit catches SMTP messages locally; it does **not** deliver them to Yopmail. To send to a real external inbox, set a real SMTP server (`SMTP_HOST`, `SMTP_PORT`, `SMTP_SECURE`, optional `SMTP_USER`/`SMTP_PASSWORD`, `EMAIL_FROM`) or configure Resend. The address must have the form `name@yopmail.com`, with `@` rather than a quotation mark. SMTP delivery is tested against a local SMTP receiver; external sender delivery requires your provider configuration.

## Implemented features

- Public catalog: product/artisan/category search, combined URL filters, sorting, pagination, product galleries, variants, availability, artisan directory, and storefronts.
- Identity: email/password registration, scrypt password hashing, opaque database sessions, logout, single-use verification/reset tokens, session revocation, rate limits, and configured Google/Facebook OAuth. Existing identities must be explicitly linked while signed in.
- Customer accounts: persistent wishlist and bag, quantity editing, profiles, address editing, notifications, order history, delivery confirmation, and reviews restricted to delivered purchases.
- Commerce: server-side integer money arithmetic; per-maker orders, shipping and discounts; destination shipping zones; jurisdiction/effective-date tax settings; immutable purchase/pricing snapshots; checkout quote-change detection; transactional stock reservation; idempotent order creation; and inventory release.
- Payments: real Stripe test Checkout and PayPal sandbox order/capture adapters, authenticated return flows, signed/verified webhooks, event deduplication, and provider-managed Stripe payment-method portal. Unconfigured providers stay unavailable. A redirect never marks an order paid.
- Artisans: approval-gated onboarding, shop biography and photo editing, product and variant/stock editing, image uploads and cover ordering, moderated publication, own-order fulfillment, tracking, custom quotes, sales reports, and feedback.
- Custom commissions: private reference images, structured briefs, participant conversations, request decisions, versioned quotes, customer revision/decline, expiry checks, immutable acceptance, payable custom orders, and fulfillment.
- Administration: account restrictions and session revocation, artisan approval, listing moderation with reasons, order/payment/refund oversight, support requests/replies, category/banner/promotion editing, scheduled campaigns, shipping/tax/payment controls, audit records, and live reports.
- Assistant: persistent account history, live product cards and deterministic catalog fallback. With an OpenAI key, server-side function calling adds shopping, custom-brief preparation, artisan reports/inquiry summaries, and admin reports/moderation/support summaries. Cart and custom-request tools prepare short-lived, owner-bound actions that require explicit confirmation. Token counts, latency, failures, optional cost estimates, and tool audits are recorded.

## Local persistence and PostgreSQL

With no `DATABASE_URL`, the app runs real PostgreSQL through PGlite and saves checkpointed, compressed database archives to `.data/marketplace.pglite`. Each successful mutation/transaction waits for an atomic, flushed snapshot replacement. A process lock prevents two processes from opening the same local archive. This avoids a persistent NodeFS/WAL recovery failure observed on Windows/OneDrive during implementation.

This adapter is for **single-process local development**. Stop the development server before running local `db:seed`, `db:migrate`, or `jobs` scripts. For background work while the server runs, use the authenticated HTTP jobs endpoint. Do not put the local archive on a serverless filesystem or share it between workers. Its format is tied to the installed PGlite version; preserve `package-lock.json` and export/migrate data before upgrading the engine. Older diagnostic directories in `.data/` are not used by the application.

For deployment, configure a dedicated PostgreSQL database and durable object storage:

```dotenv
DATABASE_URL=postgresql://USER:PASSWORD@HOST:5432/DATABASE
NEXT_PUBLIC_SITE_URL=https://your-marketplace.example
ADMIN_EMAIL=your-admin@example.com
ADMIN_PASSWORD=use-a-long-unique-password
```

Run `npm run db:migrate` and bootstrap the administrator with `NODE_ENV=production npm run db:seed`. Production seeding creates the administrator, categories, and baseline settings, and rejects `SEED_DEMO=true`; remove that development flag first. A production startup requires `DATABASE_URL`. `ALLOW_LOCAL_DATABASE=true` is an explicit exception for a single-process local production-build preview, not a deployment recommendation.

The initial migration is [drizzle/0000_marketplace.sql](drizzle/0000_marketplace.sql). Domain services use parameterized SQL transactions; Drizzle provides typed catalog reads/schema definitions. Foreign keys, uniqueness, inventory, rating, and money constraints are enforced in PostgreSQL.

## Configure integrations

All secrets belong in `.env.local` or the deployment secret manager. None use a `NEXT_PUBLIC_` prefix. [.env.example](.env.example) lists the contract. Restart the server after changing credentials.

### Stripe test mode

Set `STRIPE_SECRET_KEY` to an `sk_test_…` key and `STRIPE_WEBHOOK_SECRET` to the endpoint signing secret. Enable Stripe in `/admin/settings/payments`. Live keys are rejected in this release.

Forward test events to `/api/webhooks/stripe`. Subscribe to `checkout.session.completed`, `checkout.session.expired`, `checkout.session.async_payment_failed`, `refund.created`, `refund.updated`, and `refund.failed`. Card Checkout is the only enabled Stripe payment type. Configure the Stripe customer portal’s payment-method management before using saved-card management. Raw card data stays with Stripe.

Use the Stripe CLI or dashboard to verify actual sandbox purchase, replay, expiry, and refund behavior before release. Checkout creation uses the immutable order ID as its provider idempotency key. Amount/currency mismatches fail transactionally. Unpaid orders reserve stock for about 31 minutes; the jobs worker confirms Stripe expiration before releasing it. Orphan checkout references are reconciled against provider sessions.

### PayPal sandbox

Set `PAYPAL_CLIENT_ID`, `PAYPAL_CLIENT_SECRET`, and `PAYPAL_WEBHOOK_ID`. Register `/api/webhooks/paypal` for `PAYMENT.CAPTURE.COMPLETED`. The adapter uses only `api-m.sandbox.paypal.com`. The customer approves at PayPal, then submits capture from the authenticated return page. Only a successfully verified capture webhook confirms payment. Capture-in-progress prevents premature inventory release. Automated PayPal refunds and PayPal vaulting are not implemented.

### Google and Facebook

Set the matching client ID/secret pairs. Register these exact callback URLs under the configured site origin:

```text
/api/oauth/google/callback
/api/oauth/facebook/callback
```

Buttons appear only for configured providers. Google uses state and PKCE; both providers use expiring HttpOnly state cookies, server-side code exchange, and explicit account linking. Validate app permissions and approved callback domains in each provider’s console.

### Email and background jobs

Set SMTP credentials or `RESEND_API_KEY` and a verified `EMAIL_FROM` for external delivery. Jobs are persisted before delivery and retried with backoff. Mutating requests automatically trigger delivery after their response, so registration no longer needs a manual worker run. Without a provider, messages are labeled `previewed`, saved in **`.data/outbox/`**, and shown in the authenticated **`/account/mail`** development inbox. They are not marked as sent to an external inbox. The standalone `npm run jobs` command remains available with the local server stopped; Docker supplies a periodic worker automatically.

Outside the supplied Docker setup, schedule **`POST /api/jobs`** with `Authorization: Bearer <JOBS_SECRET>` from a trusted scheduler every minute. This processes email, expires unpaid orders, expires quotes, and removes expired sessions/rate-limit entries. Configure a long random `JOBS_SECRET`. There is no unauthenticated jobs trigger. Docker supplies its own periodic worker; other deployments must configure their scheduler.

### Images and private references

Development images are stored under `.data/uploads/` and served through `/api/media/:id`. Uploads accept JPEG/PNG/WebP only, validate file signatures and MIME, cap size at 5 MB, and limit count in listing/request forms. Reference downloads check request participants on every read. SVG uploads are rejected.

For deployment, set `STORAGE_BUCKET`, `STORAGE_REGION`, `STORAGE_ACCESS_KEY_ID`, `STORAGE_SECRET_ACCESS_KEY`, and optional `STORAGE_ENDPOINT`. Keep the bucket private; application routes enforce media visibility. Production uploads require configured object storage. Configure scanning, lifecycle/retention, and backups for your deployment.

### OpenAI assistant

Set `OPENAI_API_KEY` and optionally `OPENAI_MODEL` (default `gpt-4.1-mini`). AI-enabled conversation requires sign-in; guests use deterministic live-catalog search. Set current `OPENAI_INPUT_COST_PER_MILLION` and `OPENAI_OUTPUT_COST_PER_MILLION` to record cost estimates. These rates are operator configuration, not hard-coded price claims.

Tools use the current authenticated user, never a model-provided user/role. Database reports stay scoped to the seller or administrator. Content is treated as untrusted data, writes require confirmation, and the assistant cannot directly approve listings, suspend users, refund, or pay. Design-image generation is optional and is not implemented.

## Verification

```powershell
npm.cmd run typecheck
npm.cmd test
npm.cmd run build
# With npm run dev serving localhost:3000 in a separate terminal:
npm.cmd run test:demo
npm.cmd run test:http
```

The automated suite exercises real PostgreSQL semantics through PGlite, including restart persistence, concurrent inventory claims, checkout idempotency and reconciliation, role/ownership failures, moderation, quote acceptance/revisions/expiry, payment signatures and replay, refunds, uploads/private media, verification tokens, and AI confirmation. Provider calls are mocked only in targeted checkout tests; those tests are not evidence of a real sandbox purchase.

The local HTTP test signs into generated demonstration accounts, checks rendered routes and CSRF, verifies a listing moderation journey, exchanges participant messages, accepts a custom quote into an unpaid order, and exercises the assistant fallback. It only accepts localhost destinations. Verification records remain in the local demonstration database with explicit “Verification” names.

CI runs type checking, unit/integration tests, and the production build. Source formatting uses `npm run format`.

See [IMPLEMENTATION.md](IMPLEMENTATION.md) for acceptance status and the exact remaining verification and production gaps.

## Operational notes

- Use managed PostgreSQL backups/PITR and object-storage backups. Restore into staging and run the acceptance journeys before changing production traffic.
- Apply SQL migrations before rolling out application changes. Take a backup; do not automatically reset a database after migration failure.
- Monitor failed email jobs, unmatched/rejected payment events, unpaid-order expiry failures, pending refunds, application errors, and AI usage/failures. Logs contain event identifiers rather than raw provider secrets/card data.
- Settlement records are an internal liability ledger only. This build does not transfer money to artisans or claim marketplace payout compliance.
- Full Stripe sandbox refunds are admin-mediated and restricted to unshipped orders. Pending refunds block fulfillment; confirmed refunds restore inventory once. Carrier integrations, automatic delivery confirmations, and return logistics are not provided.
- Replace sandbox legal/operator content with your merchant identity, jurisdiction-specific terms, return windows, privacy retention, and support procedures before live sales. Publish only after provider, accessibility, responsive-browser, PostgreSQL deployment, and recovery verification.

Implementation references: [Next.js authentication](https://nextjs.org/docs/app/guides/authentication), [PGlite filesystems and archives](https://pglite.dev/docs/filesystems), [Stripe webhook signatures](https://docs.stripe.com/webhooks/signatures), [PayPal webhook verification](https://developer.paypal.com/api/rest/webhooks/rest/), and [OpenAI function calling](https://developers.openai.com/api/docs/guides/function-calling).
