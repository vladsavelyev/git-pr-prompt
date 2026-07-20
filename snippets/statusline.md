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
PR number + model + a token-usage bar. `install.sh` sets exactly this string as
`.statusLine.command` in `~/.claude/settings.json` (via `jq`, leaving every
other key — including secrets — untouched). If you already have a customized
statusline, splice in just the fragment above instead of overwriting.
