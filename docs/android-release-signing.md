# Android release signing (optional)

This template builds and runs in release mode out of the box, signed with
the Android debug key — that's enough for local testing but **not** for
publishing to the Play Store or distributing a signed build to testers.
This guide is for when you're ready to set up a real upload keystore. It is
entirely optional and not wired into any active pipeline by default — see
[`docs/ci-release-setup.md`](ci-release-setup.md) if you also want a CI
workflow to consume it.

## How signing already works here

`android/app/build.gradle.kts` is already set up to pick up a real keystore
automatically, with a safe fallback when one isn't present:

- It looks for `android/key.properties` (relative to the Android project
  root). If that file exists, it loads `keyAlias`, `keyPassword`,
  `storeFile` and `storePassword` from it and uses them to sign the
  `release` build type.
- If `android/key.properties` does **not** exist, the `release` build type
  falls back to signing with the **debug key**, so
  `flutter build apk --release` (and the Release launch configurations in
  `.vscode/launch.json`) keep working before you've set anything up.
- `android/key.properties` is **gitignored** (see `.gitignore`), and so is
  any `*.keystore` file — neither should ever be committed.

You don't need to edit `build.gradle.kts` to enable real signing; you only
need to create the keystore and fill in `android/key.properties`.

## 1. Generate an upload keystore

From any working directory (adjust the alias/validity/output path to
taste):

```
keytool -genkey -v -keystore upload-keystore.jks \
  -storetype JKS -keyalg RSA -keysize 2048 -validity 10000 \
  -alias upload
```

`keytool` will prompt for a store password, a key password, and the
certificate's distinguished-name fields (name, organization, etc.). Store
the resulting `.jks` file somewhere **outside the repository** — it should
never be committed, and losing it means you can no longer publish updates
to an app already on the Play Store under that signature.

## 2. Fill in `android/key.properties`

Copy the template that already ships in the repo:

```
cp android/key.properties.example android/key.properties
```

Then fill in the four values (`android/key.properties.example` documents
the same fields):

```properties
storePassword=<the keystore's store password>
keyPassword=<the key's password>
keyAlias=upload
storeFile=/absolute/or/relative/path/to/upload-keystore.jks
```

`storeFile` is resolved relative to the `android/` directory by
`build.gradle.kts` (`rootProject.file(...)`), so either an absolute path or
a path relative to `android/` works — an absolute path is less likely to
break if you move the keystore later.

## 3. Build a signed release

```
fvm flutter build apk --flavor prod --dart-define=FLAVOR=prod --release
```

(or `build appbundle` for a Play Store upload). Because
`android/key.properties` now exists, `build.gradle.kts` picks it up
automatically — no additional flags needed.

## 4. Verify the signature

Confirm the resulting APK is actually signed with your upload key, not the
debug fallback:

```
apksigner verify --print-certs build/app/outputs/flutter-apk/app-prod-release.apk
```

Check that the printed certificate fingerprint matches the one for your
upload keystore (`keytool -list -v -keystore upload-keystore.jks` prints the
same fingerprint for comparison).

## A note on passwords and AI agents

Type keystore and key passwords directly into a terminal prompt, never into
an AI chat window — including when asking an AI coding agent for help with
signing. A password pasted into a chat can end up logged, cached, or sent
to a model provider; `keytool`'s own interactive prompts (or an
environment variable read by your CI system, never printed) are the
appropriate place for a secret like this. If you ever do paste one into a
chat by mistake, rotate it (generate a new keystore/key) rather than
continuing to use it.
