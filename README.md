# dotfiles — git PR-context prompt

Show the **base branch of the current branch's PR** and its **PR number** in
both the zsh prompt (Powerlevel10k) and the Claude Code statusline.

```
~/git/navari    repl-live-kernel  → repl-sandbox  #1950
                └ current branch  └ PR base       └ clickable PR (in Claude statusline)
```

- **Base branch**: the PR's real `baseRefName` from GitHub (survives PR
  retargeting). Falls back to git-town's recorded parent
  (`git-town-branch.<branch>.parent`) when there's no PR. Hidden when it's
  `main` or the branch is untracked — so it only appears when it's interesting
  (a stacked branch / non-main base).
- **PR number**: only for **open** PRs. In the Claude statusline it's a
  clickable OSC8 hyperlink to the PR; in the p10k prompt it's plain text
  (embedding link escapes there would break p10k's width alignment).

## How it works

Everything is driven by one helper, [`bin/git-pr-context`](./bin/git-pr-context):

```
git-pr-context <repo-dir>   ->   <base>\t<pr_number>\t<pr_url>
```

- git-town parent is a local `git config` read — instant and free.
- The PR lookup shells out to `gh` (~0.6s), so the helper **never blocks**: it
  prints whatever is cached and, when the 5-minute cache is stale, kicks off a
  detached, lock-guarded background refresh. Consequence: on a brand-new branch
  the PR info shows up one prompt render late — the right trade for a prompt.

The two prompts are thin display layers over this helper:
- [`snippets/p10k-prcontext.zsh`](./snippets/p10k-prcontext.zsh) — the p10k segment.
- [`snippets/statusline.md`](./snippets/statusline.md) — the Claude statusline
  fragment, plus the full reference command in `snippets/statusline.command`.

## Requirements

- [`gh`](https://cli.github.com/) — authenticated for the repos you work in.
- `git`, and optionally [git-town](https://www.git-town.com/) (used only as the
  fallback base source when a branch has no PR).
- [Powerlevel10k](https://github.com/romkatv/powerlevel10k) for the shell prompt.
- `jq` for the installer's statusline step.
- `~/.local/bin` on your `PATH`.

## Install

```sh
git clone <this-repo> ~/dotfiles
cd ~/dotfiles
./install.sh --check   # dry run: show what would change
./install.sh           # apply
exec zsh               # reload the prompt
```

The installer is idempotent and secret-safe:
1. symlinks `bin/git-pr-context` into `~/.local/bin/`;
2. sources the p10k snippet from `~/.p10k.zsh` and adds `prcontext` to the
   prompt element list (after `vcs`);
3. sets `.statusLine.command` in `~/.claude/settings.json` via `jq`, leaving
   every other key (including API keys) untouched.

If you already customized your statusline, splice in just the fragment from
`snippets/statusline.md` rather than letting the installer overwrite it.

## `claude-spend` — token & money spending

[`bin/claude-spend`](./bin/claude-spend) reports what you've spent in Claude
Code over a period, split by model. It reads the local transcripts under
`~/.claude/projects/**/*.jsonl` — no network, no API key.

```sh
claude-spend                 # this month (default)
claude-spend today
claude-spend last-day        # yesterday
claude-spend this-week last-week this-month last-month lifetime
claude-spend --all           # one summary row per period
claude-spend --json today    # machine-readable
claude-spend open            # build an HTML dashboard and open it in your browser
claude-spend --session <transcript.jsonl>   # one session's all-in cost (see below)
```

`--session <transcript>` reports a single session's **all-in** cost — the main
transcript *plus* every subagent transcript under its `<session>/subagents/`
dir — and prints a bare `$X.XX` (or `--json`). It derives everything from the
given transcript path, so it doesn't walk the whole projects tree. Two extra
flags support the statusline: `--subagents-only` sums just the subagent
transcripts, and `--add <USD>` adds a base amount before printing. The
statusline combines them — `claude-spend --session "$transcript" --subagents-only
--add "$cost"` — feeding Claude's live `.cost.total_cost_usd` as the base and
adding only the subagent cost from disk. That shows `Σ$X.XX` next to the
built-in `$X.XX` with no one-turn disk-flush lag (the built-in figure already
has the just-finished main turn; subagents are flushed by the time they
return). See [`snippets/statusline.md`](./snippets/statusline.md).

`claude-spend open` writes a self-contained HTML dashboard (KPI tiles, a
cost-by-period bar chart, a 30-day daily-cost trend, and the by-model table) to
a temp file and opens it — light/dark aware, no dependencies, no network.

```
Claude spend — this-month
  model                       cost        in       out   cache rd   cache wr   hit%    msgs  convos
  claude-opus-4-8          $612.30    3.06M    11.79M      2.62B    100.26M    96%   15824     176
  claude-sonnet-5           $25.61   105.4k    737.2k     27.42M      1.60M    94%     419      20
  TOTAL                    $637.91    3.16M    12.55M      2.67B    103.21M    96%   16870     195
```

Two things worth knowing about how the numbers are produced:

- **Cost is computed, not recorded.** The transcripts store token counts but not
  dollars, so `claude-spend` multiplies tokens by per-model pricing baked into
  the script (`PRICING` at the top — edit it when prices change). Cache reads
  bill at 0.1×, 5-min cache writes at 1.25×, 1-hour writes at 2× the input rate.
  A model with no price entry is billed as `$0` and flagged. Time-bounded
  promotional rates (`INTRO_PRICING`) are applied by the usage's own date — e.g.
  Sonnet 5's $2/$10 introductory rate through 2026-08-31, reverting to the
  $3/$15 sticker after — so historical periods stay priced correctly.
- **Everything is deduplicated by message id, keeping the largest row.**
  Resuming or forking a session copies its messages into a new transcript file,
  so the same API response shows up in several files. Counting them all would
  roughly double every number, so each message id is tallied once. A streamed
  turn also writes its message id several times *within* one file — partial-usage
  rows during generation (tiny `output_tokens`) then the final complete row — so
  dedup keeps the row with the most `output_tokens` (the final one), not the
  first seen; keeping the first would undercount every streamed turn.

`convos` = distinct sessions, `msgs` = assistant turns, `hit%` = cache-read
tokens as a share of all input tokens. The installer symlinks it into
`~/.local/bin/` alongside `git-pr-context`.

## Troubleshooting

- **Base/PR not showing** — the cache refreshes in the background; give it one
  more prompt render, or force it: `rm -rf "$TMPDIR/git-pr-context"`.
- **Nothing at all** — check `git-pr-context "$PWD"` prints something, and that
  `gh auth status` is logged in for that repo's host.
