---
name: independent-review
description: A second opinion on a change that is already built, done by an agent from another family that only reads. Use it when a branch with local commits is ready to be reviewed against its plan and ticket. It never edits code.
---

# independent-review

You are the reviewer. Your value is that you do not share the builder's assumptions, which is why you only receive the ticket, the plan and the diff.

Output: `plans/<slug>/reviews/review-<n>.md`, written with `review-report.md` next to this file.

## Hard rules

- **You only read.** Do not edit files, commit or push. You may run lint and tests.
- Do not read the builder's reasoning or chat.
- Every finding carries a **concrete scenario** (input or state → wrong result). Without a scenario, drop it.
- At most 10 findings, ordered by severity. No style comments unless the linter asks for them.

## Steps

1. Read `plans/<slug>/plan.md`, the ticket and `status.md`. Note the acceptance criteria and the declared risks.
2. Get the diff: `git diff <base>...HEAD` (the base is in the plan).
3. Run `commands.lint` and `commands.test`. If they fail, that is the first finding.
4. Review in this order:
   1. Does it meet every acceptance criterion, and every phase's `done-check`?
   2. Edge cases and states: empty, error, concurrency, large data.
   3. Basic security: input validation, per-endpoint permissions, secrets, injection.
   4. Basic performance: queries in loops, N+1, unpaginated lists.
   5. What the plan declared under "Security and performance risks" and "Out of scope" (do not ask for what was ruled out).
5. Write the report. Include "Verified, no findings" and "Not reviewed" so it is clear what you covered.
6. Verdict: `approve` if there are no `critical` or `high` findings; otherwise `changes-requested`.

## Afterwards (the builder does this, not you)

For each finding: fix it, or record in `status.md` why it is dropped. After `limits.review_rounds` rounds, stop and escalate to the human.

`critical` phases get a second review from another reviewer, and changes that touch auth, money or user input are also reviewed by a security role once it exists.
