# Local OMP development guide

TLDR: Use `omp` for normal coding. It keeps the seven useful code tools plus
checkpoint and rewind, leaving about 14.5K tokens for the task before automatic
compaction. Use `omp-web` or `omp-full` only when the extra tools are needed.

## Start here

```bash
cd ~/github/ORG/REPO
omlxctl profile daily
omp
```

Open a new OMP session after changing the oMLX profile. A running session keeps
the old context limit.

## Which command to use

| Command | Use it for | Fixed input on OMP 18.1.10 |
| --- | --- | ---: |
| `omp` | Normal coding with read, shell, edit, write, grep, glob, LSP, checkpoint and rewind | 10,531 tokens |
| `omp-web` | Browser, web search, task agents and uncommon tools | 18,610 tokens |
| `omp-full` | Same unrestricted mode, kept as an explicit escape hatch | 18,610 tokens |

The daily profile compacts at 25K. The normal `omp` command therefore leaves
about 14.5K tokens for code and conversation. Full mode leaves about 6.4K.
Docker still works in normal mode through the shell tool.

The base prompt alone is 3,714 tokens, not 1,000. The rest is mostly tool
schemas, which are the instructions that teach the model how to call each tool.

## Daily workflow

1. Start with `omp` inside the repository root.
2. State the result you want and how it will be proved.
3. Reference a small file with `@path/to/file` instead of pasting it.
4. Let grep, glob and LSP find the right code before reading whole files.
5. For a broad investigation, ask OMP to create a checkpoint, investigate, and
   rewind with a short report. This removes the exploration from the live
   conversation while keeping the findings.
6. Use `/session` to check context. Use `/compact Focus on ...` before a long
   final implementation if the session is near 25K.
7. Start a new session when the goal changes. Do not carry an unrelated task in
   an old conversation.

Run a shell command with `!command` when its output should enter the model
context. Use `!!command` when only you need the output. This is useful for noisy
status commands and saves context.

## oMLX commands

| Command | Effect |
| --- | --- |
| `omlxctl status` | Show server, profile, process memory and swap |
| `omlxctl profile daily` | 30K exact context, 25K compaction, best daily mode |
| `omlxctl profile scan64` | 64K text-only scan with SpecPrefill 20 percent |
| `omlxctl profile check` | Prove that the four live config files match |
| `omlxctl logs` | Follow the server log |
| `omlxctl restart` | Restart a stuck server |
| `omlxctl stop` / `start` | Free model memory or start it again |

`scan64` is for a rare one-shot repository scan. It uses approximate prompt
selection and needs more memory. Return to `daily` for implementation work.

## OMP commands

| Command | Effect |
| --- | --- |
| `omp -c` | Continue the latest session in this folder |
| `omp -r` | Pick an older saved session |
| `omp @file "question"` | Start with one file attached |
| `omp --thinking low` | Faster work with less reasoning |
| `omp --thinking medium` | More reasoning for hard debugging |
| `/session` | Show current usage and session data |
| `/compact Focus on X` | Summarize old context around the named goal |
| `/tree` | Move through the session history |
| `/fork` | Start a new branch from an earlier message |
| `/model` | Pick a model or role |
| `/settings` | Open OMP settings |
| `/hotkeys` | Show all keyboard shortcuts |

Use low thinking for routine edits. Use medium for a hard bug or design choice.
Old thinking is not replayed to oMLX in later calls.

## Useful skills

Invoke a skill with `/skill:NAME` in interactive OMP.

| Skill | Use it when |
| --- | --- |
| `basic-memory-workflow` | A task must load and update project memory |
| `measured-quality` | Tuning a score, ranking, search or model answer |
| `orca-cli` | Working with Orca worktrees, terminals or artifacts |
| `computer-use` | Controlling a native Mac app or visible browser window |
| `orchestration` | Coordinating a large task across several agents |
| `find-skills` | Looking for a reusable skill for a new kind of task |

Skills are listed in the prompt but their full instructions are loaded only
when needed. Keep project-specific skills small and place them under
`.agents/skills/NAME/SKILL.md`.

## Settings kept by Nix

- Compact prompt and no decorative personality.
- Old reasoning is not replayed.
- Repeated file reads and useless tool results are pruned.
- Large files are summarized before being returned.
- LSP starts only when used and is shared between OMP sessions.
- Diagnostics run after writes and edits, with duplicates removed.
- Checkpoint and rewind are enabled for long investigations.
- Automatic compaction can run during a tool loop or while idle.
- Run `omlxctl stop` after a local-model session to return about 20 GB to the
  browser and Docker. Run `omlxctl start` before the next session.

The source of truth is `local-llm.nix`. `./rebuild.sh` restores these settings
after an OMP or oMLX update.
