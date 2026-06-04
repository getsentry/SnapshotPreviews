#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd -P)"
PROJECT_ROOT="$SCRIPT_DIR"

OUTPUT_DIR="$PROJECT_ROOT/XCFrameworks"
PROJECT_BUILD_DIR="${PROJECT_BUILD_DIR:-"$PROJECT_ROOT/build"}"
XCFRAMEWORK_BUILD_DIR="$PROJECT_BUILD_DIR/xcframeworks"
TEMP_PACKAGE_DIR="$XCFRAMEWORK_BUILD_DIR/package"
ARCHIVES_DIR="$XCFRAMEWORK_BUILD_DIR/archives"
DERIVED_DATA_DIR="$XCFRAMEWORK_BUILD_DIR/DerivedData"

FRAMEWORKS=(
  SnapshotSharedModels
  SnapshotPreviewsCore
  SnapshotPreferences
  PreviewGallery
  SnapshottingTests
  Snapshotting
)

SWIFT_MODULE_FRAMEWORKS=(
  SnapshotSharedModels
  SnapshotPreviewsCore
  SnapshotPreferences
  PreviewGallery
  SnapshottingTests
)

PLATFORMS=(
  "iphoneos|generic/platform=iOS"
  "iphonesimulator|generic/platform=iOS Simulator"
  "macosx|generic/platform=macOS"
  "watchos|generic/platform=watchOS"
  "watchsimulator|generic/platform=watchOS Simulator"
)

prepare_temp_package() {
  local framework="$1"

  if [ -d "$TEMP_PACKAGE_DIR" ]; then
    rm -r "$TEMP_PACKAGE_DIR"
  fi

  mkdir -p "$TEMP_PACKAGE_DIR"
  ln -s "$PROJECT_ROOT/Sources" "$TEMP_PACKAGE_DIR/Sources"
  ln -s "$PROJECT_ROOT/XCFrameworks" "$TEMP_PACKAGE_DIR/XCFrameworks"
  cp "$PROJECT_ROOT/XCFrameworkPackage.swift" "$TEMP_PACKAGE_DIR/Package.swift"
}

requires_swift_module() {
  local framework="$1"

  for swift_module_framework in "${SWIFT_MODULE_FRAMEWORKS[@]}"; do
    if [ "$swift_module_framework" = "$framework" ]; then
      return 0
    fi
  done

  return 1
}

build_framework_archive() {
  local framework="$1"
  local sdk="$2"
  local destination="$3"
  local archive_path="$ARCHIVES_DIR/$framework-$sdk.xcarchive"

  if [ -d "$archive_path" ]; then
    rm -r "$archive_path"
  fi

  SNAPSHOT_PREVIEWS_XCFRAMEWORK_PRODUCT="$framework" xcodebuild archive \
    -scheme "$framework" \
    -archivePath "$archive_path" \
    -derivedDataPath "$DERIVED_DATA_DIR/$framework" \
    -sdk "$sdk" \
    -destination "$destination" \
    BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
    INSTALL_PATH="Library/Frameworks" \
    SKIP_INSTALL=NO \
    OTHER_SWIFT_FLAGS="-no-verify-emitted-module-interface"

  copy_swift_module "$framework" "$sdk" "$archive_path"
}

copy_swift_module() {
  local framework="$1"
  local sdk="$2"
  local archive_path="$3"
  local configuration="Release-$sdk"

  if [ "$sdk" = "macosx" ]; then
    configuration="Release"
  fi

  local source_module_path="$DERIVED_DATA_DIR/$framework/Build/Intermediates.noindex/ArchiveIntermediates/$framework/BuildProductsPath/$configuration/$framework.swiftmodule"
  if [ ! -d "$source_module_path" ]; then
    if requires_swift_module "$framework"; then
      echo "Missing Swift module output for $framework at $source_module_path" >&2
      exit 1
    fi

    return
  fi

  local framework_path="$archive_path/Products/Library/Frameworks/$framework.framework"
  local modules_path="$framework_path/Modules"

  if [ "$sdk" = "macosx" ] && [ -d "$framework_path/Versions/A" ]; then
    modules_path="$framework_path/Versions/A/Modules"
    if [ -e "$framework_path/Modules" ]; then
      rm -r "$framework_path/Modules"
    fi
    ln -s "Versions/Current/Modules" "$framework_path/Modules"
  fi

  mkdir -p "$modules_path"
  if [ -d "$modules_path/$framework.swiftmodule" ]; then
    rm -r "$modules_path/$framework.swiftmodule"
  fi
  cp -r "$source_module_path" "$modules_path/$framework.swiftmodule"
  sanitize_swift_interfaces "$modules_path" "$framework"
}

sanitize_swift_interfaces() {
  local modules_path="$1"
  local framework="$2"

  find "$modules_path" -type f -name "*.private.swiftinterface" -delete
  find "$modules_path" -type f -name "*.swiftinterface" | while read -r file; do
    sed \
      -e '/NSInvocation/d' \
      -e 's/XCTest\.//g' \
      -e "s/${framework}\.//g" \
      "$file" > "$file.tmp"
    mv "$file.tmp" "$file"
  done
}

create_xcframework() {
  local framework="$1"
  local output_path="$OUTPUT_DIR/$framework.xcframework"
  local args=()

  for platform in "${PLATFORMS[@]}"; do
    local sdk="${platform%%|*}"
    args+=(
      -framework
      "$ARCHIVES_DIR/$framework-$sdk.xcarchive/Products/Library/Frameworks/$framework.framework"
    )
  done

  if [ -d "$output_path" ]; then
    rm -r "$output_path"
  fi

  xcodebuild -create-xcframework "${args[@]}" -output "$output_path"
}

copy_previews_support() {
  local source_path="$PROJECT_ROOT/PreviewsSupport/PreviewsSupport.xcframework"
  local output_path="$OUTPUT_DIR/PreviewsSupport.xcframework"

  if [ -d "$output_path" ]; then
    rm -r "$output_path"
  fi
  ditto "$source_path" "$output_path"
}

main() {
  mkdir -p "$OUTPUT_DIR" "$ARCHIVES_DIR"
  copy_previews_support

  for framework in "${FRAMEWORKS[@]}"; do
    prepare_temp_package "$framework"
    pushd "$TEMP_PACKAGE_DIR" >/dev/null
    for platform in "${PLATFORMS[@]}"; do
      sdk="${platform%%|*}"
      destination="${platform#*|}"
      build_framework_archive "$framework" "$sdk" "$destination"
    done
    popd >/dev/null

    create_xcframework "$framework"
  done

  echo "XCFrameworks written to $OUTPUT_DIR"
}

main "$@"
