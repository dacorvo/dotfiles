#!/usr/bin/env bash
# Index new Claude Code turns into funes — local only, no network.
#
# Fired by the Stop hook (after every turn), so the local index stays fresh as you
# work. `funes index` is incremental and idempotent — it re-embeds nothing already
# stored — and indexing per turn yields the same chunks as indexing once per session,
# since chunk ids derive from (session, turn, block, split). Publishing to the remote
# is a separate step (funes-push.sh, on session boundaries), so this per-turn run
# stays cheap and never touches the network.
#
# The work runs detached so it never blocks the turn or trips the hook timeout: the
# foreground half drains the hook payload, re-execs as a background worker, and
# returns. Detach and locking use only portable idioms (nohup + a mkdir lock) — stock
# macOS ships neither setsid nor flock, and this runs on macOS and Linux.

set -uo pipefail

LOG="$HOME/.claude/hooks/funes-sync.log"
LOCK="$HOME/.claude/hooks/.funes-index.lock"   # serialize concurrent index runs
STALE_LOCK_SECS=1800                           # take over a lock a hard-killed run left behind

log() { printf '%s %s\n' "$(date +%Y-%m-%dT%H:%M:%S%z)" "$*" >>"$LOG"; }

# Resolve a binary by name, falling back to common install dirs — hooks can run with a
# minimal PATH (e.g. launched from the IDE).
find_bin() {
    command -v "$1" 2>/dev/null && return 0
    for d in "$HOME/.local/bin" /opt/homebrew/bin /usr/local/bin "$HOME/go/bin" /usr/bin /bin; do
        [ -x "$d/$1" ] && { printf '%s\n' "$d/$1"; return 0; }
    done
    return 1
}

# mtime in epoch seconds — GNU `stat -c` first, BSD `stat -f` second.
lock_mtime() { stat -c %Y "$1" 2>/dev/null || stat -f %m "$1" 2>/dev/null || echo 0; }

worker() {
    local funes holder mtime now stolen
    funes="$(find_bin funes || true)"
    if [ -z "$funes" ] || [ ! -x "$funes" ]; then
        log "index ABORT: funes not found; skipping."
        return
    fi

    # Serialize concurrent turns/sessions. mkdir is atomic; steal an existing lock only
    # when its holder is truly gone (PID liveness, not wall-clock age — a long or
    # laptop-slept run must not have its lock stolen while it is still working).
    if ! mkdir "$LOCK" 2>/dev/null; then
        holder="$(cat "$LOCK/pid" 2>/dev/null || true)"
        if [ -n "$holder" ] && kill -0 "$holder" 2>/dev/null; then
            log "index: another run (pid $holder) in progress; skipping."
            return
        fi
        if [ -z "$holder" ]; then
            mtime="$(lock_mtime "$LOCK")"; now="$(date +%s)"
            if [ "$mtime" -gt 0 ] && [ "$((now - mtime))" -le "$STALE_LOCK_SECS" ]; then
                log "index: lock being acquired by another worker; skipping."
                return
            fi
        fi
        stolen="$LOCK.stale.$$"
        if mv "$LOCK" "$stolen" 2>/dev/null; then
            rm -rf "$stolen" 2>/dev/null
            log "index: reclaimed abandoned lock (holder=${holder:-unknown})"
        fi
        mkdir "$LOCK" 2>/dev/null || { log "index: another worker grabbed the lock; skipping."; return; }
    fi
    printf '%s\n' "$$" >"$LOCK/pid" 2>/dev/null || true
    trap 'rm -rf "$LOCK" 2>/dev/null' EXIT

    # Name the target explicitly: an automated (no-TTY) `funes index` refuses to run with
    # no target, so this indexes only Claude sessions — other agents get their own hook.
    log "index: start"
    if "$funes" index --harness claude >>"$LOG" 2>&1; then
        log "index: ok"
    else
        log "index: FAILED (exit $?)"
    fi
}

# Worker mode (re-exec): do the real work, already detached from the turn.
if [ "${1:-}" = "--worker" ]; then
    worker
    exit 0
fi

# Foreground: drain the Stop payload on stdin, hand off to a detached worker, return.
cat >/dev/null
nohup bash "$0" --worker >/dev/null 2>&1 </dev/null &
disown 2>/dev/null || true
exit 0
