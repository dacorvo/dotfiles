#!/usr/bin/env bash
# Archive Claude Code session transcripts to a private HF bucket.
#
# Fired by the SessionEnd hook. Every transcript the sync would actually push is
# scanned individually by trufflehog in single-file mode (directory mode silently
# skips large files, so it must not be used as a gate). A file is excluded from
# the upload when trufflehog reports a verified secret, or an unverified one from
# a high-confidence detector (structured, prefixed credentials). Noisy detectors
# such as VirusTotal (any 64-char hex) only block when actually verified, so they
# don't permanently bar legitimate transcripts. Clean files sync to the bucket.

set -uo pipefail

# Detectors trusted enough to block on even when unverified — a revoked-but-still-
# present token (e.g. the leaked HuggingFace one) must never slip through. Match is
# case-insensitive. Add structured, low-false-positive credential types here.
HICONF_DETECTORS="huggingface,aws,github,githubapp,gitlab,slack,slackwebhook,anthropic,openai,stripe,gcp,azure,azurestorage,sendgrid,twilio,mailgun,pypi,privatekey,square,digitaloceantoken,cloudflareapitoken"

# Resolve a binary by name, falling back to common install locations — the hook
# may run with a minimal PATH (e.g. launched from the IDE), so PATH alone is not
# enough to find tools installed under Homebrew, uv, or ~/.local/bin.
find_bin() {
    command -v "$1" 2>/dev/null && return 0
    for d in "$HOME/.local/bin" /opt/homebrew/bin /usr/local/bin "$HOME/go/bin" /usr/bin /bin; do
        [ -x "$d/$1" ] && { printf '%s\n' "$d/$1"; return 0; }
    done
    return 1
}

HF="$(find_bin hf || true)"
TRUFFLEHOG="$(find_bin trufflehog || true)"
JQ="$(find_bin jq || true)"
PROJECTS="$HOME/.claude/projects"
LOG="$HOME/.claude/hooks/archive-session.log"

log() { printf '%s %s\n' "$(date +%Y-%m-%dT%H:%M:%S%z)" "$*" >>"$LOG"; }

# All prerequisites must be present. A missing trufflehog must never degrade into
# an unscanned upload, so bail out entirely rather than skip the secret gate.
for tool in "$HF" "$TRUFFLEHOG" "$JQ"; do
    if [ -z "$tool" ] || [ ! -x "$tool" ]; then
        log "ABORT: missing prerequisite (hf=$HF trufflehog=$TRUFFLEHOG jq=$JQ); skipping upload."
        exit 0
    fi
done

cat >/dev/null  # drain hook JSON on stdin (unused: we gate the whole upload set)

# Bucket namespace follows the authenticated HF account, so the hook is portable
# across hosts and users.
HF_USER="$("$HF" auth whoami 2>/dev/null | sed -n 's/^user=\([^ ]*\).*/\1/p')"
if [ -z "$HF_USER" ]; then
    log "ABORT: could not determine HF user (hf auth whoami); skipping upload."
    exit 0
fi
BUCKET="hf://buckets/$HF_USER/claude-sessions"

# Files the sync would actually push (new/changed). Scanning only these keeps the
# gate fast and covers exactly what is about to leave the machine.
candidates=()
while IFS= read -r rel; do
    [ -n "$rel" ] && candidates+=("$rel")
done < <("$HF" buckets sync "$PROJECTS" "$BUCKET" --include "*.jsonl" --dry-run 2>/dev/null \
    | "$JQ" -r 'select(.type == "operation" and .action == "upload") | .path')

if [ "${#candidates[@]}" -eq 0 ]; then
    log "nothing to upload; up to date."
    exit 0
fi

# Scan each candidate; flag it if trufflehog reports a verified secret or an
# unverified one from a high-confidence detector.
exclude_args=()
dirty=0
for rel in "${candidates[@]}"; do
    f="$PROJECTS/$rel"
    [ -f "$f" ] || continue
    hits="$("$TRUFFLEHOG" filesystem "$f" --json --no-update 2>/dev/null \
        | "$JQ" -r --arg hiconf "$HICONF_DETECTORS" '
            ($hiconf | ascii_downcase | split(",")) as $allow
            | select(type == "object" and .DetectorName != null)
            | (.DetectorName | ascii_downcase) as $d
            | select((.Verified == true) or ($allow | index($d) != null))
            | .DetectorName' \
        | wc -l | tr -d ' ')"
    if [ "${hits:-0}" -gt 0 ]; then
        dirty=$((dirty + 1))
        exclude_args+=(--exclude "$rel")
        log "EXCLUDE (${hits} blocking finding(s)): $rel"
    fi
done

log "candidates=${#candidates[@]} excluded=${dirty}"

# Sync everything except the flagged files (rsync-like: only changed files move).
if [ "${dirty}" -gt 0 ]; then
    "$HF" buckets sync "$PROJECTS" "$BUCKET" --include "*.jsonl" "${exclude_args[@]}" >>"$LOG" 2>&1
else
    "$HF" buckets sync "$PROJECTS" "$BUCKET" --include "*.jsonl" >>"$LOG" 2>&1
fi
if [ "$?" -eq 0 ]; then
    log "sync OK"
else
    log "sync FAILED"
fi
exit 0
