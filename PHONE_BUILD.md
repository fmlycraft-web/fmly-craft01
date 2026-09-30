# FMLY CRAFT — Phone-only APK build

1. Create/sign in to GitHub.
2. Create a new repository, e.g. `fmly-craft` (Public is simplest for first build).
3. Extract this ZIP on your phone.
4. Upload the **contents of the `fmly_craft_app` folder** to the repository root. Make sure `.github/workflows/build-apk.yml` is uploaded too. If the GitHub mobile app doesn't show hidden `.github`, use github.com in Chrome with Desktop site enabled.
5. Open **Actions** → **Build FMLY CRAFT APK** → **Run workflow**.
6. Wait for the green check.
7. Open the completed workflow run → **Artifacts** → `fmly-craft-release-apk` → download the ZIP.
8. Extract it and tap `app-release.apk`.
9. If Android blocks installation, enable **Install unknown apps** for the browser/file manager you used, then install again.

This workflow builds a DEMO APK. It is not the production Supabase/payment build. For production, add the Supabase URL and anon key as GitHub Actions secrets/variables and change the build command accordingly; payment secrets must remain server-side.
