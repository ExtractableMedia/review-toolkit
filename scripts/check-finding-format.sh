#!/bin/bash
#
# Checks a review file against reference/finding-format.md.
#
#   scripts/check-finding-format.sh examples/sample-review.md
#
# Point it at the golden sample in CI, or at any generated local-review.md or *-DOC-REVIEW.md to
# check a real review before posting it.
#
# The format used to be enforced mechanically by a heading regex in the deleted MCP server. Nothing
# replaced it, and the sample fixture drifted from the spec unnoticed until a human read both files
# side by side. These are the five things that actually broke, in the order they are cheapest to
# check.
#
# Exit: 0 conforms, 1 does not, 2 could not run.

set -uo pipefail

file="${1:-}"
[ -n "$file" ] || { echo "usage: $0 <review-file>" >&2; exit 2; }
[ -f "$file" ] || { echo "no such file: $file" >&2; exit 2; }

rc=0
fail() { echo "$file: $*" >&2; rc=1; }

# Findings quote review markup while discussing it, so a table row or checklist item inside a
# finding body is illustration, not data. Read each only from the section that owns it. Match on the
# word, not the whole heading: reviews title these sections both "## Summary" / "## Checklist" and
# "## Consolidated Summary" / "## Pre-Merge Checklist", and the spec blesses neither spelling.
section() { awk -v w="$1" '/^## /{f = ($0 ~ w); next} f' "$file"; }
summary=$(section 'Summary')
checklist_body=$(section 'Checklist')

# comm compares line by line and needs its inputs in the same collating order. These are numeric
# strings, so a numeric sort and a lexicographic one disagree (2 vs 10) and comm silently reports
# nonsense for either side.
lex() { printf '%s\n' "$1" | sed '/^$/d' | sort; }

# Anchor every ID extraction: a finding's description routinely cites other findings ("fixes F2,
# narrows F35"), and an unanchored match collects those too.
ids() { grep -oE "$2" <<< "$1" | grep -oE '[0-9]+' | sort -n | uniq; }

headings_raw=$(grep -E '^### F[0-9]+' "$file")
[ -n "$headings_raw" ] || { echo "$file: no findings found — is this a review file?" >&2; exit 2; }

# Icon and label are one unit: the table in the spec pairs them, so 🔴 Observation is as wrong as an
# invented label.
labels='🔴 Critical|🟠 High Priority|🟡 Medium Priority|🟢 Low Priority|ℹ️ Observation'

# 1. Heading grammar. Two shapes: open, or struck through with a status marker.
while IFS= read -r line; do
  if [[ "$line" == *'~~'* ]]; then
    grep -qE "^### F[0-9]+ ~~($labels) - .+~~ (✅|☑️|⏸️|🚫) [A-Za-z]+$" <<< "$line" \
      || fail "malformed resolved heading: $line"
  else
    grep -qE "^### F[0-9]+ ($labels) - .+$" <<< "$line" \
      || fail "malformed heading: $line"
  fi
done <<< "$headings_raw"

# 2. IDs form a single unbroken sequence from F1. Document order is by reviewer section rather than
# by number, so this is a check on the set, not the order.
all=$(grep -oE '^### F[0-9]+' <<< "$headings_raw" | grep -oE '[0-9]+' | sort -n)
unique=$(uniq <<< "$all")
if [ "$(wc -l <<< "$all")" -ne "$(wc -l <<< "$unique")" ]; then
  fail "duplicate finding IDs: $(uniq -d <<< "$all" | tr '\n' ' ')"
fi
expected=$(seq 1 "$(tail -1 <<< "$unique")")
gap=$(comm -13 <(lex "$unique") <(lex "$expected"))
[ -z "$gap" ] || fail "gap in finding IDs: $(tr '\n' ' ' <<< "$gap")"

# 3. The summary table covers every finding and invents none.
table=$(ids "$summary" '^\| F[0-9]+ \|')
only_heading=$(comm -23 <(lex "$unique") <(lex "$table"))
only_table=$(comm -13 <(lex "$unique") <(lex "$table"))
[ -z "$only_heading" ] || fail "missing from summary table: $(tr '\n' ' ' <<< "$only_heading")"
[ -z "$only_table" ] || fail "in summary table but not a finding: $(tr '\n' ' ' <<< "$only_table")"

# 4. The checklist holds every actionable finding and no observation. A status marker may sit before
# the ID or after the description; both are in use.
observations=$(grep -E '^### F[0-9]+ (~~)?ℹ️' <<< "$headings_raw" \
  | grep -oE '^### F[0-9]+' | grep -oE '[0-9]+' | sort -n)
actionable=$(comm -23 <(lex "$unique") <(lex "$observations"))
checked=$(ids "$checklist_body" '^- \[[ x]\] [^F]*F[0-9]+')
missing_actionable=$(comm -23 <(lex "$actionable") <(lex "$checked"))
listed_observations=$(comm -12 <(lex "$observations") <(lex "$checked"))
[ -z "$missing_actionable" ] \
  || fail "actionable findings missing from checklist: $(tr '\n' ' ' <<< "$missing_actionable")"
[ -z "$listed_observations" ] \
  || fail "observations listed in the checklist: $(tr '\n' ' ' <<< "$listed_observations")"

# 5. Status agrees between the heading and the summary table. This is the drift that motivated the
# checker: resolving a finding means striking its heading AND marking the table, and doing only the
# second leaves a heading that is still perfectly well-formed, so nothing above catches it.
mark_of() {
  case "$1" in
    *✅*) echo '✅';; *☑️*) echo '☑️';; *⏸️*) echo '⏸️';; *🚫*) echo '🚫';; *) echo '-';;
  esac
}
# Read the Status cell alone. A finding whose subject *is* a status marker puts the icon in its own
# description — F14 of this repo's own review does exactly that — so scanning the whole row reports
# a status the table never set.
status_cell() { awk -F'|' '{print $(NF - 1)}' <<< "$1"; }
while IFS= read -r line; do
  id=$(grep -oE '^### F[0-9]+' <<< "$line" | grep -oE '[0-9]+')
  if [[ "$line" == *'~~'* ]]; then
    head_mark=$(mark_of "${line##*\~\~}")
  else
    head_mark='-'
  fi
  row=$(grep -m1 -E "^\| F$id \|" <<< "$summary")
  # A missing row is check 3's finding, not this one.
  [ -n "$row" ] || continue
  table_mark=$(mark_of "$(status_cell "$row")")
  [ "$head_mark" = "$table_mark" ] \
    || fail "F$id status disagrees: heading says '$head_mark', summary table says '$table_mark'"
done <<< "$headings_raw"

[ $rc -eq 0 ] && echo "$file: OK"
exit $rc
