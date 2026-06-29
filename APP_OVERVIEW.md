# Home237 — Full App Rundown

> Cameroon property‑rental marketplace built in Flutter. Tenants find & rent verified
> homes; landlords list properties and collect rent; admins moderate everything.
> Branded **Home237** (internal `MaterialApp` title still says `HomeFinder237`).

Last updated: 2026‑06‑27. This document describes the app **as it actually is in the code**, including the bits that are leftover/test code so you know what's real before launch.

---

## 1. What the app is

A two‑sided real‑estate marketplace for Cameroon with a built‑in admin back office:

- **Tenants** browse verified listings by city (Buea, Douala, Yaoundé, Bamenda, Bafoussam, Limbe), save favourites, chat with landlords, book property tours, sign digital leases, and pay rent — all from the phone.
- **Landlords** list properties (pending admin approval), upgrade to **Premium**, get **Boosted / Fast‑Track** placement, manage tours, and receive rent payouts.
- **Admins** approve/reject listings, review landlord KYC verifications, manage users (suspend/ban), handle reports, run support chat, and set platform fees.

It ships as **Android (primary), Web, and iOS** from one Flutter codebase. The web build also nudges visitors to download the Android APK.

---

## 2. Tech stack

| Layer | Choice |
|---|---|
| Framework | Flutter (Dart SDK ^3.10.7), Material, `provider` for state |
| Auth | Firebase Auth (email/password + Google Sign‑In) |
| Database | Cloud Firestore (primary data store) |
| File storage | **Supabase Storage** (buckets: `properties`, `profiles`, `verifications`) |
| Payments | **Fapshi** (MTN MoMo / Orange Money) via a **Supabase Edge Function** |
| Push | Firebase Cloud Messaging (FCM) |
| Config/secrets | Firebase Remote Config (+ `admin_settings` Firestore docs) |
| Maps | `flutter_map` + `latlong2` + `geolocator` + `geocoding` |
| AI assistant | **Groq** (`llama-3.1-8b-instant`) with function‑calling |
| Media | `image_picker`, `cached_network_image`, `video_player`/`chewie` |
| QR | `mobile_scanner` + `qr_flutter` (tour passes & escrow check‑in) |
| Email | `mailer` (SMTP) for lease agreements & notifications |
| i18n | English + French (custom `AppLocalizations`) |

**Two backends, on purpose:** Firebase holds the structured data and auth; Supabase holds the heavy image files and the server‑side payment proxy. See [supabase/functions/fapshi/index.ts](supabase/functions/fapshi/index.ts).

---

## 3. Roles & startup routing

Roles: `tenant`, `landlord`, `admin`, `none` (enum in [lib/auth_service.dart](lib/auth_service.dart#L14)).

Startup flow ([lib/splash_screen.dart](lib/splash_screen.dart)):

```
Splash (3.5s min, animated)
 ├─ first launch?           → OnboardingScreen
 ├─ not signed in           → HomePage (public browse)
 ├─ signed in, unverified   → sign out → HomePage
 ├─ suspended / doc deleted → sign out → HomePage
 └─ signed in + verified → route by role:
        tenant   → TenantDashboard
        landlord → LandlordDashboard
        admin    → AdminDashboard
        none     → RoleSelectionScreen
```

`HomePage` is fully browsable **without an account**; auth is prompted only when the user tries to favourite, chat, book, or pay.

---

## 4. Feature catalogue (by area)

**Discovery & browse** — [home_page.dart](lib/home_page.dart), [explore_screen.dart](lib/explore_screen.dart), [property_details_screen.dart](lib/property_details_screen.dart), [map_component.dart](lib/map_component.dart)
- City carousels, "Near You" (auto‑detected city via geolocation), Featured row, type filters (Apartment/Studio/House/Office/Land), search, map view.
- Only `status == approved|active` listings show. Sort = **Boosted first → newest**.

**Auth** — [signin_screen.dart](lib/signin_screen.dart), [signup_screen.dart](lib/signup_screen.dart), [forgot_password_screen.dart](lib/forgot_password_screen.dart), [email_verification_screen.dart](lib/email_verification_screen.dart), [role_selection_screen.dart](lib/role_selection_screen.dart)
- Email/password + Google (popup on web, redirect fallback on mobile‑web/blocked popups), email‑verification gating, "remember me".

**Landlord** — [landlord_dashboard.dart](lib/landlord_dashboard.dart), [add_property_screen.dart](lib/add_property_screen.dart), [edit_property_screen.dart](lib/edit_property_screen.dart), [my_properties_screen.dart](lib/my_properties_screen.dart), [landlord_profile_screen.dart](lib/landlord_profile_screen.dart), [verification_upload_screen.dart](lib/verification_upload_screen.dart)
- Create/edit listings (images → Supabase Storage), submit KYC verification, view tour requests, upgrade to Premium.

**Tenant** — [tenant_dashboard.dart](lib/tenant_dashboard.dart), [saved_properties_screen.dart](lib/saved_properties_screen.dart), [tenant_profile_screen.dart](lib/tenant_profile_screen.dart), [rent_tracker_screen.dart](lib/rent_tracker_screen.dart)
- Saved favourites, rent tracking, profile.

**Tours & "Smart Escrow"** — [tour_requests_screen.dart](lib/tour_requests_screen.dart), [tour_pass_display_screen.dart](lib/tour_pass_display_screen.dart), [tour_pass_scanner_screen.dart](lib/tour_pass_scanner_screen.dart), [tour_player_screen.dart](lib/tour_player_screen.dart)
- Tenant pays a viewing fee held in escrow; a **QR‑code handshake** at the property releases it (tenant shows pass, agent/landlord scans). Video tours via `chewie`.

**Leases & rent** — [lease_agreement_screen.dart](lib/lease_agreement_screen.dart), [services/lease_service.dart](lib/services/lease_service.dart), [services/rent_payment_service.dart](lib/services/rent_payment_service.dart)
- Digital lease with an `escrowCode`, auto‑emailed (HTML) to both parties. Monthly rent paid via Fapshi push; on success the lease goes `active`; landlord payout via Fapshi `sendPayout`.

**Messaging** — [messages_screen.dart](lib/messages_screen.dart), [chat_screen.dart](lib/chat_screen.dart), [support_chat_screen.dart](lib/support_chat_screen.dart) + admin side [admin_support_chats_screen.dart](lib/admin_support_chats_screen.dart), [admin_chat_detail_screen.dart](lib/admin_chat_detail_screen.dart)
- Tenant↔landlord chat, plus user↔admin support chat. FCM foreground/background notifications.

**AI assistant** — [ai_agent_screen.dart](lib/ai_agent_screen.dart), [services/ai_service.dart](lib/services/ai_service.dart)
- "Home237 Virtual Démarcheur": bilingual EN/FR Groq chatbot with **function‑calling tools**: `open_tour_scheduler`, `search_properties`, `get_real_time_properties` (reads live Firestore listings). Knows Cameroon neighbourhoods. API key pulled from `admin_settings/groq` (Firestore) or Remote Config.

**Admin** — [admin_dashboard.dart](lib/admin_dashboard.dart), [admin_properties_screen.dart](lib/admin_properties_screen.dart), [admin_users_screen.dart](lib/admin_users_screen.dart), [admin_verifications_screen.dart](lib/admin_verifications_screen.dart), [admin_reports_screen.dart](lib/admin_reports_screen.dart), [admin_fee_settings_screen.dart](lib/admin_fee_settings_screen.dart)
- Approve/reject listings, review KYC, suspend/ban users, resolve reports, configure fees.

**Settings & legal** — [settings_screen.dart](lib/settings_screen.dart), [privacy_security_screen.dart](lib/privacy_security_screen.dart), [help_support_screen.dart](lib/help_support_screen.dart), [privacy_policy_screen.dart](lib/privacy_policy_screen.dart), [terms_of_service_screen.dart](lib/terms_of_service_screen.dart), dark/light theme, EN/FR toggle, account deletion.

---

## 5. Monetization

1. **Premium subscription (landlords)** — 5,000 FCFA/month or 45,000 FCFA/year via Fapshi. Unlocks: up to 3 listings, "Premium" badge, priority in search, analytics, priority support. See [premium_subscription_screen.dart](lib/premium_subscription_screen.dart).
2. **Boosted listings** (`isBoosted`) — "Top Pick" / Featured placement at the top of carousels.
3. **Fast‑Track** (`isFastTracked`) — highlighted green border; faster/priority approval.
4. **Rent collection** — monthly rent through the app (Fapshi), with escrow + automated landlord payout.
5. **Viewing/tour fees** — held in escrow, released on QR check‑in.

---

## 6. Payments — how money actually moves

**The real, production path is Fapshi via a Supabase Edge Function.** Direct calls to `live.fapshi.com` from the phone were dropped because Cameroon mobile networks caused TLS handshake failures and it exposed the API key.

```
Flutter (FapshiService)
  → Supabase.functions.invoke('fapshi', { action, ... })
    → Edge Function (holds FAPSHI_API_USER / FAPSHI_API_KEY as secrets)
      → live.fapshi.com  (/direct-pay, /payment-status, /payout)
```

- Client: [lib/services/fapshi_service.dart](lib/services/fapshi_service.dart) — `directPay`, `getPaymentStatus`, `sendPayout`.
- Server: [supabase/functions/fapshi/index.ts](supabase/functions/fapshi/index.ts) — normalises phone numbers, returns `{ ok, ... }`.
- Flow: `direct-pay` returns a `transId` → app polls `payment-status` every 3s up to ~2 min → on `SUCCESSFUL`, Firestore is updated (subscription/rent/lease).

**Verified working 2026‑06‑27:** a live 100 FCFA test went `PENDING → SUCCESSFUL`. The earlier "Payment Failed" spree was **insufficient MoMo balance at 5,000 FCFA**, not a bug. The failed‑status message now names the likely cause (balance/PIN/prompt) instead of a generic error.

> ⚠️ **Dead/sandbox code:** [lib/services/momo_service.dart](lib/services/momo_service.dart) is a **direct MTN MoMo sandbox** integration with hard‑coded sandbox keys (`sandbox.momodeveloper.mtn.com`, `targetEnvironment = 'sandbox'`). It is **not** the live path and should be removed or clearly quarantined before launch to avoid confusion.

---

## 7. Data model (Firestore)

Top‑level collections (inferred from code, esp. `AuthService.wipeUserData`):

| Collection | Purpose |
|---|---|
| `users/{uid}` | profile, `role`, `subscriptionStatus`/`Expiry`, `activeSessionToken`, `fcmToken`, `suspended`, `hasSeenWelcome`, `emailVerified` |
| `banned_users` | permanent email ban list (checked on every sign‑in) |
| `sessions/{uid}` | session record |
| `properties/{id}` | listing: `town`, `area`, `type`, `beds`, `price`, `images[]`, `status`, `landlordId`, `isBoosted`, `isFastTracked`, `isLandlordPremium`, `rating`, `createdAt` |
| `verifications` | landlord KYC submissions (`status`: pending/approved) |
| `favorites/{uid}/properties` | saved listings |
| `notifications/{uid}/items` | in‑app notifications |
| `tour_requests` | tour bookings (tenantId/landlordId) |
| `leases/{id}` | digital lease + `escrowCode`, `status` pending/active/ended |
| `rent_transactions/{transId}` | rent payment log (status pending/paid/failed/expired) |
| `conversations/{id}/messages` | tenant↔landlord chat |
| `support_chats/{uid}/messages` | user↔admin support |
| `ai_chats/{id}/messages` | AI assistant history |
| `reports` | property/user reports |
| `admin_settings/{groq,…}` | server‑side config (e.g. Groq API key, fees) |

Images/files live in **Supabase Storage**, not Firestore.

---

## 8. Security & session handling

- **Single active session:** each login writes a UUID `activeSessionToken`; a real‑time Firestore listener signs the user out if another device logs in ([auth_service.dart](lib/auth_service.dart#L86)).
- **Remote kill switch:** if an admin deletes or sets `suspended: true` on the user doc, the listener force‑signs‑out immediately.
- **Ban list:** `banned_users` checked on email/Google sign‑in.
- **Inactivity auto‑logout:** 5‑min idle timer, reset on any touch, via `InactivityWrapper` in [main.dart](lib/main.dart#L155).
- **Email verification** required before role dashboards (Google accounts auto‑verified).
- **Account deletion** wipes Auth + all Firestore data across ~12 collections ([auth_service.dart](lib/auth_service.dart#L667)).

---

## 9. Theming & i18n

- Light/dark themes (teal primary, blue secondary) via `ThemeNotifier`; theme can adapt per role.
- Bilingual **English/French** via custom `AppLocalizations` + Flutter localizations — appropriate for Cameroon.

---

## 10. Pre‑launch checklist (Play Store)

These are **not** payment issues — payments work — but they block or risk a Play Store listing:

1. **Release signing** — `release` is currently signed with **debug keys** ([android/app/build.gradle.kts](android/app/build.gradle.kts#L39)). Google Play rejects debug‑signed AABs. Create an upload keystore (or Play App Signing) before submitting.
2. **App ID / namespace mismatch** — applicationId `com.Joshua.home_237` vs namespace `com.example.home237`. Lock in a final package name (unchangeable after publish).
3. **Google Play Billing policy** — selling the in‑app Premium upgrade via Fapshi (not Play Billing) may violate Google's Payments policy for digital goods. Verify before/while submitting.
4. **Remove sandbox/dead code** — `momo_service.dart` (MTN sandbox) and the US‑seeded `firestore_initializer.dart` sample data are dev artifacts; clean up.
5. **Secrets hygiene** — Supabase anon key in `main.dart` is fine (public by design); confirm no live private keys are shipped in the client (Fapshi key is correctly server‑side; Groq key is server‑fetched).

---

## 11. One‑paragraph summary

Home237 is a Flutter‑based, bilingual Cameroon rental marketplace with three roles (tenant/landlord/admin). Firebase handles auth, the Firestore database, push, and config; Supabase handles image storage and a server‑side Fapshi payment proxy for MTN MoMo / Orange Money. Beyond browsing and listing, it has a genuine transactional spine — Premium subscriptions, boosted placement, QR‑based escrow for viewings, digital leases, in‑app rent collection with landlord payouts — plus a Groq‑powered bilingual AI assistant and a full admin moderation suite. The payment system is verified working; the remaining work to publish is release signing, package‑name cleanup, the Play Billing policy question, and removing leftover sandbox code.
