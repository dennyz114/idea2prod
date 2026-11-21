# <Feature title>

**Ticket:** <owner/repo#number, or "pending">
**Size:** small | medium | large
**Execution:** direct | orchestrate   <!-- direct: a single agent does it; orchestrate: one helper per phase -->
**Base:** <branch or commit this plan was written against>

## Context

The problem this solves and why now, in 2 or 3 lines. Which code and which ADRs it touches.

## Decisions

- <decision> — rejected: <alternative and why>

## Phases

### A1. <name>  (mechanical | judgment | critical | ui)
- **Does:** <what changes>
- **States** (ui only): loading, empty, error, success
- **done-check:** `<command that must pass>` → <expected result>

### B1. <name>  (...)
- ...

## Security and performance risks

- **Security:** <permissions, user input, sensitive data, new dependencies; or "none">
- **Performance:** <queries, large lists, bundle; or "none">
- **Test data:** <which seed it needs, or "base">

## Out of scope

- <what was decided not to do, and when it would be worth doing>

## Open questions

- <none, or what is still undecided>
