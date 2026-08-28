#!/bin/bash
#
# Prints the repository context /local-review needs to resolve a change set: the current branch, the
# detected base branch, and what differs from it.
#
# The base branch is the first of the remote HEAD's target, main, master, develop, or trunk that
# resolves to a ref this clone actually has — preferring the remote-tracking ref, so `origin/main`
# is a valid answer. Nothing here assumes `main`, and nothing assumes the remote is called `origin`.

# No -e: this script reports context and must always produce output, even in a degraded repository —
# a failed git call should print a gap, not abort the run. No pipefail either: every pipeline below
# feeds head or tail, which close the pipe and return 141 on any repo big enough to truncate, so it
# would only ever report a success as a failure.
set -u

if ! git rev-parse --git-dir > /dev/null 2>&1; then
  echo "Not a git repository."
  exit 0
fi

# `git rev-parse --abbrev-ref HEAD` answers "HEAD" for a detached checkout, which reads as a branch
# actually named HEAD. CI checkouts and `gh pr checkout` of a fork both land detached, so name the
# state instead. symbolic-ref still reports the branch name on an unborn HEAD, which is the useful
# answer there.
if branch=$(git symbolic-ref --quiet --short HEAD 2>/dev/null); then
  branch_display="$branch"
elif commit=$(git rev-parse --short HEAD 2>/dev/null); then
  branch="" ; branch_display="(detached HEAD at $commit)"
else
  branch="" ; branch_display="(HEAD could not be read)"
fi

# Prefer a remote named origin, else the first one configured. A clone made with `--origin
# upstream`, or a fork whose only remote is `github`, has a base to resolve against just as much as
# a conventional one does.
if git remote | grep -qx origin; then
  remote=origin
else
  remote=$(git remote | head -1)
fi

# Resolve a branch name to a ref that actually exists in this clone, preferring the remote-tracking
# ref over the local branch.
#
# Order matters in both directions. A single-branch clone, or `gh pr checkout` of a fork, has
# origin/main but no local main, so a bare name yields an empty diff that reads as an unchanged
# branch. And a local branch only advances on an explicit pull, while origin/<name> moves on any
# fetch — so preferring the local one makes a `main` left behind for a week drag every upstream
# commit merged since into this branch's diff, handing reviewers work nobody here wrote.
# origin/<name> is never staler than the local branch, because the pull that advances one advances
# the other.
resolve_base() {
  if [ -n "$remote" ] && git show-ref --verify --quiet "refs/remotes/$remote/$1"; then
    printf '%s/%s' "$remote" "$1"
  elif git show-ref --verify --quiet "refs/heads/$1"; then
    printf '%s' "$1"
  else
    return 1
  fi
}

default=""
if [ -n "$remote" ]; then
  default=$(git symbolic-ref --quiet --short "refs/remotes/$remote/HEAD" 2>/dev/null \
    | sed "s|^$remote/||")
fi

base=""
for candidate in "$default" main master develop trunk; do
  # A candidate name reaches here from the remote's HEAD, and git parses a ref starting with `-` as
  # an option rather than a revision. `git branch` refuses to create one, but `git update-ref
  # refs/heads/-evil` succeeds and passes the show-ref gate below, so reject the shape here as well
  # as terminating option parsing at each call site.
  case "$candidate" in -*) continue ;; esac
  [ -n "$candidate" ] || continue
  if base=$(resolve_base "$candidate"); then
    break
  fi
  base=""
done

# Being on the base branch and having no base at all print the same thing if you let them, and the
# skill has to tell them apart: one means "review the uncommitted work", the other means "stop and
# ask".
on_base=""
if [ -n "$base" ] && { [ "$base" = "$branch" ] || [ "$base" = "$remote/$branch" ]; }; then
  on_base=yes
fi

echo "Current branch: $branch_display"

if [ -n "$base" ] && [ -z "$on_base" ]; then
  echo "Base branch: $base"
  merge_base=$(git merge-base --end-of-options "$base" HEAD 2>/dev/null)
  echo "Merge base: ${merge_base:-(could not compute — unrelated histories?)}"
  echo ""
  # Truncation has to announce itself. The diffstat is tail-ed to keep its summary line, so a large
  # change drops the *earliest* files — and the model has no way to know the list it is reading is
  # partial.
  commits=$(git rev-list --count --end-of-options "$base..HEAD" 2>/dev/null || echo 0)
  if [ "$commits" -gt 20 ]; then
    echo "Commits on this branch (showing first 20 of $commits):"
  else
    echo "Commits on this branch:"
  fi
  git log --oneline --end-of-options "$base..HEAD" 2>/dev/null | head -20
  echo ""
  files=$(git diff --name-only --end-of-options "$base...HEAD" 2>/dev/null | wc -l | tr -d ' ')
  if [ "$files" -gt 39 ]; then
    echo "Changed files vs $base (showing last 39 of $files):"
  else
    echo "Changed files vs $base:"
  fi
  git diff --stat --end-of-options "$base...HEAD" 2>/dev/null | tail -40
else
  if [ -n "$on_base" ]; then
    echo "Base branch: (none needed — this is the base branch '$branch')"
  elif [ -n "$default" ]; then
    # The remote names a default branch but this clone has no ref for it, which a single-branch or
    # shallow clone does routinely. Diffing against nothing here would report a branch full of
    # commits as clean.
    echo "Base branch: (unresolved — $remote/HEAD names '$default', but no ref for it exists"
    echo "              in this clone. A single-branch or shallow clone does this; fix with:"
    echo "              git fetch $remote $default)"
  else
    echo "Base branch: (none detected — no conventional base exists in this clone)"
  fi
  echo ""
  echo "Recent commits (no base to compare against):"
  git log --oneline -10 2>/dev/null
fi

echo ""
dirty=$(git status --short 2>/dev/null | wc -l | tr -d ' ')
if [ "$dirty" -gt 40 ]; then
  echo "Uncommitted changes (showing first 40 of $dirty):"
else
  echo "Uncommitted changes:"
fi
git status --short 2>/dev/null | head -40
