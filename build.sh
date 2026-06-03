#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd -P)"

ruby "$SCRIPT_DIR/scripts/build_xcframework_distribution.rb"
ruby "$SCRIPT_DIR/scripts/validate_xcframework_distribution.rb"
