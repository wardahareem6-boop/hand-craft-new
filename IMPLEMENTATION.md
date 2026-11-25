# Implementation and acceptance status

The original specification remains unchanged. This document distinguishes implemented code, verified local behavior, and external/production acceptance work.

## Follow-up: usable local checkout, mail, logout, and Docker

- Fixed the default-size/primary-variant CSS collision that made outline and ghost buttons—including logout—render white text on transparent backgrounds. Presentation regression tests cover every non-primary variant.
- Added visible header/workspace logout controls with session revocation and full navigation reset.
- Added persisted demo card/PayPal connections, default/disconnect controls, explicit no-charge review/confirmation/cancellation, test fulfillment, and server-enforced demo ownership/confirmation. Demonstration orders use `payment_status=simulated`, have `is_demo=true`, and are excluded from GMV, settlements, and verified-purchase reviews. They are never reported as provider-paid.
- Added automatic email queue processing after mutations, SMTP transport, truthful preview status, and an authenticated development inbox with usable verification links. No external email is claimed when no sender is configured. Docker Mailpit captures messages locally.
- Added sign-in connection cards that distinguish connected, available, and unconfigured Google/Facebook providers.
- Added a multi-stage Dockerfile, local Compose stack (PostgreSQL, migrations/seed, application, Mailpit, and worker), durable volumes, non-root runtime, loopback exposure, health checks, and Docker CI validation/build steps. Docker runtime verification remains unavailable because Docker is not installed on this machine.
- Added a local HTTP regression script (`npm run test:demo`) for new-account verification, method linkage, demonstration checkout, and logout; SMTP delivery is tested against a local receiver.

The remaining sections refer to real external provider acceptance. The demonstration flow intentionally does not replace those checks.

## Implemented and locally exercised

| SRS area                          | Delivered behavior                                                                                                                                                                                                                   | Evidence                                                                                       |
| --------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ---------------------------------------------------------------------------------------------- |
| Foundation and persistent records | Next.js/React/TypeScript application, Tailwind/Radix components, scoped MUI tables, PostgreSQL schema/constraints, Drizzle reads, migrations, seed, CI                                                                               | Typecheck, production build, SQL integration suite, local restart-persistence test             |
| Customer credentials              | Registration, salted scrypt hashes, database sessions, logout/revocation, verification/reset tokens, rate limits, profile and address management                                                                                     | Auth/session/token and HTTP checks                                                             |
| Marketplace                       | Categories, approved artisan storefronts, moderated product CRUD, variants, stock, images, combined catalog filters, search/sort/pagination, favorites                                                                               | Domain tests and listing-to-moderation HTTP journey                                            |
| Bag and checkout core             | Persistent bag, quantity/stock validation, integer totals, seller groups, destination shipping, configured tax, promotions, quote fingerprint, stock reservation, idempotency, financial snapshots                                   | Money, stock race, multi-seller checkout, stale-quote, and duplicate-request tests             |
| Payment reconciliation            | Signed Stripe events, PayPal verification adapter, amount/currency checking, replay protection, paid-state transition, notifications, expiry/release logic                                                                           | Cryptographic test-signature and transaction tests; real provider acceptance still required    |
| Fulfillment                       | Seller-scoped order views, paid-only state transitions, shipment tracking, customer delivery confirmation, history, verified-purchase reviews                                                                                        | Authorization and fulfillment tests, rendered role pages                                       |
| Custom requests                   | Structured briefs, private reference images, participant messages, seller decisions, versioned quotes, revision/decline, expiry, one-order acceptance, locked terms, payment handoff                                                 | Ownership/media/quote concurrency tests and customer/artisan HTTP journey                      |
| Seller reports                    | Actual paid merchandise totals, refunds/net merchandise, order count, best sellers, feedback, low-stock lists, daily chart and date filters                                                                                          | Database-backed report queries; empty seed dashboards accurately show zero sales               |
| Admin controls                    | User restrictions, session revocation, artisan approval, listing decisions, orders/transactions, full unshipped Stripe sandbox refunds, categories, banners, promotions, shipping zones, tax/payment controls, support inbox, audits | Admin/security/refund tests and rendered configuration pages                                   |
| Notifications and email queue     | Persisted notifications, read state, durable email jobs, retry/backoff, local outbox, configured Resend delivery                                                                                                                     | Local queue records; external delivery acceptance still required                               |
| Marketplace assistant             | Live catalog fallback, persisted conversation, role-bound read tools, proposed cart/custom actions, single-use explicit confirmations, tool/usage logs                                                                               | Fallback, persistence, ownership, and confirmation tests; live model acceptance still required |

Checkout tests that stub provider calls verify local business logic. They are explicitly **not** proof of a real Stripe or PayPal sandbox purchase.

## Credentials and deployment work still required

1. Configure an eligible Stripe test merchant and/or PayPal sandbox account, public HTTPS webhook forwarding, and the Stripe customer portal. Complete real product and custom-order payment journeys, refund verification, webhook replay, and reconciliation. No provider keys were available in this workspace.
2. Configure Google/Facebook apps and test registration/linking/callback failures with real provider identities. Buttons remain hidden without credentials.
3. Configure a verified email sender and run delivery acceptance tests. Locally, the worker writes an outbox file rather than sending email.
4. Configure `OPENAI_API_KEY` to test real function calling, model failures, token/cost recording, and all three role experiences. Without it, the assistant truthfully identifies its deterministic catalog mode.
5. Provision production PostgreSQL, private object storage, secret management, the jobs scheduler, deployment monitoring, backups, and a restore drill. The local PGlite adapter is single-process development storage.
6. Run browser-based responsive and accessibility QA at 360/768/1024/1440 pixels, keyboard/screen-reader checks, and performance measurements. Browser automation was unavailable and the accessible native Chrome window was minimized; no visual QA pass or screenshots are claimed.

## Deliberate implementation limits

- Sandbox payments only; live Stripe keys are rejected. Marketplace payouts are an internal ledger, not actual transfers.
- Automated refunds cover full, unshipped Stripe test orders. Automated PayPal refunds, partial refunds, disputes, return logistics, and carrier APIs remain outside this implementation. Shipped refund cases require review.
- Saved methods use Stripe’s configured customer portal. PayPal vaulting is unavailable.
- One configured currency (USD); exclusive, operator-configured country/region tax and standard country shipping zones. Multiple carriers, weight bands, inclusive taxation, automated tax services, and simultaneous tax jurisdictions are not modeled.
- Custom design-preview image generation, conversation-image attachments outside the custom brief, realtime typing/push transport, and automatic delivery confirmation are not implemented. Messages persist and refresh by polling.
- Local integration records and sample photos are demonstration content. Production merchant/legal identity, final return windows, retention/deletion processing, scanning, and observability vendors need operator setup.
- Private API reads/writes enforce ownership. The early proxy only redirects guests; a cookie’s presence never grants access.
- The app provides HTTP end-to-end checks and SQL/domain integration tests. A Playwright visual/browser suite and production load/concurrency testing against the deployment PostgreSQL service remain outstanding.

## Manual acceptance journeys

Use the accounts generated in `.data/demo-credentials.txt` in separate browser profiles.

1. **Listing:** artisan signs in, edits/creates a listing with photos and options, submits it; it stays private. Administrator reviews and approves. Customer finds it in the catalog. Edit the description and confirm it returns to pending review.
2. **Purchase:** customer saves an address and adds pieces from two makers. Review separate shipping and totals. Configure the provider, complete its real sandbox checkout, and observe pending until the signed webhook arrives. Confirm suborder totals reconcile. Sellers prepare/ship only their own items. Customer confirms delivery and reviews the purchased piece.
3. **Custom commission:** customer sends a brief and private reference. Assigned artisan opens it and sends a quote; another artisan receives no access. Customer requests a revision, accepts the latest quote, and opens the linked payable order. Complete sandbox payment and fulfillment. The accepted price and terms stay unchanged.
4. **Restriction:** administrator records a reason and confirmation when suspending an account. Sessions are revoked and restricted sellers’ listings leave the public purchasable catalog. Audit history remains available.
5. **Assistant:** search actual products under a budget. With an API key, ask it to prepare a cart change. Verify that the cart remains unchanged until explicit confirmation, and that a second user cannot execute the proposed action.

Final command results are reported in the delivery response. Requirements involving external providers remain unverified until the corresponding real acceptance journey passes.
