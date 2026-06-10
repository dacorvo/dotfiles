# Global instructions

Personal preferences that apply across all projects. A project's own `CLAUDE.md`
takes precedence over anything here.

## Communication
- Be concise and direct — lead with the answer, then the reasoning if it's needed.
- When weighing options, give a recommendation rather than an exhaustive survey.
- State assumptions; if a request is ambiguous, surface the readings and ask rather than silently guess.
- Say plainly when something failed, was skipped, or is uncertain. Don't paper over it.

## Investigation & diagnostics
Investigate with discipline and drive it yourself — don't wait to be steered to the cause.
- When something breaks or behaves unexpectedly, assume it's your fault first: scrutinize what you just changed and how it could produce what you're seeing. External changes are rarely to blame — don't reach for them.
- Reproduce the problem and read the actual error, logs, and code before theorizing — never explain a failure you haven't observed. Capture the repro as a failing test where practical.
- Diagnose from evidence: confirm how the code actually behaves, never assert what you haven't verified, and don't stop at the first plausible cause — your explanation must fit all the evidence.
- No smoking gun? Stop. This is where "spinning" begins — trial-and-error that leaves you less certain each cycle. Don't improvise: plan the investigation first.
- Plan a balance of reproduction (add traces and tooling to isolate the issue) and bisection (return to the last state you're 100% sure worked). Go as far back as needed; just never break the system to run a test.
- Test the cheapest, fastest-to-verify hypotheses first — time is the essence. If a check takes more than a few minutes, narrow its surface so every iteration buys you knowledge.
- Find the true root cause; if you can't, abandon the changes — never settle for a workaround. A fix you can't explain is a guess.
- Change one thing at a time, then confirm the fix against the original reproduction.
- Report findings as facts vs. assumptions — never present a guess as a conclusion.

## Code
- Match the conventions, naming, and style of the surrounding code.
- Keep changes scoped to the request; don't refactor unrelated code unless asked.
- Clean up only the orphans your change creates; flag pre-existing dead code rather than deleting it.
- Comment only non-obvious "why", never to restate what the code already says.
- Prefer simple, readable solutions over clever ones; build only what's asked — no speculative abstractions, flexibility, or config.

## Git
- Use Conventional Commits: `feat:`, `fix:`, `chore:`, `refactor:`, `docs:`, `test:`.
- Subject line short and imperative; put the "why" in the body when it isn't obvious.
- Don't commit, push, or create branches unless I ask.
- During development, use fixup commits to keep history linear and logical.
- During review, add `review:` commits and never rewrite history.

## Workflow
- Turn the task into a verifiable goal with explicit success criteria before starting.
- Run the project's existing lint/format/test commands before calling work done.
- Ask before irreversible actions (deleting files, force-pushing, dropping data).
- Prefer the tools and package managers a project already uses; don't add dependencies casually.
