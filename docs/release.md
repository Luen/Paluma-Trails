# Releases

## Versioning and release PRs

Version bumps and the changelog are managed by
[release-please](https://github.com/googleapis/release-please), driven by
Conventional Commits. It updates `version.txt`, `CHANGELOG.md`,
`app/pubspec.yaml` and `.release-please-manifest.json` together. Squash-merge
pull requests so each one is a single commit; merge commits make Release Please
list the same change twice. The exception is the `dev` → `main` promotion PR:
use a merge commit there so the individual commits reach `main` and appear in
the changelog.

Release Please needs a `RELEASE_PLEASE_TOKEN` secret. The built-in
`GITHUB_TOKEN` cannot be used for this: tags and releases it creates do not
trigger other workflows, so the Release workflow would never build the assets.

Create a fine-grained personal access token for only this repository with:

- **Contents:** read and write
- **Pull requests:** read and write
- **Issues:** read and write (release-please labels its PRs)
- **Metadata:** read

Save it as the `RELEASE_PLEASE_TOKEN` repository secret. Fine-grained tokens
expire; set a reminder and rotate the secret before it does.

### Cutting a release

1. Promote `dev` to `main` with a pull request and wait for CI.
2. Release Please opens or updates a `chore(main): release X.Y.Z` pull request
   with the next version and changelog. If it does not appear, run **Release
   Please → Run workflow** on `main` and check the warning in the job log.
3. Review the release PR, then merge it when CI is green. Merging creates the
   `vX.Y.Z` tag and a GitHub Release with the changelog.
4. The tag starts `.github/workflows/release.yml`, which builds and appends:

   - `app-release.aab` — Play Store upload
   - `app-arm64-v8a-release.apk`, `app-armeabi-v7a-release.apk` and
     `app-x86_64-release.apk` — sideload builds
   - `paluma-trails-web.tar.gz` — the Flutter web build
   - `SHA256SUMS`

   The Android `versionCode` is the workflow run number; the `versionName` is
   the tag without the leading `v`.

The version annotation in `app/pubspec.yaml` (`# x-release-please-version`) is
what keeps the app version in sync. Do not remove it. Release builds take the
version from the tag anyway, and the build number from the workflow run.

### Manual and hotfix tags

Manual tags still work if Release Please is unavailable or for a hotfix:

```sh
git switch main && git pull
git tag v0.2.1
git push origin v0.2.1
```

Tags containing a hyphen (for example `v0.2.0-rc.1`) are published as
prereleases. The Release workflow creates the release when it does not exist;
when Release Please already created it, the workflow appends the artifact
section instead of overwriting the changelog.

To test the build without publishing, run **Release → Run workflow** on `dev`
in the Actions tab. It uploads the same artifacts to the workflow run but does
not create a GitHub Release.

## Android sideloading

There is no universal APK. Pick the file that matches the phone:

| ABI | File | Typical device |
| --- | --- | --- |
| arm64-v8a | `app-arm64-v8a-release.apk` | most phones, including the Pixel 8 |
| armeabi-v7a | `app-armeabi-v7a-release.apk` | older 32-bit phones |
| x86_64 | `app-x86_64-release.apk` | emulators |

```sh
adb install -r app-arm64-v8a-release.apk
```

The `.aab` is only for Play; it is not installable with `adb`. Play delivers
just the phone's ABI, so the store download is much smaller than the AAB.

## Size budget

`app/tool/aab_size.sh` builds split APKs from the AAB with bundletool 1.18.3
for a Pixel 8 device spec and fails if the arm64 Play download exceeds 20 MB.
The workflow runs it on every release build and prints the artifact sizes in
the job summary. Current measurements (see #72) are about 14 MB for a Play
install and 29 MB for the arm64 sideload APK.

## Signing

`app/android/app/build.gradle.kts` reads `app/android/key.properties` when it
exists and otherwise falls back to debug signing. Generate the upload key with
`app/tool/create_upload_keystore.sh`, then set the four `ANDROID_*` secrets.
Without them the workflow still succeeds, but warns and publishes debug-signed
artifacts that are only suitable for sideload testing.

The full Android, Play Console and Apple checklist is in
[Signing and store credentials](signing.md).

Debug keys differ between machines, so uninstall an existing app before
installing a CI build if the signature does not match:

```sh
adb uninstall space.wanderstories.paluma_trails
adb install app-arm64-v8a-release.apk
```

Do not commit `key.properties` or the keystore; both are ignored by git.

## Not automated yet

- Play Store and App Store uploads, and the iOS IPA, wait for the signing setup
  in #66. Store delivery will use in-repo fastlane lanes once those secrets
  exist; see [ADR 0007](decisions/0007-release-tooling.md).
- Promotion from `dev` to `main` is still a manual pull request.
- The web image is published by the Release workflow; where it is deployed from
  is tracked in #69.
