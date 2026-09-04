#!/bin/bash
#
# PostToolUse hook: keep a shell script executable and shellcheck-clean.
#
# Two CI checks are mirrored here. `Check bundled scripts are executable` fails when a script lacks
# the bit — which the Write tool never sets, so every newly authored script fails it once. Restoring
# the bit is the fix in every case, so the hook applies it rather than reporting it. super-linter's
# VALIDATE_BASH is the other, and shellcheck runs only when it is installed.
#
# Two dependencies, both optional, both silent when absent: `jq` to read the hook payload, and
# `shellcheck` to lint. No `jq` means no bit restoration either — the payload is where the path
# comes from, so nothing below it runs.

set -uo pipefail

jq=$(command -v /usr/bin/jq || command -v jq) || exit 0

# Hooks match on the tool, never on the path, so every Write and Edit in this repository reaches
# this script whatever the file type. The check below is the only filter there is — not a second
# one behind some narrowing in settings.json.
file=$("$jq" -r '.tool_input.file_path // empty' 2>/dev/null) || exit 0
case "$file" in
  *.sh) ;;
  *) exit 0 ;;
esac

root="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null)}"
[ -n "$root" ] && [ -d "$root" ] || exit 0
root=$(cd "$root" && pwd -P) || exit 0
cd "$root" || exit 0

# Resolve the file and require containment before stripping the prefix. A trailing slash on the
# root, a symlinked project directory (/tmp against /private/tmp) or an --add-dir path outside the
# repository all defeat a bare prefix strip, and the case below would then match nothing — so the
# bit would go unrestored, silently, on the one path where restoring it mattered.
dir=$(cd "$(dirname -- "$file")" 2>/dev/null && pwd -P) || exit 0
file="$dir/$(basename -- "$file")"
case "$file" in
  "$root"/*) ;;
  *) exit 0 ;;
esac

rel="${file#"$root"/}"
[ -f "$rel" ] || exit 0

# Restores the bit everywhere CI requires it, this directory included, so a newly authored script
# gets it as it is written rather than after a failed build. One case is out of reach: a hook that
# has lost its own bit cannot exec, so it cannot chmod anything — which is why CI checks the
# directory as well rather than trusting the hook alone.
# -h before -x: chmod follows a symlink, so a script linked in from elsewhere would have its
# target's mode changed — silently, permanently, and outside the set this hook is meant to touch.
# Only the mutation is skipped; the shellcheck below still runs on it.
case "$rel" in
  skills/*|examples/*|scripts/*|.claude/hooks/*)
    [ -h "$rel" ] || [ -x "$rel" ] || chmod +x "$rel" ;;
  *) ;;
esac

command -v shellcheck >/dev/null 2>&1 || exit 0

if output=$(shellcheck -- "$rel" 2>&1); then
  exit 0
fi

# Diagnostics go to stderr: exit 2 hands stderr back to Claude, while stdout is transcript-only, so
# a message there reports that something is wrong without reporting what. shellcheck quotes file
# contents, which on a branch under review is untrusted text, so it is fenced as data.
{
  printf 'shellcheck found offenses in %s\n' "$rel"
  printf '<linter-output>\n%s\n</linter-output>\n' "$output"
} >&2
exit 2
