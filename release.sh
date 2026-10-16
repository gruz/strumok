#!/usr/bin/env bash
# release.sh — bump VERSION, commit, tag, push and create a GitHub release.
set -euo pipefail

REPO="gruz/strumok"

usage() {
    cat <<EOF
Usage: ./release.sh [--dry-run] <version>

Example:
    ./release.sh 0.1.9

Bumps VERSION in stream-window, commits, tags v<version>, pushes,
and creates a GitHub release with the stream-window asset attached.
Requires: git, gh, and a clean working tree.
EOF
}

DRY_RUN=0
[ "${1:-}" = "--dry-run" ] && { DRY_RUN=1; shift; }

NEW="${1:-}"
if [ -z "$NEW" ]; then
    usage >&2
    exit 1
fi
# strip a leading 'v' if the user typed it
NEW=${NEW#v}
TAG="v$NEW"

if [ ! -f stream-window ]; then
    echo "error: must be run from the repo root" >&2
    exit 1
fi

if [ -n "$(git status --porcelain)" ]; then
    echo "error: working tree is not clean — commit or stash changes first" >&2
    git status --short
    exit 1
fi

CURRENT=$(sed -n 's/^VERSION="\(.*\)"$/\1/p' stream-window | head -1)
echo "Current VERSION: ${CURRENT:-?}"
echo "New VERSION:     $NEW"

if [ "$NEW" = "$CURRENT" ]; then
    echo "error: new version is the same as the current version" >&2
    exit 1
fi

if ! git tag -l "$TAG" | grep -qxF "$TAG"; then
    : # tag does not exist yet, good
else
    echo "error: tag $TAG already exists" >&2
    exit 1
fi

run() {
    if [ "$DRY_RUN" = 1 ]; then
        echo "[dry-run] $*"
    else
        echo "+ $*"
        "$@"
    fi
}

# update VERSION
sed -i "s/^VERSION=\".*\"$/VERSION=\"$NEW\"/" stream-window

# verify
CHECK=$(sed -n 's/^VERSION="\(.*\)"$/\1/p' stream-window | head -1)
[ "$CHECK" = "$NEW" ] || { echo "error: VERSION update failed" >&2; exit 1; }

run git add stream-window
run git commit -m "bump VERSION to $NEW"
run git push origin master
run git tag -a "$TAG" -m "stream-window $TAG"
run git push origin "$TAG"
run gh release create "$TAG" --title "stream-window $TAG" --generate-notes stream-window

if [ "$DRY_RUN" = 1 ]; then
    echo "[dry-run] done"
else
    echo "Release $TAG is live:"
    echo "  https://github.com/$REPO/releases/tag/$TAG"
    echo "  https://github.com/$REPO/releases/latest/download/stream-window"
fi
