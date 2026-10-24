#!/bin/bash
# Proves a build is fit for App Review:
#   - no private API: no trace of the old descriptor hook (symbols, selector names,
#     class names, log text) and none of the runtime calls such a hook needs
#   - no Lemon Squeezy checkout / licence-key code (guideline 3.1.1)
#   - the StoreKit store is compiled in (proves Swift saw APPSTORE)
#   - the Home Screen name is the intended single U+0020 space
#
# Usage: Scripts/audit-appstore.sh path/to/WidgetSimple.app
# Exits non-zero if any check fails; prints every command it runs.
#
# The private names below are assembled from pieces on purpose: the repository must
# stay clean for a plain `grep -RIn` over the sources (see CHANGES.md), and this
# script is the one place that has to know what to look for in a binary.
set -euo pipefail

APP="${1:?usage: $0 path/to/WidgetSimple.app}"
fail=0

j() { local IFS=''; echo "$*"; }

# Everything the removed hook added to a binary: its own functions, the private
# selectors it sent, the private classes it looked up, and its log lines.
HOOK_PATTERNS=(
  "$(j Install Widget Descriptor Hook)"
  "$(j Hooked Get All Descriptors)"
  "$(j getAllCurrent Descriptors WithCompletion)"
  "$(j WidgetExtension XPC Server)"
  "$(j Descriptor Fetch Result)"
  "$(j set Trans parent:)"
  "$(j set Background Removable:)"
  "$(j set Preferred Background Style:)"
  "$(j background Removable)"
  "$(j preferred Background Style)"
  'install: hooked'
)
# Runtime calls nothing in this project may make.
FORBIDDEN_IMPORTS=(
  _method_setImplementation _method_getImplementation _method_exchangeImplementations
  _class_copyMethodList _class_copyIvarList
  "$(j _dl sym)" "$(j _dl open)" "$(j _NSClass From String)"
)
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
  imports="$(awk '{print $NF}' <<<"$undef")"
  for p in "${FORBIDDEN_IMPORTS[@]}"; do
    if grep -qxF -- "$p" <<<"$imports"; then echo "FAIL [$name] imports $p"; fail=1; fi
  done
  for p in "${EXTERNAL_PAYMENT[@]}"; do
    if grep -qiF -- "$p" <<<"$strs"; then echo "FAIL [$name] external payment trace: $p"; fail=1; fi
  done
  # Linked frameworks, for the record: only public system frameworks belong here.
  if command -v otool >/dev/null 2>&1; then
    echo "linked by [$name]:"
    otool -L "$bin" | tail -n +2 | sed 's/^/  /'
    if otool -L "$bin" | grep -q '/PrivateFrameworks/'; then
      echo "FAIL [$name] links a private framework"; fail=1
    fi
  fi
done

main="$APP/$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$APP/Info.plist")"
if strings -a "$main" | grep -qF com.rabetv.widgetsimple.pro.yearly; then
  echo "ok   StoreKit product id compiled into the app (Swift APPSTORE active)"
else
  echo "FAIL StoreKit product id missing: Swift did not see APPSTORE"; fail=1
fi

# The label under each widget is the app's display name: one U+0020 space, as MD Blank
# ships it (Config/Base.xcconfig). WidgetSimple is the documented 2.3.8 fallback.
shown="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleDisplayName' "$APP/Info.plist" 2>/dev/null || true)"
if [ "$shown" = " " ]; then
  echo "ok   CFBundleDisplayName is a single space (no label under the widget)"
elif [ "$shown" = "WidgetSimple" ]; then
  echo "ok   CFBundleDisplayName=WidgetSimple (2.3.8 fallback)"
else
  printf 'FAIL CFBundleDisplayName is %q (expected a single space)\n' "$shown"; fail=1
fi

if [ "$fail" -eq 0 ]; then
  echo "AUDIT PASSED: no private API, no external payment, StoreKit present, intended name."
else
  echo "AUDIT FAILED"
fi
exit "$fail"
