---
name: git-commit
description: Write commits with a short typed subject and a body listing what changed and why; keep CHANGELOG.md updated per PR.
metadata: { "openclaw": { "requires": { "bins": ["git"] } } }
---
# Git commit

A reader of the commit must understand the change without the diff. CI (`PR hygiene`) checks the subject and body of every commit and the CHANGELOG entry.
Write commit subjects and bodies in English.

## Format
```text
<type>(<module>): <REQ-ID if any> <what was done>      ≤ 72 characters

- what changed and why (one item per notable change)
- names of classes, endpoints, migrations — as in the code
- what did NOT change, if not obvious

Refs: SPEC-NNN, #<issue>
```
Types: `feat`, `fix`, `refactor`, `test`, `docs`, `build`, `ci`, `chore`.

## How to commit
Write the message to a file and pass it via `-F` so the body is not lost:
```bash
cat > /tmp/commit-msg <<'MSG'
feat(users): REQ-003 search users by email

- ListUsersHandler filters by email substring; term is lowercased
- ListUsersValidator limits search to 320 characters, as in openapi.yaml
- integration test REQ_003_search_by_email_case_insensitive

Refs: SPEC-001, #1
MSG
git commit -F /tmp/commit-msg --trailer "Agent: $AGENT_ID"
```
`--trailer` appends the line `Agent: dev` (or `qa`, `architect`): this shows on GitHub which agent made the commit, even though all commit as the bot. Do not change the author via `git config`: a name like `dopamine-dev-bot (dev)` is already set by the `GIT_AUTHOR_*` variables.

## CHANGELOG
- One line per PR in `## [Unreleased]` under `Added` / `Changed` / `Fixed` / `Removed` / `Security`.
- Write what changed for the API user or developer, not how: "Admin user list with pagination, email search and status filter. (SPEC-001, #1)".
- Do not edit old lines or release sections.

## Not allowed
- A commit without a body; `wip`, `fix`, `update` as the whole subject.
- `--amend` and force-push after the PR is open: new changes go in new commits.
