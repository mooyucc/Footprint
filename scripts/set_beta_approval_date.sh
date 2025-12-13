#!/bin/bash
# Write BetaApprovalDate into Info.plist at archive time (UTC yyyy-MM-dd)
# Add this script as a Run Script phase AFTER “Copy Bundle Resources”
# Scope: Beta scheme / Archive builds

set -euo pipefail

# Only run for Beta configuration
if [[ "${CONFIGURATION:-}" != "Release" && "${CONFIGURATION:-}" != "Beta" ]]; then
  exit 0
fi

# Only run when building the Beta bundle id
if [[ "${PRODUCT_BUNDLE_IDENTIFIER:-}" != "Mooyu.Footprint.beta" ]]; then
  exit 0
fi

PLIST_PATH="${BUILT_PRODUCTS_DIR}/${INFOPLIST_PATH}"
if [[ ! -f "${PLIST_PATH}" ]]; then
  echo "Info.plist not found at ${PLIST_PATH}" >&2
  exit 1
fi

DATE_UTC="$(/bin/date -u +%Y-%m-%d)"
/usr/libexec/PlistBuddy -c "Set :BetaApprovalDate ${DATE_UTC}" "${PLIST_PATH}" \
  || /usr/libexec/PlistBuddy -c "Add :BetaApprovalDate string ${DATE_UTC}" "${PLIST_PATH}"

echo "BetaApprovalDate set to ${DATE_UTC} for ${PRODUCT_BUNDLE_IDENTIFIER}"

