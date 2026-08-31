# Logjam

Personal iOS app for tracking listens across a Discogs-imported vinyl collection. See [CLAUDE.md](CLAUDE.md) for the full spec.

This is a single-user project built for my own collection — the bundle identifier and iCloud container in [project.yml](project.yml) (`com.lanceconzett.Logjam`) are tied to my Apple ID. The steps below build and run it as-is on my own devices. If you want to adapt this for yourself, you'll also need to change `PRODUCT_BUNDLE_IDENTIFIER` and the `com.apple.developer.icloud-container-identifiers` entry in `project.yml` to something under your own account first — setting your Development Team alone isn't enough, since Apple won't let you provision a bundle ID or iCloud container that's already registered under someone else's account.

## Setup

1. Install [XcodeGen](https://github.com/yonaskolb/XcodeGen) if you don't have it: `brew install xcodegen`
2. Generate the Xcode project: `xcodegen generate`
3. Open `Logjam.xcodeproj` in Xcode.
4. Select the `Logjam` target → **Signing & Capabilities** → set your Development Team.
5. Build and run on a simulator or device.
6. In the app, go to **Settings** and enter:
   - Your Discogs username
   - A personal access token from [discogs.com/settings/developers](https://www.discogs.com/settings/developers)
7. Go to **Library** and pull to refresh (or tap the sync button) to import your collection.

## Regenerating the project

The `.xcodeproj` is generated from [project.yml](project.yml) and is gitignored. After pulling changes or editing `project.yml`, re-run:

```
xcodegen generate
```

## Shipping a new build via AltStore

This section documents my own deployment pipeline, not a general project feature — it's wired to my GitHub repo and my AltStore source. Reusing it for your own fork means updating the source URL in step 2 below and the `iconURL`/`sourceURL` fields in [altstore-source.json](altstore-source.json) to point at your own repo.

Once set up (see below), getting a code change onto my phone is just:

```
git tag v1.2.0
git push --tags
```

That triggers [.github/workflows/release-ipa.yml](.github/workflows/release-ipa.yml), which builds an unsigned `.ipa`, attaches it to a GitHub Release, and updates [altstore-source.json](altstore-source.json) to point at it. Open AltStore on my phone (AltServer running on my Mac, same Wi-Fi), pull to refresh the source, and tap Update.

### One-time setup

1. In the repo's GitHub Settings → Actions → General → Workflow permissions, select **Read and write permissions** (needed so the workflow can create releases and commit `altstore-source.json` back to `main`).
2. In AltStore on my phone: **Browse** tab → the `+` in the top-left → paste in `https://raw.githubusercontent.com/LanceCo/logjam/main/altstore-source.json` → Add.
3. Tag and push a release as above. Check the Actions tab on GitHub if it doesn't show up in AltStore within a few minutes.
