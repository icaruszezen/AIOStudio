#!/usr/bin/env bash
set -euo pipefail

if [[ "${GITHUB_REF:-}" == refs/tags/v* ]]; then
  VERSION="${GITHUB_REF#refs/tags/v}"
elif [[ -n "${INPUT_VERSION:-}" ]]; then
  VERSION="${INPUT_VERSION}"
else
  VERSION=$(grep '^version:' pubspec.yaml | sed 's/version: *//;s/+.*//')
  echo "::notice::No tag or input version — using pubspec.yaml version: $VERSION"
fi

echo "Expected version: $VERSION"

if ! [[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "::error::Version '$VERSION' is not valid semver (X.Y.Z)"
  exit 1
fi

ERRORS=0

PUBSPEC_VERSION=$(grep '^version:' pubspec.yaml | sed 's/version: *//;s/+.*//')
if [[ "$PUBSPEC_VERSION" != "$VERSION" ]]; then
  echo "::error::pubspec.yaml version ($PUBSPEC_VERSION) != tag ($VERSION)"
  ERRORS=$((ERRORS + 1))
else
  echo "  pubspec.yaml: $PUBSPEC_VERSION"
fi

EXT_PKG_VERSION=$(python3 -c "import json; print(json.load(open('extension/package.json'))['version'])")
if [[ "$EXT_PKG_VERSION" != "$VERSION" ]]; then
  echo "::error::extension/package.json version ($EXT_PKG_VERSION) != tag ($VERSION)"
  ERRORS=$((ERRORS + 1))
else
  echo "  extension/package.json: $EXT_PKG_VERSION"
fi

EXT_MANIFEST_VERSION=$(python3 -c "import json; print(json.load(open('extension/manifest.json'))['version'])")
if [[ "$EXT_MANIFEST_VERSION" != "$VERSION" ]]; then
  echo "::error::extension/manifest.json version ($EXT_MANIFEST_VERSION) != tag ($VERSION)"
  ERRORS=$((ERRORS + 1))
else
  echo "  extension/manifest.json: $EXT_MANIFEST_VERSION"
fi

MSIX_VERSION=$(grep 'msix_version:' pubspec.yaml | sed 's/.*msix_version: *//')
EXPECTED_MSIX="${VERSION}.0"
if [[ "$MSIX_VERSION" != "$EXPECTED_MSIX" ]]; then
  echo "::warning::msix_config version ($MSIX_VERSION) != expected ($EXPECTED_MSIX)"
else
  echo "  msix_config: $MSIX_VERSION"
fi

if [[ $ERRORS -gt 0 ]]; then
  echo "::error::Version validation failed with $ERRORS error(s). Update version numbers before tagging."
  exit 1
fi

echo "version=$VERSION" >> "$GITHUB_OUTPUT"
echo "All version checks passed for v$VERSION"
