#!/bin/bash
#
# Prints the context /doc-review needs before it dispatches a reviewer: whether the named document
# exists and what kind of file it is, the review file its name derives, whether that file already
# exists and which document it reviews, and the branch and commit the review will record.
#
# Everything here is deterministic and was previously left to prose — deriving a filename, spotting a
# basename collision, reading a page count. A script gets it the same way every run.

# No -e: this script reports context and must always produce output, even for a document that does
# not exist — a failed check should print a gap, not abort the skill. Injected context that fails
# aborts the whole invocation.
set -u

# The skill passes $ARGUMENTS as one quoted word, but a user who quoted the path themselves produces
# a doubled quote that the shell splits back into words. Rejoin them, drop the quotes, trim.
doc="$*"
doc="${doc#\"}"; doc="${doc%\"}"
doc="${doc#\'}"; doc="${doc%\'}"
doc="${doc#"${doc%%[![:space:]]*}"}"
doc="${doc%"${doc##*[![:space:]]}"}"

if [ -z "$doc" ]; then
  echo "Document: (none named)"
  exit 0
fi

# A name starting with `-` reads as an option to every tool below. Anchor it instead of relying on
# each tool honoring `--`, which poppler's do not.
case "$doc" in -*) doc="./$doc" ;; esac

echo "Document: $doc"

if [ ! -e "$doc" ]; then
  echo "Exists: no"
  exit 0
elif [ -d "$doc" ]; then
  echo "Exists: no — that is a directory, not a document"
  exit 0
fi
echo "Exists: yes"

base=$(basename -- "$doc")
ext="${base##*.}"
[ "$ext" != "$base" ] || ext=""
size=$(wc -c < "$doc" | tr -d ' ')

case "$(printf '%s' "$ext" | tr '[:upper:]' '[:lower:]')" in
  pdf)
    echo "Type: PDF ($size bytes)"
    if command -v pdfinfo > /dev/null 2>&1; then
      pages=$(pdfinfo "$doc" 2> /dev/null | awk '/^Pages:/ {print $2}')
      echo "Pages: ${pages:-(pdfinfo could not read the file)}"
    else
      echo "Pages: (unknown — pdfinfo is not installed)"
    fi
    if command -v pdftotext > /dev/null 2>&1; then
      echo "pdftotext: available"
    else
      echo "pdftotext: not installed — read pages with the Read tool instead"
    fi
    ;;
  *)
    lines=$(wc -l < "$doc" | tr -d ' ')
    echo "Type: ${ext:-no extension} ($lines lines, $size bytes)"
    ;;
esac

# The review filename: lowercase the basename, spaces to dashes, drop the extension, append the
# suffix. A dotfile such as `.env` has no stem to drop, so it keeps its whole name.
stem="${base%.*}"
[ -n "$stem" ] || stem="$base"
review="$(printf '%s' "$stem" | tr '[:upper:]' '[:lower:]' | tr ' ' '-')-DOC-REVIEW.md"

if root=$(git rev-parse --show-toplevel 2> /dev/null); then
  in_git=yes
else
  root=$PWD
  in_git=no
fi

# Absolute, symlink-resolved path, so two spellings of one document compare equal.
abs() {
  (cd "$(dirname -- "$1")" 2> /dev/null && printf '%s/%s' "$(pwd -P)" "$(basename -- "$1")")
}
doc_abs=$(abs "$doc")

# Record the document relative to the root when it lives under it; the header row is read back on
# the next run, and a path that depends on the directory the session started in would not match.
case "$doc_abs" in
  "$root"/*) doc_display="${doc_abs#"$root"/}" ;;
  *) doc_display="$doc_abs" ;;
esac
echo "Document (as recorded): $doc_display"

# Basenames collide across directories. When the derived file already reviews a different document,
# prefix the parent directory rather than merging two documents into one record.
path="$root/$review"
if [ -f "$path" ]; then
  existing=$(grep -m1 -E '^\| \*\*Document\*\* \|' "$path" | awk -F'|' '{print $3}' | tr -d '` ')
  if [ -z "$existing" ]; then
    echo "Existing review: $review — could not read which document it reviews; open it before writing"
  else
    case "$existing" in
      /*) existing_abs=$(abs "$existing") ;;
      *) existing_abs=$(abs "$root/$existing") ;;
    esac
    if [ "$existing_abs" = "$doc_abs" ]; then
      echo "Existing review: $review — reviews this document; merge into it as a re-review"
    else
      parent=$(basename -- "$(dirname -- "$doc_abs")" | tr '[:upper:]' '[:lower:]' | tr ' ' '-')
      echo "Existing review: $review — reviews a different document ($existing); do not merge"
      review="$parent-$review"
    fi
  fi
fi
echo "Review file: $review"

if [ "$in_git" = yes ]; then
  # `git rev-parse --abbrev-ref HEAD` answers "HEAD" for a detached checkout, which reads as a
  # branch actually named HEAD. symbolic-ref names the state instead.
  if branch=$(git symbolic-ref --quiet --short HEAD 2> /dev/null); then
    echo "Branch: $branch"
  else
    echo "Branch: (detached HEAD)"
  fi
  echo "Commit: $(git rev-parse --short HEAD 2> /dev/null || echo '(no commits yet)')"
  # The commit pins what the reviewer read only if the document is in this repository at that commit.
  case "$doc_abs" in
    "$root"/*)
      if [ -n "$(git status --short -- "$doc" 2> /dev/null)" ]; then
        echo "Document status: uncommitted changes — the commit does not pin the text under review"
      else
        echo "Document status: clean at that commit"
      fi
      ;;
    *) echo "Document status: outside this repository — the commit does not pin it" ;;
  esac
else
  echo "Repository: not a git repository — the review file goes in the current directory"
fi
echo "Date: $(date +%F)"
