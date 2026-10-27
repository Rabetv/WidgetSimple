#!/bin/bash
# Proves an `appstore`-flavour build is fit for App Review:
#   - no trace of the descriptor hook removed from the project (a regression guard)
#   - no Lemon Squeezy checkout / licence-key code (guideline 3.1.1)
#   - the StoreKit store is compiled in (proves Swift saw APPSTORE)
#   - a visible name under the icon (guideline 2.3.8)
#
# Usage: Scripts/audit-appstore.sh path/to/WidgetSimple.app
# Exits non-zero on the first category that fails; prints every command it runs.
set -euo pipefail

APP="${1:?usage: $0 path/to/WidgetSimple.app}"
fail=0

# Everything the removed hook would add to a binary: its own functions, the private selectors it
# sends, the private classes it looks up, and its log lines.
HOOK_PATTERNS=(
  InstallWidgetDescriptorHook
  HookedGetAllDescriptors
  OriginalGetAllDescriptors
  getAllCurrentDescriptorsWithCompletion
  WidgetExtensionXPCServer
  DescriptorFetchResult
  setTransparent:
  setBackgroundRemovable:
  setPreferredBackgroundStyle:
  backgroundRemovable
  preferredBackgroundStyle
  'install: hooked'
  'XPC server class not found'
)
# Runtime calls nothing in this project makes; their import means swizzling came back.
HOOK_IMPORTS=(_method_setImplementation _method_getImplementation _class_copyMethodList _class_copyIvarList)
EXTERNAL_PAYMENT=(lemonsqueezy YOURSTORE 'licence key' license_key)

run() { echo "+ $*" >&2; "$@"; }

BINARIES=()
while IFS= read -r -d '' f; do
  if file -b "$f" | grep -q 'Mach-O'; then BINARIES+=("$f"); fi
done < <(find "$APP" -type f -print0)
[ "${#BINARIES[@]}" -gt 0 ] || { echo "no Mach-O binaries under $APP"; exit 2; }
echo "Mach-O binaries:"; printf '  %s\n' "${BINARIES[@]}"

for bin in "${BINARIES[@]}"; do
  name="${bin#"$APP"/}"
  syms="$(run nm -a "$bin" 2>/dev/null || true)"
  undef="$(run nm -u "$bin" 2>/dev/null || true)"
  strs="$(run strings -a "$bin")"
  for p in "${HOOK_PATTERNS[@]}"; do
    if grep -qF -- "$p" <<<"$syms$strs"; then echo "FAIL [$name] hook trace: $p"; fail=1; fi
  done
  for p in "${HOOK_IMPORTS[@]}"; do
    if grep -qxF -- "$p" <<<"$(awk '{print $NF}' <<<"$undef")"; then echo "FAIL [$name] imports $p"; fail=1; fi
  done
  for p in "${EXTERNAL_PAYMENT[@]}"; do
    if grep -qiF -- "$p" <<<"$strs"; then echo "FAIL [$name] external payment trace: $p"; fail=1; fi
  done
done

main="$APP/$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$APP/Info.plist")"
# Read everything first: grep -q stops at the first match, and the closed pipe would
# make strings fail under pipefail even though the id is there.
main_strings="$(strings -a "$main")"
if grep -qF com.rabetv.widgetsimple.pro.yearly <<<"$main_strings"; then
  echo "ok   StoreKit product id compiled into the app (Swift APPSTORE active)"
else
  echo "FAIL StoreKit product id missing: Swift did not see APPSTORE"; fail=1
fi

# The widget gallery and the label under each widget use the app's display name.
shown="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleDisplayName' "$APP/Info.plist" 2>/dev/null || true)"
if [ "$shown" = "WidgetSimple" ]; then
  echo "ok   CFBundleDisplayName=WidgetSimple"
else
  echo "FAIL CFBundleDisplayName is '$shown' (2.3.8)"; fail=1
fi

if [ "$fail" -eq 0 ]; then
  echo "AUDIT PASSED: no private-API hook, no external payment, StoreKit present, visible name."
else
  echo "AUDIT FAILED"
fi
exit "$fail"
