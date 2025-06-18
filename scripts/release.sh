#!/bin/bash

# Orchard Release Script
# Usage: ./scripts/release.sh [version]
# Example: ./scripts/release.sh 1.2.0

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if we're in the right directory
if [[ ! -f "Orchard.xcodeproj/project.pbxproj" ]]; then
    print_error "This script must be run from the desktop directory containing Orchard.xcodeproj"
    exit 1
fi

# Get version from argument or prompt
if [[ -n "$1" ]]; then
    VERSION="$1"
else
    print_info "Enter the new version number (e.g., 1.2.0):"
    read -r VERSION
fi

# Validate version format
if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    print_error "Invalid version format. Please use semantic versioning (e.g., 1.2.0)"
    exit 1
fi

TAG="v$VERSION"

print_info "Preparing release for version $VERSION"

# Check if tag already exists
if git rev-parse "$TAG" >/dev/null 2>&1; then
    print_error "Tag $TAG already exists"
    exit 1
fi

# Check if working directory is clean
if [[ -n $(git status --porcelain) ]]; then
    print_warning "Working directory is not clean. Uncommitted changes:"
    git status --short
    echo
    print_info "Do you want to continue? (y/N)"
    read -r continue_release
    if [[ "$continue_release" != "y" && "$continue_release" != "Y" ]]; then
        print_info "Release cancelled"
        exit 0
    fi
fi

# Update version in ContainerService.swift
print_info "Updating version in ContainerService.swift..."
if [[ -f "Orchard/ContainerService.swift" ]]; then
    # Update the currentVersion variable
    sed -i '' "s/let currentVersion = .*/let currentVersion = Bundle.main.infoDictionary?[\"CFBundleShortVersionString\"] as? String ?? \"$VERSION\"/" Orchard/ContainerService.swift
    print_success "Updated ContainerService.swift"
else
    print_warning "ContainerService.swift not found, skipping version update"
fi

# Create/update Info.plist if it doesn't exist
if [[ ! -f "Orchard/Info.plist" ]]; then
    print_info "Creating Info.plist..."
    cat > Orchard/Info.plist << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>\$(DEVELOPMENT_LANGUAGE)</string>
    <key>CFBundleExecutable</key>
    <string>\$(EXECUTABLE_NAME)</string>
    <key>CFBundleIconFile</key>
    <string></string>
    <key>CFBundleIdentifier</key>
    <string>\$(PRODUCT_BUNDLE_IDENTIFIER)</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>\$(PRODUCT_NAME)</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>$VERSION</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>12.0</string>
    <key>NSHumanReadableCopyright</key>
    <string></string>
    <key>NSMainStoryboardFile</key>
    <string>Main</string>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
</dict>
</plist>
EOF
    print_success "Created Info.plist"
else
    # Update existing Info.plist
    print_info "Updating version in Info.plist..."
    /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" Orchard/Info.plist 2>/dev/null || \
    /usr/libexec/PlistBuddy -c "Add :CFBundleShortVersionString string $VERSION" Orchard/Info.plist
    print_success "Updated Info.plist"
fi

# Create CHANGELOG entry
print_info "Creating CHANGELOG entry..."
if [[ ! -f "CHANGELOG.md" ]]; then
    cat > CHANGELOG.md << EOF
# Changelog

All notable changes to Orchard will be documented in this file.

## [$VERSION] - $(date +%Y-%m-%d)

### Added
- Initial release

### Changed
-

### Fixed
-

EOF
else
    # Add new version entry to existing changelog
    temp_file=$(mktemp)
    echo "# Changelog" > "$temp_file"
    echo "" >> "$temp_file"
    echo "All notable changes to Orchard will be documented in this file." >> "$temp_file"
    echo "" >> "$temp_file"
    echo "## [$VERSION] - $(date +%Y-%m-%d)" >> "$temp_file"
    echo "" >> "$temp_file"
    echo "### Added" >> "$temp_file"
    echo "- " >> "$temp_file"
    echo "" >> "$temp_file"
    echo "### Changed" >> "$temp_file"
    echo "- " >> "$temp_file"
    echo "" >> "$temp_file"
    echo "### Fixed" >> "$temp_file"
    echo "- " >> "$temp_file"
    echo "" >> "$temp_file"

    # Append existing changelog content (skip header)
    tail -n +4 CHANGELOG.md >> "$temp_file"
    mv "$temp_file" CHANGELOG.md
fi

print_success "Created CHANGELOG entry for version $VERSION"

# Commit changes
print_info "Committing version changes..."
git add .
git commit -m "Bump version to $VERSION"

# Create and push tag
print_info "Creating and pushing tag $TAG..."
git tag -a "$TAG" -m "Release version $VERSION"

print_info "Pushing changes and tag to remote..."
git push origin HEAD
git push origin "$TAG"

print_success "Release $VERSION has been tagged and pushed!"
print_info "GitHub Actions will now build and create the release automatically."
print_info "Monitor the progress at: https://github.com/$(git config --get remote.origin.url | sed 's/.*github.com[:/]\([^.]*\).*/\1/')/actions"

# Instructions for manual release if needed
echo
print_info "Manual release instructions (if GitHub Actions fails):"
echo "1. Go to https://github.com/$(git config --get remote.origin.url | sed 's/.*github.com[:/]\([^.]*\).*/\1/')/releases"
echo "2. Click 'Create a new release'"
echo "3. Choose tag '$TAG'"
echo "4. Set release title to 'Orchard $VERSION'"
echo "5. Copy the changelog content for this version"
echo "6. Upload the built .dmg file"

print_success "Release script completed successfully!"
