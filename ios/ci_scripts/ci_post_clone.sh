#!/bin/sh

#  FamilyPulse
#  ci_post_clone.sh - Xcode Cloud post-clone script
#
#  Installs CocoaPods dependencies after cloning the repository.

set -e

echo "Running ci_post_clone.sh - Installing CocoaPods dependencies..."

# Install CocoaPods if not already available
if ! command -v pod &> /dev/null; then
    echo "CocoaPods not found, installing..."
    export GEM_HOME="$HOME/.gem"
    gem install cocoapods --user-install --no-document
    export PATH="$PATH:$HOME/.gem/bin"
fi

# Install Pod dependencies
cd "$CI_PRIMARY_REPOSITORY_PATH"
pod install --repo-update

echo "CocoaPods installation complete."
