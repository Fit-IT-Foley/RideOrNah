# App Store Connect from the command line

We use [`asc`](https://github.com/rorkai/App-Store-Connect-CLI), an open-source (MIT) Go CLI for the App Store Connect API, signed in with a Team API key. Once the key is set up, nobody needs to sign in to the App Store Connect website for builds, TestFlight, bundle IDs, subscriptions or metadata.

We chose `asc` because it covers the whole App Store Connect API, including build uploads and TestFlight. It's a single binary with no Ruby toolchain, prints JSON for scripts, and keeps the key in the macOS Keychain. Apple's own command-line tools (`xcrun altool`, `notarytool`) only upload and notarize. fastlane would add a Ruby toolchain we don't otherwise need. `asc` is developer tooling only and never ships in the app.

## Set up a new Mac

1. Install the pinned version and stop Homebrew from upgrading it:

   ```sh
   brew install asc
   asc --version        # expect 7.6.1; see "Upgrading asc" if Homebrew installs a newer version
   brew pin asc
   ```

2. Turn off telemetry. `asc` sends command-level usage events to its maintainer by default:

   ```sh
   asc telemetry disable
   ```

3. Put the key file in place. Copy `AuthKey_<KEY_ID>.p8` from wherever you keep your backup, such as a password manager:

   ```sh
   mkdir -p ~/.appstoreconnect/private_keys
   chmod 700 ~/.appstoreconnect ~/.appstoreconnect/private_keys
   mv ~/Downloads/AuthKey_<KEY_ID>.p8 ~/.appstoreconnect/private_keys/
   chmod 600 ~/.appstoreconnect/private_keys/AuthKey_<KEY_ID>.p8
   ```

4. Sign in. This stores the key in the login Keychain under the profile `rideornah`:

   ```sh
   asc auth login --name rideornah --key-id <KEY_ID> --issuer-id <ISSUER_ID> \
     --private-key ~/.appstoreconnect/private_keys/AuthKey_<KEY_ID>.p8
   ```

5. Check it works: `make asc-status`, then `make asc-apps`.

## Where the key lives

| What | Where | Secret? |
|---|---|---|
| Key ID, Issuer ID | App Store Connect → Users and Access → Integrations → App Store Connect API | No. They identify the key but can't sign requests |
| Private key (`AuthKey_<KEY_ID>.p8`) | `~/.appstoreconnect/private_keys/`, mode `600`, plus one offline backup such as a password manager | **Yes** |
| Signed-in profile | macOS login Keychain, written by `asc auth login` | Yes |
| Telemetry setting | `~/.asc/telemetry.json` | No |

Apple lets you download the `.p8` only once, right after you create the key. Never commit it, paste it into chat or an issue, or print it in a CI log. `.gitignore` excludes `*.p8` and the repo-local `asc` config (`.asc/`).

## The key's role

The key is a **Team** key with the **App Manager** role. App Manager can upload builds, manage TestFlight testers and groups, edit metadata and pricing, and create subscriptions and in-app purchases. Those are everything the v1 plan needs. It can't manage users, sign agreements or see finance reports, so a leaked key can't take over the account. Don't use an Admin key for day-to-day work. If a later task needs more access, make a separate key for it.

## Rotate or revoke the key

Rotate it once a year, or right away if the `.p8` might have leaked:

1. App Store Connect → Users and Access → Integrations → App Store Connect API → **Generate API Key** (Team key, App Manager). Download the new `.p8`.
2. Put it in `~/.appstoreconnect/private_keys/` with mode `600`, then sign in again with the new Key ID:

   ```sh
   asc auth logout --name rideornah --confirm
   asc auth login --name rideornah --key-id <NEW_KEY_ID> --issuer-id <ISSUER_ID> \
     --private-key ~/.appstoreconnect/private_keys/AuthKey_<NEW_KEY_ID>.p8
   make asc-status
   ```

3. Update the CI secrets (see below), if they've been set.
4. Back on the API keys page, click **Revoke** next to the old key. Revoking takes effect at once and can't be undone. Delete the old `.p8` file and its backup.

## Handy commands

The `make` wrappers run `asc` in read-only mode (`ASC_READ_ONLY=1`), so they can't change anything in App Store Connect.

| Command | What it does |
|---|---|
| `make asc-status` | Show which credentials are active and check them against Apple |
| `make asc-apps` | List the team's apps |
| `make asc-bundle-ids` | List the team's bundle IDs |

Other useful ones:

```sh
asc auth doctor                               # diagnose auth problems
asc builds list --app <APP_ID> --output table # recent builds for an app
asc testflight --help                         # testers, groups, distribution
asc search "upload a build"                   # find the right command
asc --read-only <command>                     # refuse anything that would change data
```

## Upgrading asc

Upgrade on purpose, not with every `brew upgrade`:

```sh
brew unpin asc && brew upgrade asc && brew pin asc
asc --version
```

Then update the version in this file. Homebrew installs only its current version of `asc`, so on a new Mac you may get a newer version than the one listed here. That's fine, but update this file to match.

## TestFlight

Builds reach TestFlight only when the owner starts an upload, with `make testflight` on a Mac or the TestFlight workflow in CI. Both run `scripts/testflight.sh`, which:

1. finds the app record by bundle ID,
2. takes the next build number from App Store Connect,
3. archives a Release build and exports it with Xcode's automatic signing and a cloud-managed Apple Distribution certificate,
4. uploads it and waits for processing. The internal group "Ride or Nah Team" has access to all builds, so App Store Connect gives it each build automatically. The script adds the build by hand only if that access is ever turned off.

### Identity

Set in `Config/Base.xcconfig`. Every target derives its bundle ID from `APP_BUNDLE_ID`.

| What | Value |
|---|---|
| App | `com.rideornah.RideOrNah` |
| Widgets | `com.rideornah.RideOrNah.Widgets` |
| Watch app | `com.rideornah.RideOrNah.watchkitapp` |
| Watch complications | `com.rideornah.RideOrNah.watchkitapp.Widgets` |
| App group | `group.com.rideornah.RideOrNah` |
| Team | `WTF332KZJ6` |
| App Store name, SKU | "Ride or Nah", `rideornah-ios` |

### One-time setup

1. **Register the IDs.** The first archive with `-allowProvisioningUpdates`, signed in to Xcode with an Apple Account on the team, registers the four App IDs, their App Groups and WeatherKit capabilities, and the app group. The App Store Connect API can't create app groups, so Xcode does this, not `asc`.
2. **Create the app record (owner only).** Apple only allows this through a signed-in Apple Account. Either use the website (Apps → + → New App: iOS, "Ride or Nah", English (U.S.), the app's bundle ID, SKU `rideornah-ios`, Full Access), or run this in your own terminal, which signs in with your Apple Account and two-factor code:

   ```sh
   asc web apps create --name "Ride or Nah" --bundle-id com.rideornah.RideOrNah \
     --sku rideornah-ios --primary-locale en-US --auto-rename=false
   ```

   `--auto-rename=false` stops it from quietly adding a suffix if the name is taken.
3. **Subscriptions.** Create them as described under "Subscriptions" below.
4. **Internal group.** Create "Ride or Nah Team" with the owner in it, with access to all builds: `asc testflight groups create --app <APP_ID> --name "Ride or Nah Team" --internal --access-all-builds --feedback-enabled`, then `asc testflight testers add --app <APP_ID> --email <owner's Apple Account> --group "Ride or Nah Team"`.

### Upload from a Mac

```sh
make testflight
```

It needs Xcode signed in to an Apple Account on the team (Xcode → Settings → Apple Accounts), and the `asc` profile from "Set up a new Mac".

### Upload from CI

[`.github/workflows/testflight.yml`](../.github/workflows/testflight.yml) runs the same script. Nothing starts it automatically, so start it from `main`:

```sh
gh workflow run testflight.yml --ref main
gh run watch
```

It authenticates with its own Team key, named something like "RideOrNah CI", so you can revoke it without touching yours. Set its three secrets from your Mac. The owner runs these commands, never an agent:

```sh
gh secret set ASC_KEY_ID --body "<KEY_ID>"
gh secret set ASC_ISSUER_ID --body "<ISSUER_ID>"
base64 -i ~/.appstoreconnect/private_keys/AuthKey_<KEY_ID>.p8 | gh secret set ASC_PRIVATE_KEY_B64
```

The last command pipes the key straight into the secret, so it never shows up on screen or in your shell history. The workflow decodes it to a temporary file readable only by the runner, passes the file's path to `xcodebuild` and `asc` (`ASC_PRIVATE_KEY_PATH`), and deletes it at the end. GitHub masks secret values in logs. Secrets aren't passed to workflows from forks, and only people with write access can start the workflow.

**If CI signing fails.** CI signs with a cloud-managed distribution certificate through the API key. If the export step fails with a certificate permission error, Apple wants a key with more access for that. The choices are an Admin-role key used only by CI, or a regular Apple Distribution certificate stored as a secret.

### Build numbers and versions

Each upload takes the next build number from App Store Connect (`asc builds next-build-number`): one above the highest build it has seen for the app, uploaded or processed. So the Mac and CI never collide, and nothing is counted locally. The version riders see is `MARKETING_VERSION` in `Config/Base.xcconfig`. Raise it for each App Store release.

### Export compliance

Every bundle declares `ITSAppUsesNonExemptEncryption` false. The app's only encryption is HTTPS through Apple's frameworks, which is exempt, so builds don't wait on the encryption question.

## Subscriptions

The app sells two auto-renewable plans in one subscription group, "Ride or Nah", with the same pricing as PlanFetch. Their product IDs are fixed in code (`Plan` in `RideOrNahKit/Sources/Entitlements`):

| Product ID | Period | Level | US price | Introductory offer |
|---|---|---|---|---|
| `rideornah.annual` | 1 year | 1 | $19.99 | 1-week free trial |
| `rideornah.monthly` | 1 month | 2 | $2.99 | 1-week free trial |

- **Products.** Create them in App Store Connect under the app, with the same IDs, after the app record exists:
  - Other territories use App Store Connect's equalized prices for the US prices.
  - Both are available in every territory, including new ones, and the trial is offered in every territory.
  - Family Sharing is off.
  - Each has an English display name and description, and a paywall screenshot for review. Without those, they stay "Missing Metadata" and may not load in the sandbox.

  The app reads prices and the trial at runtime and never hard-codes them. `StoreKit/RideOrNah.storekit` and the UI tests' stand-in store use the same prices, for local testing only.
- **Compare with PlanFetch.** `make asc-subscriptions` prints both apps' subscription prices, read-only.
- **Legal links.** The paywall links Terms of Use to Apple's standard licensed application end user license agreement, and the Privacy Policy to `docs/privacy-policy.md` on GitHub Pages (`LegalLinks` in `RideOrNah/Store/PaywallView.swift`). Use the same two URLs in the App Store listing. Before the first submission, the privacy policy URL must be live.
- **Check on a device before each submission.** With a Sandbox Apple Account (Settings → Developer → Sandbox Apple Account on the iPhone), install a TestFlight or Xcode build. Then:
  1. Start the free trial from the paywall, and confirm Today unlocks.
  2. Cancel it in Settings → Subscriptions, and confirm the app shows "not renewing".
  3. Delete and reinstall the app, then tap Restore Purchases, and confirm access returns.
