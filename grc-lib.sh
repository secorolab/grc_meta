# Helpers shared by the grc scripts. Both script-setup and script-sync must agree on
# how a repository is updated, or the same repo ends up in a different state depending
# on which one last touched it.
#
# Sourced, not executed.

# The workspace root, so every command works from anywhere inside the tree: the
# sourced environment first, then the nearest ancestor of the current directory that
# holds src/grc_meta, and finally the checkout the calling script lives in ($1, its
# own directory). Every candidate is canonicalised with realpath -e, so a relative or
# symlinked $GRC_WS (or cwd) resolves to the same physical path the rest of the script
# compares against, instead of a raw string that breaks after the next `cd`. Prints
# the path; returns 1 when there is no workspace to find.
find_workspace() {
    local dir resolved

    if [ -n "${GRC_WS:-}" ] \
       && resolved="$(realpath -e -- "$GRC_WS" 2>/dev/null)" \
       && [ -d "$resolved/src/grc_meta" ]; then
        printf '%s\n' "$resolved"
        return 0
    fi

    dir="$(pwd -P)"
    while [ "$dir" != / ] && [ -n "$dir" ]; do
        if [ -d "$dir/src/grc_meta" ]; then
            printf '%s\n' "$dir"
            return 0
        fi
        dir="$(dirname "$dir")"
    done

    # Run from outside any workspace (a cron job, another repo): fall back to the
    # tree this script is checked out in, which is <workspace>/src/grc_meta.
    if [ -n "${1:-}" ] \
       && resolved="$(realpath -e -- "$1/../.." 2>/dev/null)" \
       && [ -d "$resolved/src/grc_meta" ]; then
        printf '%s\n' "$resolved"
        return 0
    fi
    return 1
}

# find_workspace, but when every check above comes up empty and the shell is
# interactive, ask for the path instead of just failing -- the common case for a
# fresh shell is simply that GRC_WS was never sourced. A blank answer aborts; a
# non-interactive caller (cron, CI) falls straight through to its own error, since
# there is no one to prompt. $1 is the caller's SCRIPT_DIR, passed through to
# find_workspace for its own-checkout fallback.
require_workspace() {
    local script_dir="$1" ws answer

    if ws="$(find_workspace "$script_dir")"; then
        printf '%s\n' "$ws"
        return 0
    fi

    [ -t 0 ] || return 1
    printf 'GRC_WS is not set and no workspace was found from here.\n' >&2
    printf 'Enter the workspace path (containing src/grc_meta), or leave blank to abort: ' >&2
    read -r answer
    [ -n "$answer" ] || return 1
    ws="$(realpath -e -- "$answer" 2>/dev/null)" && [ -d "$ws/src/grc_meta" ] || {
        printf 'no src/grc_meta under %s\n' "$answer" >&2
        return 1
    }
    printf 'Using it for this run. To skip this prompt, add to your shell profile (or source setup-grc.zsh):\n  export GRC_WS=%s\n' "$ws" >&2
    printf '%s\n' "$ws"
}

# Tracked changes only: an untracked file survives a checkout or a fast-forward
# untouched, so it is no reason to hold up an update.
repo_dirty() { [ -n "$(git -C "$1" status --porcelain --untracked-files=no)" ]; }

# Bring one repo in line with the branch it tracks, without ever discarding local
# work: push when it is ahead, stash/fast-forward/pop when it is behind, and refuse
# to reconcile a branch that is both -- that needs a merge or a rebase, which is the
# owner's choice. Detached checkouts (a pinned tag) have no upstream and are left be.
#
# Sets REPO_UPDATE_MSG, and REPO_UPDATE_MOVED=1 when the checkout changed and its
# build is therefore stale -- that is separate from the return code, because a
# conflicting pop both moves the checkout and needs a human. Returns 0 when something
# was done, 1 when there was nothing to do, 2 when the repo needs a human.
update_repo_branch() {
    local repo="$1" upstream gone ahead stashed=0
    REPO_UPDATE_MSG=''
    REPO_UPDATE_MOVED=0

    upstream="$(git -C "$repo" rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null)" || {
        REPO_UPDATE_MSG='on a branch with no upstream; leaving it alone'
        return 1
    }
    gone="$(git -C "$repo" rev-list --count "HEAD..$upstream")"
    ahead="$(git -C "$repo" rev-list --count "$upstream..HEAD")"

    if [ "$gone" -gt 0 ] && [ "$ahead" -gt 0 ]; then
        REPO_UPDATE_MSG="diverged from $upstream ($ahead local, $gone upstream) -- merge or rebase it yourself"
        return 2
    fi

    if [ "$ahead" -gt 0 ]; then
        # Publishing commits leaves the checkout as it was, so nothing needs rebuilding.
        if git -C "$repo" push --quiet 2>/dev/null; then
            REPO_UPDATE_MSG="pushed $ahead commit(s) to $upstream"
            return 0
        fi
        REPO_UPDATE_MSG="push to $upstream was rejected"
        return 2
    fi

    if [ "$gone" -eq 0 ]; then
        REPO_UPDATE_MSG="up to date with $upstream"
        return 1
    fi

    if repo_dirty "$repo"; then
        git -C "$repo" stash push --quiet -m "grc: before updating to $upstream"
        stashed=1
    fi

    # --ff-only, never a merge commit.
    if ! git -C "$repo" merge --ff-only --quiet "$upstream" 2>/dev/null; then
        [ "$stashed" -eq 1 ] && git -C "$repo" stash pop --quiet
        REPO_UPDATE_MSG="could not fast-forward to $upstream"
        return 2
    fi

    REPO_UPDATE_MOVED=1

    if [ "$stashed" -eq 1 ] && ! git -C "$repo" stash pop --quiet >/dev/null 2>&1; then
        # A conflicting pop keeps the stash entry but leaves conflict markers in the
        # tree, which a build would then compile. Reset to the clean updated checkout
        # and leave the work in the stash for its owner to apply.
        git -C "$repo" reset --hard --quiet
        REPO_UPDATE_MSG="fast-forwarded to $upstream, but your changes conflict with it -- git -C $repo stash pop"
        return 2
    fi

    REPO_UPDATE_MSG="fast-forwarded to $upstream"
    [ "$stashed" -eq 1 ] && REPO_UPDATE_MSG="$REPO_UPDATE_MSG, local changes restored"
    return 0
}
