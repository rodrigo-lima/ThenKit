#!/bin/sh

set -e

BUILD_SETTINGS=build-settings.txt

# clean up
rm -rf .build
rm -rf Builds
rm -rf ThenKit.xcodeproj

# swift package
swift package generate-xcodeproj --enable-code-coverage -v

# Get build settings
xcodebuild -scheme ThenKit -showBuildSettings > ${BUILD_SETTINGS}

# build
xcodebuild -scheme ThenKit -enableCodeCoverage YES test
# | xcpretty

# Project Temp Root ends up with /Build/Intermediates/
PROJECT_TEMP_ROOT=$(grep -m1 PROJECT_TEMP_ROOT ${BUILD_SETTINGS} | cut -d= -f2 | xargs)
PROFDATA=$(find ${PROJECT_TEMP_ROOT} -name "Coverage.profdata")
BINARY=$(find ${PROJECT_TEMP_ROOT} -path "*ThenKit.framework/ThenKit")

echo "PROJECT_TEMP_ROOT = $PROJECT_TEMP_ROOT"
# echo "PROFDATA          = $PROFDATA"
# echo "BINARY            = $BINARY"

xcrun llvm-cov report \
    -instr-profile ${PROFDATA} \
    ${BINARY}

rm $BUILD_SETTINGS
