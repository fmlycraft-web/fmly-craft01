# FMLY CRAFT — Android Commerce App

Production-oriented Flutter + Supabase implementation for the supplied FMLY CRAFT design. The app is deliberately **Chandigarh-only** and uses server-side geospatial validation in Supabase/PostGIS.

## Build

Flutter SDK 3.24+ recommended.

```bash
flutter pub get
flutter run --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co --dart-define=SUPABASE_ANON_KEY=YOUR_ANON_KEY
flutter build apk --release --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
flutter build appbundle --release --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
```

The container used to prepare this project does not have the Flutter/Android SDK installed, so an APK could not honestly be claimed as compiled here. The source, Android project, database migration and Edge Function are included.

## Supabase

1. Create a Supabase project.
2. Enable PostGIS extension.
3. Run `supabase/migrations/001_initial.sql`.
4. Deploy `supabase/functions/create-order/index.ts`.
5. Configure Auth providers.
6. Create an Owner user and set its profile role to `owner` using a secure server-side SQL/session procedure.
7. Create Storage bucket `product-images` and apply the policies in the migration.
8. Configure Razorpay secrets only in Edge Function/server environment; never put the secret in the APK.

## Chandigarh geofence

The migration stores a configurable polygon in `service_areas`. Replace the seed polygon with the authoritative Chandigarh boundary dataset before production. The app also performs client-side location checks for UX, but checkout/order creation is protected by the database/Edge Function.

## Roles

- `customer`
- `owner`
- `rider`

Riders require Owner approval (`pending`, `approved`, `rejected`, `suspended`).

## Demo mode

Use `--dart-define=DEMO_MODE=true` to preview the UI without Supabase. Demo mode does not represent production payments, orders, inventory or authentication.
