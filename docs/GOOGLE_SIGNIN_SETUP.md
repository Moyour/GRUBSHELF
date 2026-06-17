# Google Sign In Setup

For Sign in with Google to work, you need to configure both Google Cloud Console and your Supabase project.

## 1. Google Cloud Console

1. Go to [Google Cloud Console](https://console.cloud.google.com/) and create or select a project.
2. Enable the **Google+ API** (or **Google Identity**) if prompted.
3. Go to **APIs & Services** → **Credentials** → **Create Credentials** → **OAuth client ID**.
4. Configure the OAuth consent screen if you haven't:
   - Add scopes: `openid`, `.../auth/userinfo.email`, `.../auth/userinfo.profile`
5. Create **two** OAuth 2.0 Client IDs:

   **a) Web application** (required for Supabase audience validation):
   - Application type: **Web application**
   - Name: e.g. "GrubShelf Web"
   - Authorized redirect URIs: `https://your-project.supabase.co/auth/v1/callback` (for hosted) or `http://127.0.0.1:54321/auth/v1/callback` (for local)
   - Copy the **Client ID** (e.g. `123456789-xxx.apps.googleusercontent.com`)

   **b) iOS** (for the native app):
   - Application type: **iOS**
   - Bundle ID: `com.grubshelf.GrubShelf`
   - Copy the **Client ID** (e.g. `123456789-yyy.apps.googleusercontent.com`)

## 2. Supabase Dashboard (Hosted)

1. Go to [Supabase Dashboard](https://supabase.com/dashboard) → your project → **Authentication** → **Providers**
2. Enable **Google** (toggle ON)
3. Under **Client IDs**, add both IDs **separated by a comma**, with the **Web Client ID first**:
   ```
   web-client-id.apps.googleusercontent.com,ios-client-id.apps.googleusercontent.com
   ```
4. For **Client Secret** (optional for native): use the Web application's client secret from Google Cloud Console.

## 3. Supabase Local (config.toml)

If using `supabase start` for local development:

1. Set environment variables in `.env` (or your shell):
   ```env
   SUPABASE_AUTH_EXTERNAL_GOOGLE_CLIENT_ID="web-id.apps.googleusercontent.com,ios-id.apps.googleusercontent.com"
   SUPABASE_AUTH_EXTERNAL_GOOGLE_CLIENT_SECRET="your-web-client-secret"
   ```

2. Restart Supabase: `supabase stop` then `supabase start`.

## 4. GrubShelf App

1. Open `GrubShelf/Config.plist`
2. Set **both** keys:
   - `GOOGLE_CLIENT_ID` — **iOS** client ID from step 1b
   - `GOOGLE_WEB_CLIENT_ID` — **Web** client ID from step 1a (required for Supabase; passed to Google as `serverClientID` so the id_token audience is the web client)

The app configures `GIDConfiguration(clientID: ios, serverClientID: web)`. Without `GOOGLE_WEB_CLIENT_ID`, Supabase returns **Unacceptable audience in id_token**.

## 5. URL Scheme (Optional for some flows)

If you encounter redirect issues, add a URL scheme to your app:

1. In Xcode, select the GrubShelf target → **Info** tab
2. Under **URL Types**, add a new entry:
   - **Identifier**: `com.googleusercontent.apps.YOUR_IOS_CLIENT_ID`
   - **URL Schemes**: The reversed client ID (e.g. `com.googleusercontent.apps.123456789-yyy`)
   - **Role**: Editor

   The reversed client ID is the iOS client ID with the domain reversed:  
   `123456789-yyy.apps.googleusercontent.com` → `com.googleusercontent.apps.123456789-yyy`

## 6. OAuth consent screen app name

The name shown on Google’s sign-in screen (e.g. “Continue to **Pantry**”) comes from **Google Cloud**, not `Config.plist`.

1. [Google Cloud Console](https://console.cloud.google.com/) → **APIs & Services** → **OAuth consent screen**
2. Click **Edit app**
3. Set **App name** to **GrubShelf** (and update **App logo** / support email if needed)
4. **Save**

Changes can take a few minutes to appear. The iOS app also sets `CFBundleDisplayName` to `GrubShelf` for the home screen and system UI.

## Troubleshooting

- **"Unacceptable audience in id_token"**: You must add the **Web Client ID** to Supabase (in addition to the iOS Client ID). The Web Client ID must be first in the comma-separated list.
- **"Provider not enabled"**: Enable Google in Supabase Dashboard → Authentication → Providers.
- **"Invalid client"**: Ensure the iOS Client ID in Config.plist matches the Bundle ID (`com.grubshelf.GrubShelf`) in Google Cloud Console.
- **User cancelled**: Error code -5 from GIDSignIn means the user cancelled; we handle this silently.
