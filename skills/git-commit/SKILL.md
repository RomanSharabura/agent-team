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

## Subject: at most 72 characters (hard limit)
CI fails the whole PR if any commit subject is longer than 72 characters, counting the type, module, REQ IDs and spaces. A pushed subject cannot be fixed without rewriting history, which is not allowed after the PR is open, so check it **before** every commit.
- Name at most two REQ IDs, or one range: `REQ-002..008`, not `REQ-002..006 REQ-008`. The full list goes in the body.
- Say what was done in a few words; the details go in the body.
- Example: `feat(users): REQ-002..008 protect admin endpoints` (49), not `feat(users): REQ-002..006 REQ-008 protect admin endpoints with the Admin policy` (79, failed CI on dopamine-shop #77).

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
len=$(head -n1 /tmp/commit-msg | LC_ALL=C.UTF-8 wc -m); len=$((len - 1))
[ "$len" -le 72 ] || { echo "Subject is $len characters, max 72: shorten it"; exit 1; }
git commit -F /tmp/commit-msg --trailer "Agent: $AGENT_ID"
```
If the check fails, shorten the subject and run it again. Never commit with a longer subject.
`--trailer` appends the line `Agent: dev` (or `qa`, `architect`): this shows on GitHub which agent made the commit, even though all commit as the bot. Do not change the author via `git config`: a name like `dopamine-dev-bot (dev)` is already set by the `GIT_AUTHOR_*` variables.

## CHANGELOG
- One line per PR in `## [Unreleased]` under `Added` / `Changed` / `Fixed` / `Removed` / `Security`.
- Write what changed for the API user or developer, not how: "Admin user list with pagination, email search and status filter. (SPEC-001, #1)".
- Do not edit old lines or release sections.

## Not allowed
- A commit without a body; `wip`, `fix`, `update` as the whole subject.
- A subject longer than 72 characters (see above).
- `--amend` and force-push after the PR is open: new changes go in new commits.
