# Signing and store credentials

This is the setup for issue #66. Nothing here is configured yet, so every
release is currently debug-signed and the AAB is not accepted by Play. The
Release workflow keeps working while the secrets are missing; it warns and
publishes sideload builds.

Two rules:

- Back up the upload keystore and its passwords somewhere outside the
  repository. Losing them is recoverable, but it blocks automated releases
  until Google approves an upload-key reset.
- Never commit a keystore, `key.properties`, a service-account JSON file or an
  Apple private key. All of them are ignored by git.

## What has to exist

| Credential | Where it comes from | Used by |
| --- | --- | --- |
| Android upload keystore | `app/tool/create_upload_keystore.sh` | every Android release |
| Play Console app + Play App Signing | Play Console | first and later AAB uploads |
| Google service account JSON | Google Cloud + Play Console | future fastlane `supply` upload |
| Apple Developer Program + App Store Connect app | Apple | iOS builds and TestFlight |
| App Store Connect API key | App Store Connect | future fastlane `pilot`/`match` |
| Private `match` repository | your Git host | iOS certificates and profiles |
| GitHub `production` environment | repository settings | store-upload approval gate |

## Android upload key

### 1. Generate the keystore

You need a JDK with `keytool` (Android Studio bundles one) and an authenticated
`gh` CLI.

```sh
cd app
tool/create_upload_keystore.sh
```

The script creates `android/app/upload-keystore.jks` and
`android/key.properties`, refuses to overwrite either file, and prompts for a
password twice. The key alias defaults to `paluma-upload`; the certificate
validity is 10,000 days.

To run it non-interactively (for example from a password manager), set the
passwords in the environment instead:

```sh
STORE_PASSWORD='…' KEY_PASSWORD='…' tool/create_upload_keystore.sh
```

Move the keystore and a copy of the passwords into your password manager or an
encrypted backup. The `key.properties` file is only a local convenience; the
keystore and the two passwords are the things you cannot regenerate.

### 2. Set the GitHub secrets

From the repository root:

```sh
base64 < app/android/app/upload-keystore.jks | tr -d '\n' \
  | gh secret set ANDROID_KEYSTORE_BASE64
gh secret set ANDROID_KEYSTORE_PASSWORD
gh secret set ANDROID_KEY_ALIAS --body paluma-upload
gh secret set ANDROID_KEY_PASSWORD
```

`gh secret set` prompts for the value without echoing it. Set all four secrets
together: the workflow checks only for `ANDROID_KEYSTORE_BASE64`, so a partial
set makes the build fail instead of falling back to debug signing.

Check them with:

```sh
gh secret list | grep ANDROID_
```

### 3. Verify a signed build

Build locally:

```sh
cd app
flutter build appbundle --release
```

The Gradle build only uses the upload key when `android/key.properties` exists.
To confirm the APK signature, use `apksigner` from the Android SDK build-tools
(add the build-tools directory to `PATH` first):

```sh
apksigner verify --print-certs build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
```

Alternatively, run the Release workflow and check that the **Configure
signing** step says `Using the upload keystore`, and that the GitHub Release
notes do not contain the debug-signed warning.

## Play Console

1. Create the app in [Play Console](https://play.google.com/console) with the
   package name `space.wanderstories.paluma_trails`, then complete the app
   content declarations (privacy policy, data safety, content rating, target
   audience, ads).
2. Keep **Play App Signing** enabled. New apps use it by default: Google holds
   the app signing key, and the keystore from the previous section is only the
   upload key. Do not upload the app signing key, and do not reuse the upload
   key for another app.
3. Create an **Internal testing** track. Upload the first AAB manually from the
   **Assets** section of a `v*` GitHub Release. The first upload registers the
   upload certificate; later uploads can be automated.
4. Add yourself as an internal tester and install from the testing link. This
   verifies the upload key, the AAB and the Play signing chain before the first
   production rollout.

The first upload has to be manual. Play does not create an app record through
the API, and automated uploads need the service account below. Production
promotion stays manual even after the fastlane lane exists.

### Service account for later uploads

The Release workflow does not upload to Play yet; this prepares the credential
that the fastlane `supply` lane will use.

1. In Google Cloud, create (or choose) a project and enable the **Google Play
   Android Developer API**.
2. Create a service account and a JSON key. Store the downloaded JSON in your
   password manager; it is shown once.
3. In Play Console, go to **Users and permissions**, invite the service
   account's email address, and grant it access to this app. For internal-track
   uploads, **Release to testing tracks** and **View app information** are
   enough. Add production permissions only when production uploads are
   automated.
4. Save the JSON as the `PLAY_SERVICE_ACCOUNT_JSON` GitHub secret when the lane
   is added.

## iOS and TestFlight

iOS delivery is blocked until the Apple account and macOS signing assets exist.
The bundle ID is `space.wanderstories.palumaTrails`.

1. Join the Apple Developer Program with the account that will own the app.
2. In App Store Connect, create the app record with that bundle ID and a unique
   name.
3. Create an **App Store Connect API key** under **Users and Access →
   Integrations → App Store Connect API**, with the **App Manager** role.
   Download the `.p8` file once and note the key ID and issuer ID.
4. Create a private repository for `match` and generate the distribution
   certificate and provisioning profile with:

   ```sh
   cd app/ios
   fastlane match appstore
   ```

   The `match` repository is the backup for the certificate and profile. Keep
   its URL, a Git credential and the `MATCH_PASSWORD` in the password manager.
5. Add these repository secrets when the lanes are implemented:

   - `APP_STORE_CONNECT_API_KEY_ID`
   - `APP_STORE_CONNECT_ISSUER_ID`
   - `APP_STORE_CONNECT_API_KEY` (base64-encoded `.p8`)
   - `MATCH_GIT_URL`
   - `MATCH_PASSWORD`
   - `MATCH_GIT_BASIC_AUTHORIZATION` (if the repository is not accessible with
     the runner's token)

The macOS job will run `flutter build ipa` and upload to TestFlight. It needs a
paid Apple Developer account; a free account cannot upload builds.

## GitHub `production` environment

Store uploads will declare `environment: production`, so a release cannot reach
Play or App Store Connect without approval.

1. Repository **Settings → Environments → New environment**, name it
   `production`.
2. Add yourself (and any other release approvers) under **Required reviewers**.
3. Leave the deployment branch policy open, or allow the `v*` tag pattern.
   Restricting it to protected branches would block tag builds.
4. Do not put the keystore or API keys in environment secrets until the upload
   jobs exist; repository secrets are enough for the current build workflow.

GitHub allows the approving reviewer to approve their own deployment in a
solo-maintained repository. The gate is still useful because it makes the
upload an explicit, separate step.

## Recovery

- **Upload key lost:** in Play Console, open **App integrity → App signing** and
  request an upload key reset. After Google approves it, run the helper script
  again, update the four secrets and upload a new AAB. The app signing key is
  unaffected.
- **Upload key leaked:** request a reset immediately, then rotate the GitHub
  secrets. Do not reuse the old keystore.
- **Service account key leaked:** delete the key in Google Cloud, create a new
  one, update `PLAY_SERVICE_ACCOUNT_JSON`, and review the Play Console
  permissions.
- **Apple certificate lost:** `fastlane match` can regenerate it from the
  `match` repository; if that repository is also lost, revoke the certificate
  in the Apple Developer portal and create a new one.

## Checklist

- [ ] Upload keystore generated and backed up off-machine.
- [ ] All four `ANDROID_*` GitHub secrets set.
- [ ] Play app created, app content completed, Play App Signing enabled.
- [ ] First AAB uploaded manually to internal testing and installed by a tester.
- [ ] Google service account created and granted app access (for fastlane).
- [ ] `production` environment exists with a required reviewer.
- [ ] Apple Developer Program membership and App Store Connect app record.
- [ ] App Store Connect API key and private `match` repository created.
- [ ] TestFlight upload verified.

## Related

- [Releases](release.md) — cutting a release and sideloading.
- [ADR 0007](decisions/0007-release-tooling.md) — plain Actions plus in-repo
  fastlane for store delivery.
