# Logjam

Personal iOS app for tracking listens across a Discogs-imported vinyl collection. See [CLAUDE.md](CLAUDE.md) for the full spec.

## Setup

1. Install [XcodeGen](https://github.com/yonaskolb/XcodeGen) if you don't have it: `brew install xcodegen`
2. Generate the Xcode project: `xcodegen generate`
3. Open `Logjam.xcodeproj` in Xcode.
4. Select the `Logjam` target → **Signing & Capabilities** → set your Development Team (needed for the iCloud/CloudKit capability to provision correctly).
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

Once set up (see below), getting a code change onto your phone is just:

```
git tag v1.2.0
git push --tags
```

That triggers [.github/workflows/release-ipa.yml](.github/workflows/release-ipa.yml), which builds an unsigned `.ipa`, attaches it to a GitHub Release, and updates [altstore-source.json](altstore-source.json) to point at it. Open AltStore on your phone (AltServer running on your Mac, same Wi-Fi), pull to refresh the source, and tap Update.

### One-time setup

1. In the repo's GitHub Settings → Actions → General → Workflow permissions, select **Read and write permissions** (needed so the workflow can create releases and commit `altstore-source.json` back to `main`).
2. In AltStore on your phone: **Browse** tab → the `+` in the top-left → paste in `https://raw.githubusercontent.com/LanceCo/logjam/main/altstore-source.json` → Add.
3. Tag and push a release as above. Check the Actions tab on GitHub if it doesn't show up in AltStore within a few minutes.
