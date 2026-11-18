#!/usr/bin/env bash
#
# update.sh -- updates pkt-idle-shell from its own repository.
#
# Only fast-forwards. If you have uncommitted changes it stops, so nothing of
# yours is overwritten.
set -Eeuo pipefail

REPO="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
cd "$REPO"

if ! git diff --quiet || ! git diff --cached --quiet; then
    echo "Uncommitted changes found. Commit or stash them, then run update.sh again." >&2
    git status --short >&2
    exit 1
fi

branch="$(git rev-parse --abbrev-ref HEAD)"
git fetch --quiet origin "$branch"

before="$(git rev-parse HEAD)"
remote="$(git rev-parse "origin/$branch")"

if [ "$before" = "$remote" ]; then
    echo "pkt-idle-shell is already up to date."
    exit 0
fi

git merge --ff-only --quiet "origin/$branch"
echo "Updated: $(git rev-parse --short "$before") -> $(git rev-parse --short HEAD)"

args=(--no-data)
if git diff --quiet "$before" HEAD -- packages/; then
    args+=(--no-packages)
fi

exec "$REPO/install.sh" "${args[@]}"
