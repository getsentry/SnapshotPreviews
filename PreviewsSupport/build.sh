#!/bin/bash

set -e

xcodebuild archive \
 -scheme PreviewsSupport \
 -archivePath ./PreviewsSupport-iphonesimulator.xcarchive \
 -sdk iphonesimulator \
 -destination 'generic/platform=iOS Simulator' \
 BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
 INSTALL_PATH='Library/Frameworks' \
 SKIP_INSTALL=NO \
 CLANG_CXX_LANGUAGE_STANDARD=c++17

xcodebuild archive \
 -scheme PreviewsSupport \
 -archivePath ./PreviewsSupport-iphoneos.xcarchive \
 -sdk iphoneos \
 -destination 'generic/platform=iOS' \
 BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
 INSTALL_PATH='Library/Frameworks' \
 SKIP_INSTALL=NO \
 CLANG_CXX_LANGUAGE_STANDARD=c++17

xcodebuild archive \
 -scheme PreviewsSupport \
 -archivePath ./PreviewsSupport-watchossimulator.xcarchive \
 -sdk watchsimulator \
 -destination 'generic/platform=watchOS Simulator' \
 BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
 INSTALL_PATH='Library/Frameworks' \
 SKIP_INSTALL=NO \
 CLANG_CXX_LANGUAGE_STANDARD=c++17

xcodebuild archive \
 -scheme PreviewsSupport \
 -archivePath ./PreviewsSupport-tvos.xcarchive \
 -sdk appletvos \
 -destination 'generic/platform=tvOS' \
 BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
 INSTALL_PATH='Library/Frameworks' \
 SKIP_INSTALL=NO \
 CLANG_CXX_LANGUAGE_STANDARD=c++17

xcodebuild archive \
 -scheme PreviewsSupport \
 -archivePath ./PreviewsSupport-tvossimulator.xcarchive \
 -sdk appletvsimulator \
 -destination 'generic/platform=tvOS Simulator' \
 BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
 INSTALL_PATH='Library/Frameworks' \
 SKIP_INSTALL=NO \
 CLANG_CXX_LANGUAGE_STANDARD=c++17

xcodebuild archive \
 -scheme PreviewsSupport \
 -archivePath ./PreviewsSupport-watchos.xcarchive \
 -sdk watchos \
 -destination 'generic/platform=watchOS' \
 BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
 INSTALL_PATH='Library/Frameworks' \
 SKIP_INSTALL=NO \
 CLANG_CXX_LANGUAGE_STANDARD=c++17

xcodebuild archive \
 -scheme PreviewsSupport \
 -archivePath ./PreviewsSupport-visionossimulator.xcarchive \
 -sdk xrsimulator \
 -destination 'generic/platform=visionOS Simulator' \
 BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
 INSTALL_PATH='Library/Frameworks' \
 SKIP_INSTALL=NO \
 CLANG_CXX_LANGUAGE_STANDARD=c++17

xcodebuild archive \
 -scheme PreviewsSupport \
 -archivePath ./PreviewsSupport-visionos.xcarchive \
 -sdk xros \
 BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
 INSTALL_PATH='Library/Frameworks' \
 SKIP_INSTALL=NO \
 CLANG_CXX_LANGUAGE_STANDARD=c++17

xcodebuild archive \
 -scheme PreviewsSupport \
 -archivePath ./PreviewsSupport-catalyst.xcarchive \
 -sdk macosx \
 -destination 'generic/platform=macOS,variant=Mac Catalyst' \
 BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
 INSTALL_PATH='Library/Frameworks' \
 SKIP_INSTALL=NO \
 CLANG_CXX_LANGUAGE_STANDARD=c++17

xcodebuild archive \
 -scheme PreviewsSupport \
 -archivePath ./PreviewsSupport-macosx.xcarchive \
 -sdk macosx \
 -destination 'generic/platform=macOS' \
 BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
 INSTALL_PATH='Library/Frameworks' \
 SKIP_INSTALL=NO \
 CLANG_CXX_LANGUAGE_STANDARD=c++17

xcodebuild -create-xcframework \
 -framework ./PreviewsSupport-iphonesimulator.xcarchive/Products/Library/Frameworks/PreviewsSupport.framework \
 -framework ./PreviewsSupport-iphoneos.xcarchive/Products/Library/Frameworks/PreviewsSupport.framework \
 -framework ./PreviewsSupport-watchossimulator.xcarchive/Products/Library/Frameworks/PreviewsSupport.framework \
 -framework ./PreviewsSupport-watchos.xcarchive/Products/Library/Frameworks/PreviewsSupport.framework \
 -framework ./PreviewsSupport-tvossimulator.xcarchive/Products/Library/Frameworks/PreviewsSupport.framework \
 -framework ./PreviewsSupport-tvos.xcarchive/Products/Library/Frameworks/PreviewsSupport.framework \
 -framework ./PreviewsSupport-visionos.xcarchive/Products/Library/Frameworks/PreviewsSupport.framework \
 -framework ./PreviewsSupport-visionossimulator.xcarchive/Products/Library/Frameworks/PreviewsSupport.framework \
 -framework ./PreviewsSupport-macosx.xcarchive/Products/Library/Frameworks/PreviewsSupport.framework \
 -framework ./PreviewsSupport-catalyst.xcarchive/Products/Library/Frameworks/PreviewsSupport.framework \
 -output ./PreviewsSupport.xcframework
