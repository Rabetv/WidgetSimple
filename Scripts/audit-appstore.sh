#!/bin/bash
# Proves a build is fit for App Review:
#   - no private API: no trace of the old descriptor hook (symbols, selector names,
#     class names, log text) and none of the runtime calls such a hook needs; the one
#     dynamic symbol lookup import allowed is the one clang's own runtime adds
#     (see "Dynamic symbol lookup" below and CHANGES.md)
#   - no Lemon Squeezy checkout / licence-key code (guideline 3.1.1)
#   - the StoreKit store is compiled in (proves Swift saw APPSTORE)
#   - the Home Screen name is the intended single U+0020 space
#
# Usage: Scripts/audit-appstore.sh path/to/WidgetSimple.app [link-map-folder]
#   link-map-folder: where the linker wrote its maps (LD_GENERATE_MAP_FILE=YES).
#   Without it, a binary that imports the dynamic symbol lookup function fails,
#   because there is no way to tell who references it.
# Exits non-zero if any check fails; prints every command it runs.
#
# The private names below are assembled from pieces on purpose: the repository must
# stay clean for a plain `grep -RIn` over the sources (see CHANGES.md), and this
# script is the one place that has to know what to look for in a binary.
set -euo pipefail

APP="${1:?usage: $0 path/to/WidgetSimple.app [link-map-folder]}"
LINKMAPS="${2:-}"
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

# --- Dynamic symbol lookup ----------------------------------------------------------
# Every Swift binary that has an availability check (`#available`, `@available`) links
# clang's compiler runtime, whose os_version_check.c.o looks up the OS version function
# by name. That makes the lookup function an import of our binaries although no source
# calls it (CI run 40080516837 traced it). It passes only when the linker map shows that
# object as its sole referencer; any other referencer, or no map to prove it, fails.
LOOKUP="$(j _dl sym)"
ALLOWED_LOOKUP_REFERENCER='/libclang_rt\.[A-Za-z0-9_]+\.a:os_version_check\.c\.o$'

# The map whose "# Path:" line ends in this binary's file name.
linkmap_for() {
  local file
  [ -n "$LINKMAPS" ] && [ -d "$LINKMAPS" ] || return 0
  file="$(basename "$1")"
  grep -l -E "^# Path: .*/${file}\$" "$LINKMAPS"/*.txt 2>/dev/null | head -1 || true
}

# Every linked input that references LOOKUP: "archive:member" or "object".
lookup_referencers() {
  awk '/^# Object files:/{on=1; next} /^# /{on=0} on' "$1" | sed -E 's/^\[ *[0-9]+\] //' |
    while IFS= read -r input; do
      case "$input" in
        *.a\(*|*.a\[*)
          archive="$(sed -E 's/(\.a)[[(].*/\1/' <<<"$input")"
          member="$(sed -E 's/.*\(([^()]*)\)$/\1/' <<<"$input")"
          if nm -A -u "$archive" 2>/dev/null | grep -F -- "$archive:$member:" | grep -qw -- "$LOOKUP"; then
            echo "$archive:$member"
          fi ;;
        *.o)
          if nm -u "$input" 2>/dev/null | grep -qxF -- "$LOOKUP"; then echo "$input"; fi ;;
      esac
    done | sort -u
}

check_lookup() {
  local bin="$1" name="$2" map refs other
  map="$(linkmap_for "$bin")"
  if [ -z "$map" ]; then
    echo "FAIL [$name] imports $LOOKUP and no link map shows who references it (pass the map folder)"
    return 1
  fi
  refs="$(lookup_referencers "$map")"
  if [ -z "$refs" ]; then
    echo "FAIL [$name] imports $LOOKUP but no linked input in $map references it"
    return 1
  fi
  other="$(grep -vE -- "$ALLOWED_LOOKUP_REFERENCER" <<<"$refs" || true)"
  if [ -n "$other" ]; then
    echo "FAIL [$name] $LOOKUP is referenced by more than clang's availability runtime:"
    sed 's/^/       /' <<<"$other"
    return 1
  fi
  echo "ok   [$name] $LOOKUP comes only from clang's availability-check runtime ($refs)"
}

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
    grep -qxF -- "$p" <<<"$imports" || continue
    if [ "$p" = "$LOOKUP" ]; then
      check_lookup "$bin" "$name" || fail=1
    else
      echo "FAIL [$name] imports $p"; fail=1
    fi
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
