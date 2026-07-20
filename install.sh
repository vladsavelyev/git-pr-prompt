#!/usr/bin/env bash
# Idempotent installer for the git PR-context prompt integration.
#
#   ./install.sh          # install / update everything
#   ./install.sh --check  # report what would change, make no edits
#
# What it does:
#   1. symlink bin/git-pr-context -> ~/.local/bin/git-pr-context
#   2. wire the p10k segment into ~/.p10k.zsh (source snippet + add `prcontext`)
#   3. set the Claude statusline command in ~/.claude/settings.json (via jq,
#      leaving all other keys — including secrets — untouched)
#
# Re-running is safe: each step detects whether it's already applied.

set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHECK=0
[ "${1:-}" = "--check" ] && CHECK=1

P10K="$HOME/.p10k.zsh"
SETTINGS="$HOME/.claude/settings.json"
BIN_SRC="$REPO/bin/git-pr-context"
BIN_DST="$HOME/.local/bin/git-pr-context"
SNIPPET="$REPO/snippets/p10k-prcontext.zsh"
STATUSLINE_CMD_FILE="$REPO/snippets/statusline.command"

info() { printf '  %s\n' "$*"; }
step() { printf '\n== %s\n' "$*"; }

# --- 1. helper on PATH ------------------------------------------------------
step "bin/git-pr-context -> $BIN_DST"
if [ -L "$BIN_DST" ] && [ "$(readlink "$BIN_DST")" = "$BIN_SRC" ]; then
  info "already symlinked"
elif [ "$CHECK" = 1 ]; then
  info "WOULD symlink (currently: $( [ -e "$BIN_DST" ] && echo exists || echo missing ))"
else
  mkdir -p "$(dirname "$BIN_DST")"
  ln -sfn "$BIN_SRC" "$BIN_DST"
  info "symlinked"
fi

case ":$PATH:" in
  *":$HOME/.local/bin:"*) ;;
  *) info "NOTE: ~/.local/bin is not on your PATH — add it in ~/.zshrc" ;;
esac

# --- 2. p10k segment --------------------------------------------------------
step "p10k segment in $P10K"
if [ ! -f "$P10K" ]; then
  info "SKIP: $P10K not found (is Powerlevel10k installed?)"
else
  SOURCE_LINE="source \"$SNIPPET\""
  if grep -qF "$SNIPPET" "$P10K"; then
    info "snippet already sourced"
  elif [ "$CHECK" = 1 ]; then
    info "WOULD append: $SOURCE_LINE"
  else
    printf '\n# git PR-context prompt segment (managed by dotfiles/install.sh)\n%s\n' \
      "$SOURCE_LINE" >> "$P10K"
    info "appended source line"
  fi

  if grep -qE '^\s*prcontext\s*(#|$)' "$P10K"; then
    info "prcontext already in POWERLEVEL9K_LEFT_PROMPT_ELEMENTS"
  elif [ "$CHECK" = 1 ]; then
    info "WOULD insert 'prcontext' after 'vcs' in LEFT_PROMPT_ELEMENTS"
  else
    # Insert `prcontext` on the line after the `vcs` element (first match only).
    perl -0pi -e 's/^(\s*)vcs(\s+#[^\n]*)?\n/$&$1prcontext              # git-town base + open PR (custom)\n/m unless $done; $done=1 if /prcontext/' "$P10K"
    if grep -qE '^\s*prcontext\b' "$P10K"; then
      info "inserted 'prcontext' after 'vcs'"
    else
      info "WARN: could not auto-insert 'prcontext' — add it to POWERLEVEL9K_LEFT_PROMPT_ELEMENTS by hand"
    fi
  fi
fi

# --- 3. Claude statusline ---------------------------------------------------
step "Claude statusline in $SETTINGS"
if ! command -v jq >/dev/null 2>&1; then
  info "SKIP: jq not installed"
elif [ ! -f "$SETTINGS" ]; then
  info "SKIP: $SETTINGS not found"
else
  DESIRED="$(cat "$STATUSLINE_CMD_FILE")"
  CURRENT="$(jq -r '.statusLine.command // ""' "$SETTINGS")"
  if [ "$CURRENT" = "$DESIRED" ]; then
    info "statusline already up to date"
  elif [ "$CHECK" = 1 ]; then
    info "WOULD set .statusLine.command (differs from current)"
  else
    tmp="$(mktemp)"
    jq --arg cmd "$DESIRED" '.statusLine = {type: "command", command: $cmd}' \
      "$SETTINGS" > "$tmp"
    mv "$tmp" "$SETTINGS"
    info "set .statusLine.command"
  fi
fi

step "done"
info "restart your shell (exec zsh) to load the prompt segment"
