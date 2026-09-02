#!/bin/sh
set -e

# Xcode Cloud clones the repo fresh and has no knowledge of XcodeGen; Logjam.xcodeproj
# is gitignored (generated), so without this hook there's nothing to build.
brew install xcodegen

cd "$CI_PRIMARY_REPOSITORY_PATH"
xcodegen generate
