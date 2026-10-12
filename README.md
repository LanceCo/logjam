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

## Shipping a new build

Builds ship via Xcode Cloud to TestFlight. Pushing to `main` (or tagging a release, depending on how the Xcode Cloud workflow is configured) triggers a build; Xcode Cloud regenerates the Xcode project via [ci_scripts/ci_post_clone.sh](ci_scripts/ci_post_clone.sh) since `Logjam.xcodeproj` is gitignored. Install updates through the TestFlight app.
