#!/bin/bash
#
# PostToolUse hook: lint a Markdown file the moment it is written.
#
# CI is the authority — super-linter runs markdownlint over the whole tree with the rules in
# .markdown-lint.yml. This runs those same rules against the one file that just changed, so a
# wrapped table or an over-long line surfaces while the edit is still in context instead of after a
# push.
#
# Two dependencies, both optional, both silent when absent: `jq` to read the hook payload, and
# `markdownlint` to lint. markdownlint is not vendored — this repository has no package.json and no
# Node dependency, and adding one to lint Markdown would be a poor trade — so install it with
# `npm install -g markdownlint-cli`. Missing either leaves the hook inert and CI still catches the
# offense.

set -uo pipefail

jq=$(command -v /usr/bin/jq || command -v jq) || exit 0

# Hooks match on the tool, never on the path, so every Write and Edit in this repository reaches
# this script whatever the file type. The check below is the only filter there is — not a second
# one behind some narrowing in settings.json.
file=$("$jq" -r '.tool_input.file_path // empty' 2>/dev/null) || exit 0
case "$file" in
  *.md) ;;
  *) exit 0 ;;
esac

command -v markdownlint >/dev/null 2>&1 || exit 0

root="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null)}"
[ -n "$root" ] && [ -d "$root" ] || exit 0
root=$(cd "$root" && pwd -P) || exit 0
cd "$root" || exit 0

# Resolve the file and require containment before stripping the prefix. A trailing slash on the
# root, a symlinked project directory (/tmp against /private/tmp) or an --add-dir path outside the
# repository all defeat a bare prefix strip, and `[ -f ]` still passes afterwards because an
# absolute path to a real file is a real file. markdownlint-cli then throws on the un-relativized
# path, and the hook reports offenses in a file it never linted.
dir=$(cd "$(dirname -- "$file")" 2>/dev/null && pwd -P) || exit 0
file="$dir/$(basename -- "$file")"
case "$file" in
  "$root"/*) ;;
  *) exit 0 ;;
esac

# --ignore-path is passed explicitly and the path made relative: the patterns in .markdownlintignore
# are anchored to the repository root, so an absolute argument would match none of them and the
# untracked working files in the root would be linted as documentation.
rel="${file#"$root"/}"
[ -f "$rel" ] || exit 0

if output=$(markdownlint --config .markdown-lint.yml \
    --ignore-path .markdownlintignore -- "$rel" 2>&1); then
  exit 0
fi

# Diagnostics go to stderr: exit 2 hands stderr back to Claude, while stdout is transcript-only, so
# a message on stdout reports that something is wrong without reporting what. The linter quotes file
# contents, which on a branch under review is untrusted text, so it is fenced as data.
{
  printf 'markdownlint found offenses in %s\n' "$rel"
  printf '<linter-output>\n%s\n</linter-output>\n' "$output"
} >&2
exit 2
