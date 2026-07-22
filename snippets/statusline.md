# Claude Code statusline — PR base + clickable PR number

Claude Code's statusline is a shell command stored in `~/.claude/settings.json`
under `.statusLine.command`. It's echoed as-is to the status bar, so it can
emit real OSC8 hyperlinks (unlike the p10k prompt, which must stay plain text
so segment widths measure correctly).

## The fragment this repo adds

The only PR-context-specific part is this block, inserted right after the
existing `git_branch` rendering and before the `model` rendering:

```sh
prctx=$(git-pr-context "$cwd" 2>/dev/null);
pr_parent=$(printf '%s' "$prctx" | cut -f1);
pr_num=$(printf '%s' "$prctx" | cut -f2);
pr_url=$(printf '%s' "$prctx" | cut -f3);
if [ -n "$pr_parent" ]; then
  out="$out $(printf '\033[38;5;244m')→ $pr_parent$(printf '\033[0m')";
fi;
if [ -n "$pr_num" ]; then
  if [ -n "$pr_url" ]; then
    pr_link=$(printf '\033]8;;%s\033\\#%s\033]8;;\033\\' "$pr_url" "$pr_num");
  else
    pr_link="#$pr_num";
  fi;
  out="$out $(printf '\033[38;5;39m')$pr_link$(printf '\033[0m')";
fi;
```

It expects two variables to already exist in the surrounding command: `$cwd`
(the working dir, from `.workspace.current_dir`) and `$out` (the accumulating
status string).

## Full reference command

The complete statusline command used with this setup lives in
[`statusline.command`](./statusline.command) — dir + branch + PR base + clickable
PR number + model + a token-usage bar + two cost figures:

- `$X.XX` (gold) — Claude Code's own `.cost.total_cost_usd`. This is the
  **main agent only**: subagent (Task-tool) turns are written to separate
  `<session>/subagents/agent-*.jsonl` transcripts and are **not** folded into
  this number, so it undercounts whenever subagents are running.
- `Σ$X.XX` (orange) — the **all-in** session cost from
  [`claude-spend --session "$transcript_path"`](../bin/claude-spend), which
  sums the main transcript plus every subagent transcript. This is the figure
  that reflects what the session actually spent. The two are shown side by side
  so you can see the subagent delta at a glance.

`install.sh` sets exactly this string as
`.statusLine.command` in `~/.claude/settings.json` (via `jq`, leaving every
other key — including secrets — untouched). If you already have a customized
statusline, splice in just the fragment above instead of overwriting.
