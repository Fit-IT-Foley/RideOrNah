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

## CI (not set up yet)

When CI needs App Store Connect, for TestFlight uploads, it will authenticate with the same kind of Team key through environment variables. `asc` reads `ASC_KEY_ID`, `ASC_ISSUER_ID` and `ASC_PRIVATE_KEY_B64`, a base64 copy of the `.p8`, which keeps the line breaks intact. Use a separate key for CI, named something like "RideOrNah CI", so you can revoke it without touching your own.

Set the secrets from this Mac. The owner runs these commands, never an agent:

```sh
gh secret set ASC_KEY_ID --body "<KEY_ID>"
gh secret set ASC_ISSUER_ID --body "<ISSUER_ID>"
base64 -i ~/.appstoreconnect/private_keys/AuthKey_<KEY_ID>.p8 | gh secret set ASC_PRIVATE_KEY_B64
```

The last command pipes the key straight into the secret, so it never shows up on screen or in your shell history. Then, in a workflow step:

```yaml
env:
  ASC_KEY_ID: ${{ secrets.ASC_KEY_ID }}
  ASC_ISSUER_ID: ${{ secrets.ASC_ISSUER_ID }}
  ASC_PRIVATE_KEY_B64: ${{ secrets.ASC_PRIVATE_KEY_B64 }}
  ASC_TELEMETRY_DISABLED: "1"
```

Secrets aren't passed to workflows triggered by pull requests from forks, so only branches in this repository can use them.

## Next: TestFlight

The TestFlight upload pipeline gets its own OpenSpec change. It will need:

1. **Real identifiers.** Choose the final bundle ID prefix. Register bundle IDs for the app, widget extension and watch app (`asc bundle-ids create`). Enable the WeatherKit and App Groups capabilities, and set up the app group.
2. **The app record.** Create the app in App Store Connect with name, primary language, bundle ID and SKU. The API can't create app records, so this is a one-time step on the website, or `asc web apps create`.
3. **Agreements.** Accept the Paid Applications agreement and fill in tax and banking details. This is needed for subscriptions, not for TestFlight itself.
4. **Signing for CI.** Either cloud-managed signing (`xcodebuild -allowProvisioningUpdates` with the API key) or an Apple Distribution certificate and App Store profiles. Store them as secrets, or fetch them with `asc signing`.
5. **Versioning.** Take build numbers from `asc builds next-build-number` so uploads never collide.
6. **Export compliance.** Set `ITSAppUsesNonExemptEncryption` in the Info.plist so builds don't wait on the encryption question.
7. **The workflow.** Add a manually started, or tag-triggered, GitHub Actions job: archive, export an `.ipa`, `asc builds upload`, `asc builds wait`, then add the build to an internal TestFlight group. Upload jobs take a lot of macOS minutes, so keep them off pull requests.

## Subscriptions

The app sells two auto-renewable plans in one subscription group. Their product IDs are fixed in code (`Plan` in `RideOrNahKit/Sources/Entitlements`):

| Product ID | Period | Introductory offer |
|---|---|---|
| `rideornah.annual` | 1 year | Free trial (1 week planned) |
| `rideornah.monthly` | 1 month | Free trial (1 week planned) |

- **Products.** Create them in App Store Connect under the app, with the same IDs, after the app record exists. Set prices, the trial length and Family Sharing there; the app reads them at runtime and never hard-codes them. `StoreKit/RideOrNah.storekit` mirrors them with placeholder prices ($29.99 and $4.99) for local testing only.
- **Legal links.** The paywall links Terms of Use to Apple's standard licensed application end user license agreement, and the Privacy Policy to `docs/privacy-policy.md` on GitHub Pages (`LegalLinks` in `RideOrNah/Store/PaywallView.swift`). Use the same two URLs in the App Store listing. Before the first submission, the privacy policy URL must be live.
- **Check on a device before each submission.** With a Sandbox Apple Account (Settings → Developer → Sandbox Apple Account on the iPhone), install a TestFlight or Xcode build. Then:
  1. Start the free trial from the paywall, and confirm Today unlocks.
  2. Cancel it in Settings → Subscriptions, and confirm the app shows "not renewing".
  3. Delete and reinstall the app, then tap Restore Purchases, and confirm access returns.
