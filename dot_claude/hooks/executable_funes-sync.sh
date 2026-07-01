#!/usr/bin/env bash
# Index new Claude Code turns into funes and publish them to the active remote.
#
# Fired by the SessionEnd hook. The heavy work — embedding new turns, then a
# network push — runs detached so it never blocks session teardown or trips the
# hook timeout: the foreground half just drains the hook payload, re-execs itself
# as a background worker, and returns. Detach and locking use only portable
# idioms (nohup + a mkdir lock), because stock macOS ships neither setsid nor
# flock, and this hook runs on both macOS and Linux.
#
# `funes index` writes only locally and is incremental (it re-embeds nothing that
# hasn't changed), so re-running it every session is cheap. `funes push` uploads
# the new chunks to the active remote; it has its own fail-closed secret gate, so
# a session containing a credential is held back rather than published — this hook
# does not need to re-scan, unlike the raw-transcript archive hook.

set -uo pipefail

LOG="$HOME/.claude/hooks/funes-sync.log"
LOCK="$HOME/.claude/hooks/.funes-sync.lock"   # mkdir lock: atomic + portable (no flock on macOS)
FUNES_HOME="${FUNES_HOME:-$HOME/.funes}"
FUNES_JSON="$FUNES_HOME/funes.json"
STALE_LOCK_SECS=1800                          # take over a lock a hard-killed run left behind

log() { printf '%s %s\n' "$(date +%Y-%m-%dT%H:%M:%S%z)" "$*" >>"$LOG"; }

# Resolve a binary by name, falling back to common install locations — the hook
# may run with a minimal PATH (e.g. launched from the IDE), so PATH alone is not
# enough to find tools installed under ~/.local/bin, Homebrew, or uv.
find_bin() {
    command -v "$1" 2>/dev/null && return 0
    for d in "$HOME/.local/bin" /opt/homebrew/bin /usr/local/bin "$HOME/go/bin" /usr/bin /bin; do
        [ -x "$d/$1" ] && { printf '%s\n' "$d/$1"; return 0; }
    done
    return 1
}

# mtime of $1 in epoch seconds. GNU `stat -c` first (on macOS BSD stat this fails
# cleanly to stderr and falls through); BSD `stat -f` second. The reverse order is
# unsafe: GNU `stat -f %m` prints filesystem info to stdout *and* exits non-zero,
# so it would leak garbage into the result before the fallback runs.
lock_mtime() { stat -c %Y "$1" 2>/dev/null || stat -f %m "$1" 2>/dev/null || echo 0; }

worker() {
    local funes rc holder mtime now stolen
    funes="$(find_bin funes || true)"
    if [ -z "$funes" ] || [ ! -x "$funes" ]; then
        log "ABORT: funes binary not found on PATH or common locations; skipping."
        return
    fi

    # Serialize concurrent session-ends: mkdir is atomic, so exactly one racer wins.
    # If the lock exists, steal it only when the holder is truly gone — decided by PID
    # liveness, NOT wall-clock age: a legitimately long run (a cold first index, or a
    # laptop that slept mid-run) must not have its lock stolen out from under it while
    # it is still alive, or two `funes index` runs would write the store at once. Age
    # is only the fallback when no PID was recorded (a worker that died between mkdir
    # and writing its pid).
    if ! mkdir "$LOCK" 2>/dev/null; then
        holder="$(cat "$LOCK/pid" 2>/dev/null || true)"
        if [ -n "$holder" ] && kill -0 "$holder" 2>/dev/null; then
            log "another sync (pid $holder) in progress; skipping."
            return
        fi
        if [ -z "$holder" ]; then
            mtime="$(lock_mtime "$LOCK")"
            now="$(date +%s)"
            if [ "$mtime" -gt 0 ] && [ "$((now - mtime))" -le "$STALE_LOCK_SECS" ]; then
                log "lock being acquired by another worker; skipping."
                return
            fi
        fi
        # Holder is dead (or pidless and old). Claim the removal atomically via rename
        # so two reclaimers can't both delete and recreate the lock and end up both
        # holding it; then take it. Whoever loses the final mkdir simply skips.
        stolen="$LOCK.stale.$$"
        if mv "$LOCK" "$stolen" 2>/dev/null; then
            rm -rf "$stolen" 2>/dev/null
            log "reclaimed abandoned lock (holder=${holder:-unknown})"
        fi
        mkdir "$LOCK" 2>/dev/null || { log "another sync grabbed the lock; skipping."; return; }
    fi
    printf '%s\n' "$$" >"$LOCK/pid" 2>/dev/null || true
    trap 'rm -rf "$LOCK" 2>/dev/null' EXIT

    log "index: start"
    if "$funes" index >>"$LOG" 2>&1; then
        log "index: ok"
    else
        log "index: FAILED (exit $?)"
        return
    fi

    # Push only when a remote is attached — otherwise `funes push` errors on "no
    # active remote", which is expected on a local-only host, not a failure.
    # if [ -f "$FUNES_JSON" ] && grep -q '"remote"' "$FUNES_JSON"; then
    #     log "push: start"
    #     "$funes" push >>"$LOG" 2>&1
    #     rc=$?
    #     case "$rc" in
    #         0) log "push: ok" ;;
    #         2) log "push: WARN — secrets held back; run 'funes scrub', then it publishes next run" ;;
    #         *) log "push: FAILED (exit $rc)" ;;
    #     esac
    # else
    #     log "push: skipped (no remote attached — 'funes use <org>/<repo>' to enable)"
    # fi
}

# Worker mode (re-exec): do the real work, already detached from the session.
if [ "${1:-}" = "--worker" ]; then
    worker
    exit 0
fi

# Foreground: drain the SessionEnd JSON on stdin (we index the whole tree, not one
# file), then hand off to a detached worker and return at once.
cat >/dev/null
nohup bash "$0" --worker >/dev/null 2>&1 </dev/null &
disown 2>/dev/null || true
exit 0
