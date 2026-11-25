# Online Handmade Crafts Store — Software Requirements Specification & Implementation Plan

**Document:** `SRS-plan.md`  
**Version:** 1.0  
**Status:** Implementation blueprint  
**Application type:** Multi-vendor handmade crafts marketplace  
**Primary stack:** React + Next.js (App Router) + TypeScript + shadcn/ui + Material UI (MUI)  
**Source:** The two supplied assignment screenshots; implementation choices and production-readiness additions are marked separately below.

---

## 1. Purpose and scope

Build a visually polished, accessible, secure, responsive marketplace that connects customers with artisans selling handmade crafts. Customers can browse and purchase listed goods and request personalized products. Artisans can operate their own storefronts, manage inventory and orders, quote custom requests, and understand sales. Administrators moderate users and listings, oversee transactions, and manage the marketplace.

**The application must work end-to-end with persistent data.** No fake checkout, static dashboards pretending to be functional, or buttons that do nothing. External services must use real sandbox/test integrations before production credentials are activated.

### 1.1 What the assignment explicitly requires

The supplied assignment defines the following roles and capabilities:

| Role | Required functional areas |
|---|---|
| Customer | Email/password registration and login; social login (Google/Facebook); craft categories; search by name/artisan/category; filtering by price/rating/availability; detailed product pages with images, description, price, stock; product reviews and ratings; custom-design request forms; direct communication with artisans; cart and quantity editing; secure checkout with multiple methods (credit card/PayPal etc.); order confirmation; shipment/order statuses and notifications; wishlist; personal profile/address; order history; saved payment methods. |
| Artisan / Seller | Email registration/login; upload and manage product images/descriptions/prices; inventory/availability; accept or decline custom requests; order viewing and status updates; review and communicate on custom requests; custom price quotes and delivery timelines; sales analytics (total sales, best sellers, feedback); artisan bio/contact details. |
| Administrator | Dashboard showing website activity, users, sales, active artisans; manage customers/artisans and suspend/ban accounts; monitor, approve, or reject listings; oversee orders and transactions; manage homepage banners, categories, promotions; configure shipping rates, taxes, and payment gateways. |

### 1.2 Implementation additions (not explicitly stated in assignment)

The following make the specified functionality coherent and secure: account/email verification, password recovery, artisan approval/onboarding, product variants, addresses, shipping calculation, an explicit order state machine, payment and webhook records, notifications, custom-request proposal acceptance, conversation attachments, audit history, seller settlement tracking, returns/cancellations/refunds, rate limits, accessibility, tests, deployment, backup and monitoring.

**Distinction:** These are engineering recommendations, not claims that they are stated in the assignment. Optional extensions are clearly labeled in §19.

### 1.3 Success criteria

1. A new customer can sign up, find an approved in-stock product, pay via an enabled test payment provider, and see an order.
2. A registered artisan can create a listing, submit it for approval, and fulfill a real order after approval.
3. A customer can request a custom design, negotiate with a seller, accept a quote, pay, and track delivery.
4. An admin can moderate marketplace content and manage settings without changing source code.
5. Inventory, payments, permissions, and order statuses remain consistent under retries and concurrent requests.
6. Every major flow functions on mobile, tablet, and desktop and provides loading, empty, error, and success states.

---

## 2. Stakeholders, roles and authorization

| Role | Permissions | Restrictions |
|---|---|---|
| Guest | Browse approved products/categories/artisans, search, read published reviews, add temporary guest-cart items if supported | Cannot checkout or send requests without signing in (policy choice) |
| Customer | Own profile, addresses, wishlist, cart, orders, payments, reviews, requests, chats, notifications | Cannot edit other users, sellers, orders, moderation |
| Artisan | Own shop, own products/media/stock, assigned order items, own quotes/requests, own conversations, analytics | Cannot see another shop's private data; cannot unilaterally capture payments or edit platform settings |
| Admin | Moderate accounts/listings, oversee all orders/transactions, maintain tax/shipping/catalog/content/config, view audit log | Sensitive operations always audited; payment secrets never displayed |

One user may become an artisan while retaining the customer experience. Use a **user ↔ role** association or a clearly defined role policy rather than duplicating accounts. Secure authorization must occur on the server in every action and API route, not merely by hiding UI.

### 2.1 Account and artisan lifecycle

- Customer: `registered -> email_verified -> active`, with `suspended`/`banned` states.
- Artisan: `draft_application -> pending_review -> approved/rejected -> active/suspended`.
- Product: `draft -> pending_approval -> published/rejected -> archived`; edits to approved products that change moderated fields return to approval or are tracked as pending revisions.
- Every transition has a named actor, timestamp, and optional reason.

---

## 3. Technology architecture and stack decisions

### 3.1 Recommended stack

| Layer | Choice | Purpose / notes |
|---|---|---|
| Frontend | Next.js App Router + React + TypeScript | Server-rendered storefront, interactive dashboards, typed routes and forms |
| UI primitives | **shadcn/ui** + Radix primitives + Tailwind CSS | Main custom branded UI, accessible dialogs, menus, forms, cards, tables |
| MUI | Material UI + Material Icons (or Lucide for consistent icon system) | Use for select complex components only, e.g. data-heavy grid and date controls; avoid visually mixing two component systems |
| Style/theme | Tailwind design tokens + CSS variables; one theme map for MUI | Consistent typography, colors, radius, shadows, focus and dark-mode policy |
| Database | PostgreSQL | Relational transactional database, strong constraints and indexing |
| ORM | Prisma (or Drizzle — select one only) | Typed schema, migrations, predictable queries |
| Authentication | Auth.js or a supported equivalent | Credentials and OAuth sessions; password hashing; secure cookies |
| Validation | Zod + React Hook Form | Shared client/server payload validation |
| Data access | Server Components for reads; Server Actions or Route Handlers for mutations | Prefer a single authoritative service layer for business rules |
| Files | S3-compatible object storage / managed media service | Product photos, custom-reference attachments, profile images |
| Payments | Provider abstraction + supported card gateway; PayPal where merchant/location supports it | Webhooks are authoritative; use sandbox; never store card numbers |
| Email | Transactional email provider | Verification, receipts, order and quote notifications |
| Notifications | Persistent in-app notification store; optional email | Unread/read state and event-driven notifications |
| Background jobs | Managed queue/worker or scheduled jobs | Receipt emails, notifications, timeouts, media processing |
| Tests | Vitest/Jest + React Testing Library + Playwright | Unit, integration and end-to-end tests |
| Deployment | Next.js-compatible host + managed PostgreSQL + object storage | Separate dev, staging and production environments |
| Monitoring | Structured logs, error tracking and metrics | Payment failures, webhook errors, performance, suspicious activity |

**Important MUI/shadcn rule:** Make shadcn/ui the default visual foundation. Use MUI only in agreed areas and wrap MUI controls with the same tokens, fonts, colors, spacing, focus style, and radius. Install and configure MUI's Next.js App Router styling integration according to the chosen versions to avoid CSS-in-JS SSR style flashes. Keep a single icon family visible to users (recommended: Lucide), except where a specialized MUI control requires a built-in icon.

### 3.2 System diagram

```text
Browser (guest/customer/artisan/admin)
          |
          v
Next.js App Router (RSC + client components)
          |
          +---- Auth/session and role checks
          |
          +---- Server actions / REST route handlers
                    |
                    v
              Domain service layer
             /       |        |       \
         PostgreSQL  Object   Payment  Email/queue
          + Prisma   storage  gateway  + notifications
                               |
                         Signed webhooks
                               |
                         Payment service
```

### 3.3 Major architectural rules

- Modular monolith initially: one Next.js application, grouped by domain; avoid microservices unless scale demonstrably requires them.
- Server is the source of truth for price, taxes, stock, discounts, totals and access control.
- Revalidate cached pages after catalog changes; never cache private user data globally.
- No sensitive provider keys, database credentials or privileged tokens in client bundles.
- Audit every administrator action and every sensitive financial state change.
- Use database transactions and idempotency keys for payment and order transitions.
- Do not treat an order as paid based only on a browser redirect or client response.

---

## 4. Modern professional design specification

### 4.1 Product aesthetic

**Visual direction:** premium handcrafted boutique marketplace — editorial typography, generous whitespace, crisp photography, authentic maker storytelling, gentle natural colors and restrained motion. Aim for the finish of a real consumer commerce platform, not a generic template or admin theme.

Suggested design tokens (adjust once brand identity is approved):

| Token | Value | Use |
|---|---|---|
| Brand ink | `#20342E` | Headlines, primary CTAs |
| Primary sage | `#4D6C5D` | Links, active navigation, selected filters |
| Warm ivory | `#FAF8F3` | Page background |
| Surface | `#FFFFFF` | Cards, menus, dialogs |
| Clay accent | `#B86D4B` | Editorial highlights, badges (sparingly) |
| Text | `#25302C` | Main body |
| Muted text | `#66716A` | Secondary content |
| Border | `#E4E7E1` | Dividers and inputs |
| Error | `#B42318` | Form and request errors |
| Radius | `12px` cards / `8px` controls | Consistent component shape |
| Spacing | 4/8/12/16/24/32/48/64px scale | Rhythm across layouts |

Fonts: high-contrast serif for editorial headings (e.g. a licensed/web-available serif); clean sans-serif for product details, prices, forms and dashboards. Keep page text readable (body generally 15–16px) with WCAG-conscious color contrast.

### 4.2 Layouts

- **Public storefront:** announcement ribbon (optional), branded header, product search, categories mega-menu, wishlist, account, cart count; persistent useful filters; footer with customer service and policies.
- **Customer account:** sidebar on desktop, stacked/tab navigation on mobile; clear order and message activity.
- **Artisan studio:** distinct seller workspace with navigation for Overview, Products, Orders, Custom Requests, Messages, Analytics and Shop Profile.
- **Admin console:** dedicated admin shell with role-protected navigation, searchable data tables, bulk actions, audit trail and configuration forms.

### 4.3 UI component system

Required reusable components: `SiteHeader`, `MobileNav`, `HeroBanner`, `CategoryTile`, `ProductCard`, `Price`, `RatingStars`, `StockBadge`, `FilterSidebar`, `SortSelect`, `ProductGallery`, `QuantityStepper`, `CartDrawer`, `CheckoutStepper`, `AddressForm`, `PaymentMethodSelector`, `OrderTimeline`, `WishlistButton`, `MakerCard`, `CustomRequestWizard`, `QuoteCard`, `ChatThread`, `NotificationBell`, `DashboardStatCard`, `DataTable`, `ImageUploader`, `ConfirmDialog`, `StatusBadge`, `EmptyState`, `ErrorState`, `Skeleton`, `Pagination`, `Toast`, `Breadcrumbs`.

### 4.4 Interaction quality rules

- All clickable elements have hover, focus-visible, pressed, disabled, and loading states.
- All forms have inline field errors and accessible labels; never lose entered values after validation failure.
- UI has purposeful micro-interactions (150–250ms), respects reduced motion.
- Responsive image crops and aspect ratios are consistent; use optimized images and descriptive alt text.
- No dead links, lorem ipsum in release builds, empty buttons, or incorrect sample totals.
- Keyboard navigation and screen readers work for search, filter drawers, modal dialogs, tables, and checkout.
- Mobile-first breakpoints and horizontal-overflow handling for dashboard tables.
- Feedback is precise: `Added to cart`, `Quote sent`, `Payment pending confirmation`, not ambiguous success messages.

### 4.5 Suggested screens and pages

| Route | Screen | Key UI |
|---|---|---|
| `/` | Homepage | Editorial hero, categories, featured artisans, trending/new products, custom-order CTA |
| `/shop` | Catalog | Search, chips, multi-filter sidebar, sort, product grid, pagination |
| `/categories/[slug]` | Category landing | Category banner, subcategories, product grid |
| `/products/[slug]` | Product detail | Gallery, maker info, options, stock, qty, wishlist, reviews, delivery estimate |
| `/artisans` | Artisan directory | Searchable maker cards |
| `/artisans/[slug]` | Artisan storefront | Bio, cover image, approved products, rating, contact/custom-order CTA |
| `/login`, `/register`, `/forgot-password` | Auth | Validated forms and social OAuth where configured |
| `/wishlist` | Favorites | Saved items and remove/add to cart |
| `/cart` | Shopping cart | Items per seller, totals, quantity changes, remove |
| `/checkout` | Checkout | Addresses, shipping, payment, final order review |
| `/checkout/result` | Payment result | Clear pending/confirmed/failed state, no self-confirmed payment |
| `/account` | Account overview | Profile shortcuts and current activity |
| `/account/profile`, `/account/addresses`, `/account/payments` | Account settings | Update details, shipping addresses, provider-tokenized payment methods |
| `/account/orders`, `/account/orders/[id]` | Order history/details | Seller-specific line items, receipts and tracking timeline |
| `/account/custom-requests`, `/account/custom-requests/new`, `/account/custom-requests/[id]` | Custom jobs | Request form, attachments, quote accept/decline, status |
| `/messages`, `/messages/[threadId]` | Messaging | Seller/customer thread, images, unread badges |
| `/seller` | Seller overview | KPIs, pending actions, recent orders |
| `/seller/onboarding` | Become an artisan | Profile/application + review status |
| `/seller/products`, `/seller/products/new`, `/seller/products/[id]/edit` | Products | CRUD, uploads, variants, stock, moderation status |
| `/seller/orders`, `/seller/orders/[id]` | Fulfillment | Line items, statuses, tracking details |
| `/seller/custom-requests`, `/seller/custom-requests/[id]` | Custom work | Quote, decline, communicate, timeline |
| `/seller/analytics` | Sales dashboard | Sales chart, best sellers, feedback and date filters |
| `/seller/profile` | Shop setup | Banner, avatar, bio, contact/display options |
| `/admin` | Admin overview | Sales/orders/users/artisans; alerts |
| `/admin/users`, `/admin/artisans` | Users & sellers | Search, status control, suspension reasons |
| `/admin/products`, `/admin/products/[id]` | Moderation | Pending queue, approve/reject with reason |
| `/admin/orders`, `/admin/transactions` | Financial supervision | Orders, payment events, refunds, disputes |
| `/admin/categories`, `/admin/banners`, `/admin/promotions` | Content management | CRUD and display ordering |
| `/admin/settings/shipping`, `/admin/settings/taxes`, `/admin/settings/payments` | Platform configuration | Shipping rules, tax rules, provider enablement |
| `/admin/audit-log` | Audit events | Actor, action, entity, timestamp |

Use slugs for public SEO-friendly URLs and opaque IDs for secure records. Never infer authorization from a guessed ID.

---

## 5. Functional requirements — customer

Every requirement below must have a corresponding server behavior, database persistence and acceptance test.

| ID | Requirement | Detailed behavior / acceptance |
|---|---|---|
| C-01 | Register and sign in | Unique email, password rules, secure hash, session, logout, error states; Google/Facebook OAuth only when configured |
| C-02 | Account security | Verify email, reset password, protect private pages, manage active sessions as feasible |
| C-03 | Browse categories | Active categories from database; hide unpublished products |
| C-04 | Search | Search by product title, artisan/shop name, category; sensible partial match and no-results UI |
| C-05 | Filter and sort | Price min/max, average rating, in-stock status; combined filters survive pagination and URL refresh; sort price/recent/popular |
| C-06 | Product detail | Approved product only; correct gallery, details, live price, stock, variations, maker identity and fulfillment expectations |
| C-07 | Reviews | Only verified buyers can review fulfilled/purchased products (recommended); rating 1–5, textual feedback, moderation/reporting |
| C-08 | Wishlist | Add/remove, persist per user, prevent duplicates |
| C-09 | Cart | Add products, change quantity, remove, validate max stock, persist; re-price before checkout |
| C-10 | Checkout | Select/add address, obtain seller-aware shipping, taxes, totals, choose active supported payment method, place order safely |
| C-11 | Confirmation | Show order reference and order details after successful order placement; payment status is separate from order creation |
| C-12 | Order tracking | View processing/shipped/delivered and other necessary states; show shipment/tracking reference if entered |
| C-13 | Notifications | In-app notification for order changes; email where enabled; user read/unread state |
| C-14 | Profile | Update name, contact, addresses; view historical orders |
| C-15 | Saved payment method | Save/remove **provider tokens only**, subject to provider capability and customer consent |
| C-16 | Custom-design form | Select artisan, item idea, specifications, quantity, budget, requested date, reference images, special notes |
| C-17 | Direct communication | Authenticated customer can communicate in a thread linked to an artisan and optionally a custom request |
| C-18 | Quote handling | View seller estimate, shipping, timeline, revisions and expiration; accept quote to initiate payable order |

### 5.1 Catalog details

- Product fields: name, slug, description, artisan, category, images, price/currency, stock, status, materials, dimensions, production time, shipping weight (where needed), tags, variants/options, created/updated dates.
- Search filter query parameters: `q`, `category`, `artisan`, `minPrice`, `maxPrice`, `rating`, `inStock`, `sort`, `page`.
- Catalog query must **always** enforce `published` plus seller-active visibility.
- Store and display a numeric average rating derived from published reviews; define how unrated products are handled.
- Avoid overselling if multiple users buy the last item simultaneously.

### 5.2 Cart and multi-artisan checkout policy

The marketplace permits a cart with items from **multiple artisans**. At checkout, create a parent marketplace order plus **seller-specific suborders** (or order groups) so each artisan can independently fulfill their share. Calculate seller-specific shipping, taxes and fulfillment status, while showing the customer an aggregated order.

**Payment policy:** Prefer a single customer charge through a marketplace-capable provider, plus tracked seller liabilities and payout/settlement records. Not every payment processor supports split payouts, escrow, or all countries. Confirm merchant country, capabilities, and legal obligations before implementing live disbursement. If this is only an assignment/demo, use a clearly labeled **sandbox checkout** and simulate payouts as internal ledger records—not real transfers.

### 5.3 Customer payment behavior

1. Display a **server-calculated** order review and reserve available stock or validate atomically on order creation.
2. Create `pending_payment` order and one payment attempt with a unique idempotency key.
3. Redirect to/provider-hosted checkout or securely tokenize card details (do not collect or store raw card data).
4. Verify provider webhook signature and event idempotency before moving payment to `succeeded`.
5. On success, confirm order and decrement/reserve stock exactly once according to chosen inventory policy.
6. On failure/expiration, release stock holds and allow safe retry, not duplicate order creation.
7. Send receipt and seller notification from a durable background job or event handler.

---

## 6. Functional requirements — artisan / seller

| ID | Requirement | Detailed behavior / acceptance |
|---|---|---|
| S-01 | Seller registration | Existing verified customer may apply; standalone registration path may lead to same account; approval-gated seller access |
| S-02 | Shop profile | Create/update display name, unique slug, bio, logo, cover, visible contact information and fulfillment preferences |
| S-03 | Product management | Add/edit/archive products; upload and reorder images; set descriptions, category, price, materials/options |
| S-04 | Inventory | Maintain stock by product/variant; update availability; cannot set negative stock; low-stock warnings |
| S-05 | Listing moderation | Submit new/edited items for admin review; see approved, pending and rejected states/reasons |
| S-06 | Order management | View only own seller suborders, customer shipment details as needed, fulfill items and update allowed states |
| S-07 | Custom requests | Review incoming requests and attachments; accept for quotation or decline with explanation |
| S-08 | Quotes | Send priced quote with details, currency, shipping, estimated completion/delivery, validity and revision number |
| S-09 | Communication | Reply to customers in authorized conversations; keep message history |
| S-10 | Sales analytics | Gross sales, net of refunds where configured, order count, best-selling products, customer feedback; date filters |
| S-11 | Seller notifications | New order, request, quote response, new message, rejection, low stock |

### 6.1 Seller order status permissions

- `pending_payment`: visible read-only; must not dispatch unpaid goods.
- `paid -> processing`: artisan acknowledges/prepares the order.
- `processing -> shipped`: artisan must supply carrier/tracking when applicable; some local orders may use delivery confirmation policy.
- `shipped -> delivered`: preferably confirmed by fulfillment integration/admin/customer under agreed policy; seller cannot arbitrarily mark financial settlement.
- Cancellations and refunds require explicit rules tied to shipment state, admin policy and payment processor.
- All changes create immutable history records; send corresponding customer notifications.

---

## 7. Functional requirements — administrator

| ID | Requirement | Detailed behavior / acceptance |
|---|---|---|
| A-01 | Admin dashboard | Real totals for customers, sellers, active listings, orders, GMV/sales; correct selectable date range |
| A-02 | User management | Search/filter customers and artisans; view profiles, suspend/ban/unban with reason; preserve history |
| A-03 | Seller approval | Review artisan applications and approve/reject with reason (recommended operational addition) |
| A-04 | Listing moderation | Review pending product changes, approve/reject with reason; unpublished items excluded from storefront |
| A-05 | Order oversight | View orders across sellers, state histories, customer/seller and shipment info with access logging |
| A-06 | Transaction oversight | Payment attempts, success/failure, refunds, event histories, payout status; no secret or raw payment data |
| A-07 | Categories | CRUD, slug uniqueness, active state, display order, optional parent category/image |
| A-08 | Banners/content | Manage homepage hero/campaign title, image, CTA URL, scheduling/publish state |
| A-09 | Promotions | Create active dates, discount rules, usage limits and eligibility checks |
| A-10 | Shipping settings | Manage configurable shipping zones, shipping rates, price/weight rules, free shipping threshold where supported |
| A-11 | Tax settings | Configure jurisdiction-appropriate tax rules/rates, effective dates, inclusive/exclusive behavior |
| A-12 | Payment settings | Enable supported payment providers and display public config; secrets only in encrypted environment/secret manager |
| A-13 | Audit log | Track staff changes to accounts, listings, prices, promotions, shipping/tax and payment configuration |

**Admin finance definitions:** `GMV` = value of paid orders before refunds (choose consistent tax/shipping inclusion); `net sales` = paid merchandise totals minus refunds; `platform revenue` = commissions/fees only if actually modeled. Do not label GMV as company profit.

---

## 8. Custom-made design requests: complete workflow

The assignment specifically requires custom design specifications, buyer–seller communication, accept/decline, price estimates, and delivery timelines. Implement as a real state machine.

```text
Customer submits request
        |
        v
SUBMITTED --> Seller DECLINED --> CLOSED
        |
        v
UNDER_REVIEW <--> NEEDS_CLARIFICATION (messages / revisions)
        |
        v
QUOTED (price + estimated timeline + expiry)
   |        |              |
   |        |              +--> EXPIRED
   |        +--> Customer requests changes --> UNDER_REVIEW
   v
ACCEPTED --> PENDING_PAYMENT --> PAID / IN_PRODUCTION
                                      |
                                      v
                              SHIPPED --> COMPLETED
```

### 8.1 Required form fields

Target artisan, craft/category, title, detailed specifications, requested size/material/colors, quantity, budget range (optional), desired date, delivery address/region (when needed), up to a configured number of reference images, and extra notes. Validate image type, size and count on both client and server; store uploads privately until authorized.

### 8.2 Quote and conversion rules

- Quotes include line-item amount, shipping estimate, taxes (as configured), total, estimated completion/delivery, revision number, expiration and seller comments.
- Only the selected customer can accept a quote. Acceptance locks the accepted revision and prevents retroactive editing.
- Quote acceptance creates a linked **custom order** at the locked server-side price; successful payment then unlocks production.
- Each quote and status transition is timestamped. Expired/declined requests are never purchasable.
- A request can have a dedicated chat thread. Both parties receive notifications for replies and quote changes.
- Seller cannot access requests assigned to other artisans; customer cannot access another customer's requests.

---

## 9. Database design (PostgreSQL)

All primary keys use UUID/CUID-style opaque identifiers; every main table has `created_at`, `updated_at` as appropriate. Apply foreign keys, unique constraints, check constraints and transactional updates.

| Table | Important fields | Relations / constraints |
|---|---|---|
| `users` | id, name, email, email_verified_at, password_hash(nullable for OAuth), phone, status | Unique normalized email |
| `accounts` | user_id, provider, provider_account_id, token references | OAuth account mappings |
| `sessions` | id, user_id, expires_at | Secure sessions if database-backed |
| `user_roles` | user_id, role | Unique user+role; roles CUSTOMER, ARTISAN, ADMIN |
| `addresses` | user_id, label, recipient, phone, street, city, region, postal_code, country, is_default | Owner-only access |
| `artisan_profiles` | user_id, shop_name, slug, bio, logo_url, cover_url, contact_display, status | Unique user and shop slug |
| `artisan_applications` | user_id, status, submitted_at, reviewed_by, review_reason | Approval audit |
| `categories` | id, parent_id, name, slug, description, image_url, active, sort_order | Unique slug; nested categories optional |
| `products` | artisan_id, category_id, name, slug, description, base_price, currency, material, status, rating_avg, review_count | Approved-public visibility |
| `product_images` | product_id, storage_key, alt_text, sort_order | Ordered media |
| `product_variants` | product_id, sku, attributes_json, price_override, stock_qty, active | SKU unique per seller; stock >= 0 |
| `inventory_reservations` | variant_id, order_id, quantity, expires_at, status | Prevent overselling under concurrency |
| `wishlists` | user_id, product_id | Unique pair |
| `carts` | user_id or guest_session_key, currency | One active cart per identity |
| `cart_items` | cart_id, product_variant_id, quantity | Unique cart+variant; positive qty |
| `orders` | customer_id, order_number, currency, subtotal, shipping_total, tax_total, discount_total, grand_total, payment_status, status | Unique order number; server-calculated snapshot |
| `seller_orders` | order_id, artisan_id, status, subtotal, shipping, tax, discount, total, tracking_no, carrier | One per seller in parent order; independent fulfillment |
| `order_items` | seller_order_id, product_id(nullable after archival), variant_id, name_snapshot, sku_snapshot, unit_price, qty, line_total, custom_request_id(nullable) | Immutable purchase snapshot |
| `order_status_history` | order_id/seller_order_id, from_status, to_status, actor_id, note, timestamp | Append-only history |
| `payments` | order_id, provider, provider_reference, amount, currency, status, idempotency_key | Unique provider ref / key |
| `payment_events` | provider, provider_event_id, payment_id, event_type, verified_at, payload_safe | Unique provider+event ID |
| `refunds` | payment_id, order_id, amount, reason, provider_reference, status | Cannot exceed captured total |
| `seller_settlements` | seller_order_id, amount_due, fees, state, provider_transfer_ref | Use test-only ledger when payouts unsupported |
| `reviews` | user_id, product_id, order_item_id, rating, body, status | Rating 1–5; prevent duplicate verified review |
| `custom_requests` | customer_id, artisan_id, category_id, title, specs_json, budget, requested_date, status | Role-restricted |
| `custom_request_attachments` | request_id, storage_key, filename, mime_type | Private by default |
| `custom_quotes` | request_id, artisan_id, revision, subtotal, shipping, tax, total, currency, estimated_days, expires_at, status | Unique request+revision |
| `conversations` | id, customer_id, artisan_id, custom_request_id(nullable), last_message_at | Participant-only |
| `messages` | conversation_id, sender_id, body, attachment_key(nullable), read_at | sender must be participant |
| `notifications` | user_id, type, title, body, target_url, read_at | Query by recipient |
| `promotions` | code, type, value, starts_at, ends_at, usage_limit, active | Server validated |
| `promotion_redemptions` | promotion_id, user_id, order_id | Controls usage limits |
| `banners` | title, subtitle, image_key, cta_label, cta_url, sort_order, active, publish_window | Admin managed |
| `shipping_zones` | name, supported_regions_json, active | Defined coverage |
| `shipping_rules` | zone_id, method, rate, min/max_weight, threshold, seller_id(nullable) | Nonnegative rate |
| `tax_rules` | country, region, rate, inclusive, effective_from/to, active | Resolve by address/date |
| `platform_settings` | key, value_json, updated_by | Non-secret configuration only |
| `audit_logs` | actor_id, action, entity_type, entity_id, before_json, after_json, ip_safe, created_at | Restricted admin visibility |

### 9.1 Critical indexes

- `products(status, category_id, created_at)`, `products(artisan_id, status)`, full-text/search index for product titles/descriptions as appropriate.
- `product_variants(product_id, active)`; index `stock_qty` if inventory queries need it.
- `orders(customer_id, created_at DESC)`, `seller_orders(artisan_id, status, created_at)`.
- `custom_requests(artisan_id, status, created_at)` and `(customer_id, created_at)`.
- `messages(conversation_id, created_at)`; `notifications(user_id, read_at, created_at)`.
- `payments(provider, provider_reference)` and unique `payment_events(provider, provider_event_id)`.

### 9.2 Money/inventory correctness

- Store money in **integer minor units** plus currency (e.g., cents/paisa) or fixed-precision decimals; never JavaScript float arithmetic for totals.
- Store purchased price, tax and shipping snapshots at order creation, not read live product values on history pages.
- Implement checkout inventory mutation in a **database transaction with row locking or conditional stock updates**. Test two buyers buying the last available unit.
- Implement stock release on expired/failed payment, with scheduled cleanup that is idempotent.
- Multi-vendor financial totals must reconcile: sum(seller order totals) = parent order total, with clearly allocated discounts/shipping/tax.

---

## 10. API and server-action contract

Choose a **single convention**: JSON `app/api/...` route handlers for external-facing endpoints, with server actions for narrowly scoped form mutations if useful. Both must call the same authorization/validation/domain-service functions. The table gives logical endpoints; implement route handlers only where needed rather than duplicate actions.

**Common rules:** authenticated cookies/session, CSRF protection where applicable, Zod validation, authorization per resource, stable error codes, rate limiting on auth/search/messaging, pagination and cursor/page limits. Return consistent JSON `{ data, error, meta }`; never expose hashes or payment secrets.

| Domain | Method + endpoint | Authorized use |
|---|---|---|
| Auth | `POST /api/auth/register` | Register; verification; Auth.js OAuth endpoints handled by auth framework |
| Profile | `GET/PATCH /api/me`, `GET/POST /api/me/addresses` | Self profile and address CRUD |
| Catalog | `GET /api/products`, `GET /api/products/:slug`, `GET /api/categories` | Public approved inventory |
| Artisans | `GET /api/artisans`, `GET /api/artisans/:slug` | Public approved shops |
| Reviews | `GET/POST /api/products/:id/reviews` | Public read; verified buyer create |
| Wishlist | `GET/POST/DELETE /api/me/wishlist` | Customer only |
| Cart | `GET/POST/PATCH/DELETE /api/cart/items` | Own cart only |
| Checkout | `POST /api/checkout/quote`, `POST /api/checkout/create` | Server calculates and creates pending order/payment |
| Payment | `POST /api/webhooks/:provider` | Signature-validated provider callbacks; idempotent |
| Orders | `GET /api/me/orders`, `GET /api/me/orders/:id` | Customer's own orders |
| Custom | `POST/GET /api/custom-requests`, `GET /api/custom-requests/:id` | Request participants |
| Quotes | `POST /api/custom-requests/:id/quotes`, `POST /api/quotes/:id/accept` | Assigned seller / owning customer |
| Messaging | `GET/POST /api/conversations/:id/messages` | Participants only |
| Notifications | `GET /api/me/notifications`, `PATCH /api/me/notifications/:id` | Recipient only |
| Seller products | `GET/POST /api/seller/products`, `PATCH/DELETE /api/seller/products/:id` | Approved seller owns resource |
| Seller orders | `GET /api/seller/orders`, `PATCH /api/seller/orders/:id/status` | Own seller suborders, allowed state transition |
| Seller reports | `GET /api/seller/analytics?from=&to=` | Own aggregated data |
| Admin moderation | `GET /api/admin/products/pending`, `POST /api/admin/products/:id/decision` | Admin only, audited |
| Admin accounts | `GET /api/admin/users`, `POST /api/admin/users/:id/status` | Admin only, audited |
| Admin content | CRUD `/api/admin/categories`, `/api/admin/banners`, `/api/admin/promotions` | Admin only |
| Admin config | `GET/PATCH /api/admin/settings/shipping|taxes|payments` | Admin only, no raw gateway secrets |
| Admin oversight | `GET /api/admin/orders`, `GET /api/admin/transactions`, `GET /api/admin/analytics` | Admin only |
| Uploads | `POST /api/uploads/sign`, `POST /api/uploads/finalize` | Scoped signed upload URLs; validate ownership and MIME |

**Use real-time messaging only if needed:** polling/refresh works for basic assignment compliance; for a premium experience use a managed realtime service or SSE with scoped subscriptions and correct reconnect/unread behavior. Do not ship a cosmetic chat with locally stored messages only.

### 10.1 Example canonical checkout request

```json
{
  "shippingAddressId": "uuid",
  "billingAddressId": "uuid",
  "shippingMethodSelections": [
    { "artisanId": "uuid", "methodId": "standard" }
  ],
  "promotionCode": "HANDMADE10",
  "paymentProvider": "configured-provider",
  "idempotencyKey": "client-generated-uuid"
}
```

**Do not accept authoritative item prices or grand total from the browser.** Load the cart server-side and compute prices, availability, discounts, taxes and shipping there.

### 10.2 Standard error codes

`UNAUTHENTICATED`, `FORBIDDEN`, `VALIDATION_ERROR`, `NOT_FOUND`, `OUT_OF_STOCK`, `PRICE_CHANGED`, `INVALID_STATE_TRANSITION`, `QUOTE_EXPIRED`, `PAYMENT_FAILED`, `RATE_LIMITED`, `CONFLICT`, `INTERNAL_ERROR`.

---

## 11. Full customer journeys and acceptance conditions

### 11.1 Standard product purchase

1. Guest opens homepage/category and filters catalog.
2. Guest views published product and in-stock variant.
3. Customer logs in/registers; chosen cart items remain accessible after authentication (if guest cart supported).
4. Customer adds items from two different artisans.
5. Cart displays seller grouping, correct quantities and server-backed estimated totals.
6. Checkout collects address and shipping method per seller and shows final totals.
7. Test payment succeeds; signed webhook confirms payment exactly once.
8. Customer sees order confirmation; each seller sees only their part of the order.
9. Sellers process and ship; customer sees status history and notification.
10. After eligible delivery, customer can leave a review for purchased product.

**Pass:** Inventory reduced once, order money reconciles, both seller orders are isolated, notifications appear, and repeat webhook delivery does not duplicate orders or stock movements.

### 11.2 Custom design purchase

1. Customer opens artisan page and starts a custom request.
2. Customer adds instructions, quantity, dates and reference attachment.
3. Artisan receives notification and reviews request.
4. Artisan asks a question via chat; customer replies.
5. Artisan submits an estimate and timeline.
6. Customer accepts the latest unexpired quote.
7. A linked custom order is created; checkout collects payment.
8. Artisan sees work status, marks production/shipping progress; customer tracks order.

**Pass:** Quote terms remain immutable after acceptance, payment references the correct custom order, and third parties cannot access the request/messages.

### 11.3 Moderation and account restriction

1. Artisan creates new product — it appears as pending, not publicly discoverable.
2. Admin approves — product becomes searchable and purchasable.
3. Admin rejects edited listing with a reason — seller sees the reason and can resubmit.
4. Admin suspends an artisan — their public purchasable listings become unavailable; existing paid orders remain administratively manageable.

**Pass:** no route/API reveals rejected items publicly; every admin decision is audited.

---

## 12. Payments, shipping, taxes and operational rules

### 12.1 Payment methods

- The assignment cites **credit card and PayPal** as examples. Actual payment providers depend on merchant country and gateway eligibility. Evaluate the supported gateway(s) and sandbox availability before wiring production checkout.
- Implement provider-agnostic contracts: `createCheckout`, `verifyWebhook`, `getPayment`, `refundPayment`, `listSavedMethods` (if supported).
- Only enable UI choices that are backed by a configured provider. For unsupported methods show neither clickable options nor pretend success.
- Store transaction IDs and masked provider metadata, not raw card numbers/CVV.
- Display clearly whether payment is `pending`, `succeeded`, `failed`, `refunded`, or `partially_refunded`.

### 12.2 Shipping

- Rates can vary by zone, seller, order weight/value, and shipping method.
- The admin owns base shipping configuration; seller-specific overrides only if authorized by a clear policy.
- Multi-seller orders can have multiple parcels and tracking numbers.
- Shipping estimate shown before payment must be calculated server-side.
- If no carrier API exists, sellers can enter carrier/tracking details manually; admin can audit changes.

### 12.3 Taxes

- Tax jurisdiction depends on customer/delivery location, merchant obligations and applicable law. Admin-configurable rates do not substitute for legal/tax advice.
- Record tax calculation inputs, effective rule and amount on order snapshot.
- State explicitly whether listed prices include tax and how discounts impact taxable bases.

### 12.4 Refunds and cancellation (recommended extension)

- Document who may cancel at each state and whether custom-made items are refundable.
- Admin-mediated refunds use payment-provider API, are idempotent and update immutable financial records.
- Stock restoration for canceled/unshipped orders must be explicit and performed once.

---

## 13. Security, privacy, accessibility, performance

### 13.1 Security controls

- Server-side RBAC + ownership checks on **every** protected read and write; deny by default.
- Passwords hashed with a modern password hashing algorithm through a trustworthy auth implementation; safe reset tokens and email verification.
- Cookies `HttpOnly`, `Secure` in production, appropriate `SameSite`; CSRF defenses for cookie-authenticated mutations.
- Rate limits for authentication, password reset, messaging, reviews, upload signing and sensitive admin endpoints.
- Validate and sanitize all user content; safely render rich text, if allowed; protect against XSS, SQL injection, SSRF and unsafe file uploads.
- Signed upload URLs, upload content-type/size validation, private custom attachments and media scanning if available.
- Verify webhook signatures with raw payload requirements; deduplicate by provider event ID.
- Never keep gateway secrets in DB config managed through ordinary admin UI; use secret manager/environment.
- Separate permissions for admin actions, audit changed values without leaking secrets, protect logs and backups.
- For production, ensure privacy policy, data retention/deletion rules, consent and merchant legal requirements are addressed.

### 13.2 Non-functional targets (engineering proposals)

| ID | Target / measurement |
|---|---|
| NFR-01 | Responsive at 360px, 768px, 1024px, 1440px and wide desktop |
| NFR-02 | Core storefront content and navigation remain usable without client-side JavaScript where practical; interactive checkout explicitly requires JS |
| NFR-03 | WCAG 2.2 AA-aligned keyboard use, accessible names, sufficient contrast, error announcements |
| NFR-04 | Aim for Core Web Vitals: LCP <= 2.5s, INP <= 200ms, CLS <= 0.1 at 75th percentile on representative production traffic |
| NFR-05 | Paginate list views; use optimized images; avoid N+1 database queries |
| NFR-06 | Auth and authorization tests show no cross-account data access |
| NFR-07 | Payment webhook retries produce no duplicate capture/order/stock mutation |
| NFR-08 | Application has backups, migration rollback strategy, error monitoring and documented incident recovery |
| NFR-09 | Admin and seller reports accurately reflect paid transactions and refunds |
| NFR-10 | No client-visible sensitive credentials; production secrets separated by environment |

---

## 14. Suggested Next.js project structure

```text
handmade-crafts-store/
├── app/
│   ├── (storefront)/
│   │   ├── page.tsx
│   │   ├── shop/page.tsx
│   │   ├── products/[slug]/page.tsx
│   │   ├── categories/[slug]/page.tsx
│   │   └── artisans/[slug]/page.tsx
│   ├── (auth)/login/ ... register/ ... forgot-password/
│   ├── (customer)/account/ ... cart/ ... checkout/ ... wishlist/ ... messages/
│   ├── (seller)/seller/ ...
│   ├── (admin)/admin/ ...
│   ├── api/ ...
│   ├── layout.tsx
│   ├── globals.css
│   ├── not-found.tsx
│   └── error.tsx
├── components/
│   ├── ui/                 # shadcn components
│   ├── storefront/
│   ├── commerce/
│   ├── seller/
│   ├── admin/
│   └── shared/
├── features/
│   ├── auth/
│   ├── catalog/
│   ├── cart/
│   ├── checkout/
│   ├── orders/
│   ├── artisan/
│   ├── custom-requests/
│   ├── messaging/
│   ├── reviews/
│   ├── payments/
│   ├── notifications/
│   └── admin/
│       # each domain: schemas, service, repository, actions, tests
├── lib/
│   ├── db.ts
│   ├── auth.ts
│   ├── permissions.ts
│   ├── money.ts
│   ├── storage.ts
│   ├── payments/
│   ├── email/
│   └── errors.ts
├── prisma/
│   ├── schema.prisma
│   ├── migrations/
│   └── seed.ts
├── styles/tokens.css
├── tests/e2e/
├── public/
├── .env.example
├── next.config.ts
├── package.json
└── README.md
```

Route-group names do not appear in URLs. Put permission checks in layouts for user experience **and** in every protected service/API for real enforcement. Keep shared components small; do not place business logic inside page JSX.

---

## 15. Build roadmap — dependencies and deliverables

Follow this order to minimize rework and ensure each phase produces working functionality.

### Phase 0 — Architecture and product decisions

- [ ] Confirm brand identity, target country/currency, shipping geography and language.
- [ ] Decide merchant/payment gateway capabilities, PayPal eligibility, sandbox options and payout policy.
- [ ] Decide multi-artisan checkout and settlement approach (recommended above).
- [ ] Finalize order, custom-request and moderation state machines.
- [ ] Convert this SRS into issue tracker epics and atomic tasks.

**Exit gate:** No unresolved critical checkout/payment model ambiguity.

### Phase 1 — Foundation and professional UI system

- [ ] Initialize Next.js TypeScript App Router project and lint/format configuration.
- [ ] Install Tailwind, shadcn/ui, scoped MUI integration, Lucide icons, form libraries.
- [ ] Establish tokens, typography, spacing, buttons, forms, cards, modal and alert styles.
- [ ] Implement global storefront, seller and admin responsive shells.
- [ ] Build navigation, footer, loading skeletons, empty/error states, image pipeline.
- [ ] Set up PostgreSQL, ORM, first migration, seed scripts and environment validation.

**Exit gate:** Polished homepage and shells render consistently on desktop/mobile; database migration runs cleanly.

### Phase 2 — Identity and access

- [ ] Email/password registration/login/logout, verification, reset password.
- [ ] Google/Facebook sign-in through real configured OAuth applications.
- [ ] Customer profile/address forms.
- [ ] Seller application and approval workflow.
- [ ] Role-aware route guards, ownership checks, and security tests.

**Exit gate:** Guest/customer/seller/admin access boundaries enforced on server.

### Phase 3 — Catalog, artisan storefronts and moderation

- [ ] Admin category CRUD and banner content management.
- [ ] Artisan shop profile, seller product create/edit/archive and secure image uploads.
- [ ] Variant stock, listing submission and admin approval/rejection.
- [ ] Public category/search/filter/sort pages, product details, artisan directory/profiles.
- [ ] Wishlist and product reviews with verified-purchase rules.

**Exit gate:** A moderated artisan product can be found, viewed and favorited; unpublished items stay private.

### Phase 4 — Cart, checkout and orders

- [ ] Persistent cart, quantity validations and seller grouping.
- [ ] Shipping/tax configuration and server-side price calculation.
- [ ] Checkout flow with address, shipping, promotions, order snapshot and inventory protection.
- [ ] Payment provider sandbox, signed webhooks, retries, failure handling.
- [ ] Parent/seller orders, history, tracking and notification system.
- [ ] Seller order fulfillment, admin order/transaction overview.

**Exit gate:** Real sandbox purchase through multi-seller cart completes and reconciles correctly.

### Phase 5 — Custom orders and messaging

- [ ] Custom request wizard with private reference image uploads.
- [ ] Seller inbox/request decisions and scoped threaded messages.
- [ ] Versioned quote, revision, expiry, customer acceptance.
- [ ] Convert accepted quote to payable custom order with immutable terms.
- [ ] Custom order fulfillment status and notifications.

**Exit gate:** Fully paid custom order flows from specification to fulfillment with preserved history.

### Phase 6 — Analytics, controls and operational quality

- [ ] Seller sales charts, best sellers and reviews feedback.
- [ ] Admin user/seller controls, category/banner/promotion/config pages.
- [ ] Admin sales/transactions dashboard and audit trail.
- [ ] Refund/cancellation policies and workflows as approved.
- [ ] Email templates, background jobs, monitoring, backup and recovery runbooks.

**Exit gate:** Seller/admin dashboards derive from actual transactions; no hard-coded statistics.

### Phase 7 — Test, harden and release

- [ ] Unit tests for totals, state machines, validators and permission checks.
- [ ] Integration tests for PostgreSQL constraints, inventory races, webhooks and moderation.
- [ ] Playwright E2E for main journeys across 3 roles and mobile viewports.
- [ ] Accessibility audit, security review, performance audit, SEO metadata.
- [ ] Staging demo with realistic seed data, test provider and example artisan accounts.
- [ ] Production migrations, provider keys, domain/HTTPS, alerts, backups and deployment checklist.

**Exit gate:** All critical acceptance tests pass; production configuration has no dummy payment or open admin access.

---

## 16. Detailed implementation backlog (epics)

| Epic | Priority | Must-deliver tickets |
|---|---|---|
| E01 Foundation | P0 | Repo/config, environment schema, UI tokens, layouts, DB migrations, CI |
| E02 Identity | P0 | Credentials, OAuth, verified email, password reset, RBAC, profiles, seller onboarding |
| E03 Catalog | P0 | Categories, seller CRUD, images, variants, stock, moderation, search/filter, product detail |
| E04 Customer commerce | P0 | Wishlist, cart, addresses, checkout quote, order creation, payment, order history |
| E05 Fulfillment | P0 | Seller suborders, allowed status transitions, tracking, order notifications |
| E06 Custom requests | P0 | Request form, upload, artisan review, chat, quotes, acceptance, payment conversion |
| E07 Admin | P0 | Dashboard, user management, product moderation, transaction/order oversight, site settings |
| E08 Analytics | P1 | Seller revenue, best sellers, ratings, date filters; admin KPI definitions |
| E09 Operational | P1 | Email, audits, refunds, retries, rate limiting, background jobs, monitoring |
| E10 Quality | P0 | Automated tests, security, WCAG, responsive QA, production readiness |

**P0** = essential for end-to-end assignment acceptance. **P1** = necessary for a robust release. Within each epic, implement backend and real DB behavior before marking matching screens complete.

---

## 17. Test plan

### 17.1 Unit tests

- Price/discount/tax/shipping arithmetic with minor-unit rounding and multiple sellers.
- Stock boundaries (`0`, `1`, simultaneous requests, invalid quantity).
- Product moderation and custom quote state machines reject illegal transitions.
- Permission helper: role + resource ownership.
- Input validation including filenames, upload size/type and duplicate promo usage.

### 17.2 Integration tests

- Register/login/session renewal/logout; OAuth identity linking.
- Artisan creates pending product; admin decision controls public visibility.
- Checkout creates one order with separate seller suborders and immutable line snapshots.
- Webhook signature rejection, replay deduplication, delayed/out-of-order events.
- Unpaid/expired order releases stock correctly.
- Custom quote acceptance creates exactly one linked payable order.
- Unauthorized customer/seller cannot access different users' requests, chats or orders.
- Suspension prevents new listings/checkouts where policy requires.

### 17.3 End-to-end test matrix

| Scenario | Guest | Customer | Artisan | Admin |
|---|---|---|---|---|
| Browse catalog/search/filter | Yes | Yes | Yes | Yes |
| Add wishlist and purchase | Login required | Yes | If also customer | Not through admin role by default |
| Create product | No | No | Own shop | Moderation, not seller impersonation |
| Approve/reject listing | No | No | No | Yes |
| Send custom request | Login required | Yes | If also customer | No by default |
| Respond/quote custom request | No | No | Own assigned requests | Oversee under policy |
| Update fulfillment | No | No | Own seller order | Override only with audit/policy |
| Edit payment/tax/shipping settings | No | No | No | Yes |

### 17.4 Mandatory release tests

- [ ] Checkout zero-quantity, negative-quantity, stale-price and out-of-stock failures handled.
- [ ] Payment retry and duplicate webhook do not double charge or decrement twice.
- [ ] Cross-tenant security tests pass for private resources and file downloads.
- [ ] Product image failures, network interruptions and empty catalogs have deliberate UI.
- [ ] Mobile checkout uses readable touch targets and no horizontal overflow.
- [ ] Admin suspension/rejection actions require confirmation and create audit records.
- [ ] Public pages have titles, metadata, canonical URLs where useful, and sitemap/robots handling.
- [ ] No real payment credentials or sensitive `.env` files committed.

---

## 18. Environment, setup and deployment plan

### 18.1 Example environment contract

```dotenv
# DATABASE_URL=postgresql://... (server only)
# AUTH_SECRET=... (server only)
# AUTH_URL=https://your-domain.example
# GOOGLE_CLIENT_ID=...
# GOOGLE_CLIENT_SECRET=...
# FACEBOOK_CLIENT_ID=...
# FACEBOOK_CLIENT_SECRET=...
# STORAGE_ENDPOINT=...
# STORAGE_BUCKET=...
# STORAGE_ACCESS_KEY_ID=...
# STORAGE_SECRET_ACCESS_KEY=...
# PAYMENT_PROVIDER=...
# PAYMENT_SECRET_KEY=...
# PAYMENT_WEBHOOK_SECRET=...
# EMAIL_API_KEY=...
# NEXT_PUBLIC_SITE_URL=https://your-domain.example
```

This is a *template*, not a requirement to enable every provider. Do not expose `DATABASE_URL`, auth, storage or payment secrets with the `NEXT_PUBLIC_` prefix.

### 18.2 Local and deployed environments

1. Create source repository and protected main branch; use feature branches/PR reviews.
2. Provision separate development and staging PostgreSQL databases.
3. Use migration files committed to source control; deploy migrations before application rollout with rollback plan.
4. Create bucket/media storage with correct private/public policy, permitted CORS and upload limits.
5. Configure OAuth redirect URIs for local/staging/production.
6. Configure sandbox gateway and webhook endpoint; use provider event replay tools to test retries.
7. Seed categories, demo artisans, approved/pending products, customers, orders and banners in non-production only.
8. Configure admin bootstrap via explicit one-time server-side process; never grant admin based on a client field or public signup.
9. Add CI checks: typecheck, lint, tests, migration verification and production build.
10. Deploy staging, run E2E smoke tests, configure backups and error alerts before production launch.

### 18.3 Demonstration data

For assignment demonstration include at least: 5 craft categories, 3 approved artisans, 15–20 real-looking approved product records with images, 2 pending listings, in-stock and sold-out variants, one test customer with a wishlist/cart, one paid multi-seller order, one custom quote accepted into a paid order, and a pending admin moderation case. Use permission-safe demo credentials provided outside public client code.

---

## 19. Clearly optional enhancements (after assignment completion)

- Recommendations based on shopping behavior, advanced faceted search engine.
- Live typing indicators, push notifications, video consultations.
- Customer photo reviews, artisan verification badges, maker stories/blog.
- Coupons by artisan, gift cards, loyalty points, internationalization/multi-currency.
- Shipping carrier API integration, automated tax engine, marketplace vendor payouts.
- AI-assisted product descriptions or visual custom-design previews.

Do **not** let these distract from implementing the assignment's customer, artisan and admin requirements first.

---

## 20. Definition of done for each feature

A ticket is complete only if:

- [ ] UI matches approved responsive design, including loading/empty/error/success/disabled states.
- [ ] Database schema and migrations exist where necessary; no essential data stored only in browser memory.
- [ ] Input validation exists server-side (and client-side for usability).
- [ ] Authentication, role checks and ownership rules are enforced.
- [ ] Relevant API/action returns structured errors and success responses.
- [ ] Unit/integration/E2E tests cover happy path and material failure cases.
- [ ] User-visible notifications and feedback are truthful.
- [ ] Sensitive actions are logged/audited; no accidental data leakage.
- [ ] Product uses real data and the feature works after reload and on another device/session.
- [ ] Documentation includes setup and a working manual QA scenario.

---

## 21. Final acceptance checklist mapped to the assignment

| Assignment item | Implemented by | Verification |
|---|---|---|
| Customer registration/email + social login | C-01/C-02, E02 | Register and OAuth E2E |
| Browse categories/search/filter | C-03 to C-05, E03 | Combined search/filter scenario |
| Product details/reviews/ratings/stock | C-06/C-07, E03 | Public listing + buyer review |
| Custom requests and direct chat | C-16 to C-18, E06 | Complete quote journey |
| Shopping cart, checkout and payment | C-09 to C-11, E04 | Sandbox paid order and webhook replay |
| Order tracking and notifications | C-12/C-13, E05 | Ship status appears in customer account |
| Wishlist/profile/orders/payment methods | C-08/C-14/C-15 | Persistence and tokenized method test |
| Seller account/product/stock management | S-01 to S-05 | Pending -> approved product journey |
| Seller orders/custom quoting/chat | S-06 to S-09 | Seller scoped status/quote tests |
| Seller sales analytics and bio | S-10/S-11, shop profile | Real transaction report and profile |
| Admin dashboard and user moderation | A-01 to A-03 | KPIs and suspended account test |
| Admin product approval/order oversight | A-04 to A-06 | Moderation and payment history tests |
| Admin banners/categories/promotions | A-07 to A-09 | Published content changes without deploy |
| Admin shipping/tax/payment configuration | A-10 to A-12 | Safe policy changes reflected in checkout |

**Delivery rule:** Mark a requirement `complete` only after the relevant verification runs successfully with real persistent records and, for payment, a verified sandbox integration.

---

## 22. Implementation prompts / work orders for a coding assistant

Use these sequentially; do not request the entire app in one code-generation pass.

**Work order 1 — Foundation:** “Implement Phase 1 from `SRS-plan.md`: create Next.js App Router TypeScript project, Tailwind/shadcn, correctly integrated scoped MUI, premium boutique design tokens, responsive storefront/seller/admin shells, PostgreSQL ORM setup, seed and CI. Deliver working files and verify build.”

**Work order 2 — Auth:** “Implement Phase 2 with real secure sessions, credentials + configured Google/Facebook OAuth, email verification/reset, seller application/approval, roles and strict server-side ownership checks. Add automated tests. Never stub success.”

**Work order 3 — Marketplace:** “Implement Phase 3: PostgreSQL-backed categories, seller profile/product CRUD, secure image uploads, variants/stock, admin moderation, production-quality storefront search/filters and product pages, wishlist and verified-purchase reviews. Include migrations and tests.”

**Work order 4 — Checkout:** “Implement Phase 4: multi-artisan cart, seller suborders, shipping/tax configuration, server-side totals, race-safe inventory reservation, configured gateway sandbox and idempotent signed webhooks, order status timeline and notifications. Show proof with an end-to-end paid test order.”

**Work order 5 — Custom designs:** “Implement Phase 5: custom request wizard, private reference images, participant-only messaging, versioned price quote and deadlines, acceptance and checkout-linked custom orders, tracking and notifications. Include unauthorized-access tests.”

**Work order 6 — Admin/quality:** “Implement Phases 6–7 with real seller/admin reports, all administrative controls, audit logs, end-to-end tests, accessibility and performance fixes, staging deployment instructions and release checklist.”

For each work order insist on: **(a)** actual code, **(b)** schema migrations, **(c)** tests and build verification, **(d)** screenshots of responsive UI where available, **(e)** exact remaining gaps. Any unsupported payment provider must be reported explicitly rather than disguised as functional.

---

## 23. Assumptions and decisions to settle before live launch

These questions were not answered in the assignment screenshots; recommended defaults are provided for implementation:

| Decision | Recommended default |
|---|---|
| Currency | One configured currency for MVP, minor-unit storage |
| Marketplace seller model | Multiple independent artisans, one customer cart, per-seller suborders |
| Listing visibility | Admin approval before publication |
| Seller eligibility | Admin-approved profile |
| Checkout payment | Real supported **sandbox** card gateway; enable PayPal only if supported |
| Saved cards | Provider-managed vault/tokens only; hide option if unavailable |
| Payouts | Demo ledger until approved marketplace-capable payout system is available |
| Guest checkout | Require sign-in for MVP; guest cart optional |
| Product variants | Optional per product but support model from start |
| Custom quote acceptance | Locked version, expiration, payment before production |
| Messaging | Persistent server-side thread; realtime transport optional |
| Delivery confirmation | Shipment tracking plus explicit completion policy |
| Taxes and shipping | Configurable per supported geographic zone; no fictional universal rate |
| Returns/refunds | Published policy and admin-mediated processing |
| Support/legal pages | About, Contact, Terms, Privacy, Shipping, Refunds |

**Scope commitment:** This plan covers all functional categories shown in the assignment images and supplies the additional engineering detail needed to build a genuinely working modern marketplace in the requested React/Next.js/shadcn/ui/MUI stack.








## AI Agent Module — Functional Requirements

### Objective
Implement an intelligent, role-aware AI Marketplace Agent to assist customers, artisans, and administrators through natural-language interactions and authorized actions within the Handmade Crafts Store.

### FR-AI-01: Conversational Shopping Assistant
- Customers can communicate with the AI through an integrated chat interface.
- The AI retrieves real products based on user preferences, budgets, categories, and occasions.
- The AI recommends products using verified prices and inventory availability.
- The AI supports product comparisons and cart assistance.

### FR-AI-02: AI-Powered Customization Assistant
- Collect customer design requirements conversationally.
- Convert customer instructions into structured customization specifications.
- Support optional AI-generated design previews.
- Submit customization requests to relevant artisans.
- Allow artisans to review requirements and provide quotations.

### FR-AI-03: Artisan AI Copilot
- Generate product descriptions, titles, and suggested keywords.
- Analyze seller-specific sales and inventory information.
- Provide restocking recommendations.
- Generate draft customer responses.
- Summarize custom design inquiries.

### FR-AI-04: Admin AI Analyst
- Answer questions about marketplace sales and performance.
- Generate summaries of orders, sellers, and product categories.
- Identify unusual marketplace activity for human review.
- Summarize pending product approvals and customer complaints.
- Provide actionable business insights based on authorized data.

### FR-AI-05: Agent Tools and Integrations
- Integrate an OpenAI model with server-side tool/function calling.
- Connect agent tools to authenticated Next.js backend APIs.
- Retrieve live data from the marketplace database.
- Validate all agent actions using role-based access control.
- Require explicit user confirmation before consequential actions.
- Maintain audit logs of agent tool execution.

### FR-AI-06: AI Conversation Interface
- Provide a floating AI assistant accessible throughout the application.
- Support conversation history.
- Display product cards and relevant actionable suggestions.
- Show loading and tool-execution states.
- Display clear error messages and allow retrying failed requests.
- Support separate AI capabilities for each user role.

### FR-AI-07: Agent Security and Reliability
- Never expose OpenAI API keys to the browser.
- Enforce customer, seller, and admin data isolation.
- Prevent unauthorized modifications or disclosures.
- Treat customer messages and marketplace content as untrusted input.
- Require confirmation for cart modifications, listing updates, and other important actions.
- Never process payments, refunds, account suspensions, or product approvals without the appropriate authorized workflow.
- Provide deterministic fallback behavior when the AI service is unavailable.
- Track token usage, latency, failures, and AI-related operational costs.

### Acceptance Criteria
- The agent retrieves accurate information from actual marketplace records.
- Customers receive relevant recommendations based on real inventory.
- Custom design requests generate structured, usable specifications.
- Sellers cannot access another seller's private information.
- Admin analytics reflect actual database values.
- Protected actions require permission checks and appropriate confirmation.
- The AI never claims an operation succeeded unless the backend confirms it.
