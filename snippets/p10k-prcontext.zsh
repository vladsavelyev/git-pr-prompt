# Powerlevel10k custom segment: PR base branch + open PR number.
#
# Source this from ~/.p10k.zsh (inside the `() { ... }` config block is fine,
# or at file scope), then add `prcontext` to POWERLEVEL9K_LEFT_PROMPT_ELEMENTS
# (a good spot is right after `vcs`).
#
# Base is the PR's real baseRefName (falls back to git-town's recorded parent
# when there's no PR); hidden when it is `main` or unknown. Backed by the
# `git-pr-context` helper on PATH (cached, non-blocking).

function prompt_prcontext() {
  local out=$(git-pr-context "$PWD" 2>/dev/null)
  [[ -z $out ]] && return
  local base=${out%%$'\t'*}
  local rest=${out#*$'\t'}
  local pr=${rest%%$'\t'*}
  local text=""
  [[ -n $base ]] && text="→ ${base}"
  [[ -n $pr ]] && text="${text:+$text }#${pr}"
  [[ -z $text ]] && return
  p10k segment -f 141 -t "$text"
}

# Instant-prompt variant: same calls, so p10k can replay it.
function instant_prompt_prcontext() {
  prompt_prcontext
}
