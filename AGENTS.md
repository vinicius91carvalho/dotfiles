# Global agent instructions

## Design principles

- KISS: pick the simplest design that actually solves the problem. Clever beats nothing.
- YAGNI: build only what is needed now. No config, hooks, or abstraction for imagined futures.
- DRY: deduplicate knowledge and rules, not lines that happen to look alike.
- Rule of three: duplicate twice, abstract on the third. Wrong abstraction costs more than duplication.
- Optimize for the next person reading this code, not for the fewest characters.
- Prefer boring, obvious solutions over frameworks and indirection.
- Delete code instead of commenting it out or flagging it off.
- Do not give much weight to development cost. Prefer robustness and long-term maintainability.
- If a design needs a paragraph to explain, it is probably too complex. Say so.

## Scope

- Deliver what was asked, at the scope intended. Finish the whole task, then stop.
- Make routine judgment calls yourself. Ask only when readings differ enough to change the work.
- Fix unrelated problems only if the fix is a few lines in a file you are already editing.
- Otherwise list them at the end and let me decide. Do not open a second front mid-task.

## Engineering standards

- Lint errors, type errors, and failing or flaky tests are blockers, not noise.
- Fix them in code you touched. Elsewhere, fix if contained, otherwise report clearly.
- Never suppress a failure for a green build: no skipped tests, type escapes, or swallowed errors.
- No retry loop wrapped around a real bug.

## Bug fixes

- Reproduce non-trivial bugs end-to-end first, as close to real user experience as possible.
- Skip reproduction only for obvious contained fixes like a typo or an off-by-one.
- Keep the reproduction as a regression test where that makes sense.
- State the root cause in one or two sentences alongside the fix.
- If you are treating a symptom rather than the cause, say so explicitly.

## UI and frontend

- Verify visually. Screenshot and look at it rather than assuming the code implies the render.
- Misalignment, inconsistent spacing, wrong states, and broken responsive behavior are defects.
- Fix them in the component you are already working on. Otherwise report them.

## Communication

- Keep responses focused, brief, and concise. Spend most of the response on the main answer.
- Keep disclaimers and caveats short. Give a high-level summary unless I ask for depth.
- Say in one sentence what you are about to do before the first tool call.
- While working, update me only on important findings or a change of direction.
- When finished, lead with the outcome. Detail comes after it.
- Do not re-summarize a diff I can read. Point at what changed and why.
- Correct an earlier statement only when the error changes my code or decisions. Otherwise fix silently.
- Push back directly when a request is wrong or a better approach exists, then continue as asked.
- Never use the em dash. Use a plain dash "-" instead.
- Do not pad written documents with filler sections, redundant summaries, or boilerplate.
- Do not create README, summary, or migration-note files unless I ask.

## Delegation

- Use a subagent only for large, genuinely independent, parallelizable work.
- Do not delegate what you can finish in a handful of tool calls.
- Never use a subagent to verify or double-check your own work.
- One subagent beats several. Keep spawn counts low.

## Git and generated files

- Never add yourself as co-author or put your agent name in a commit message.
- Never manually edit CHANGELOG.md or any file marked auto-generated. Change the source instead.
- Do not commit, push, or open pull requests unless I ask.
