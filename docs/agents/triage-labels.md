# Triage labels

The confirmed canonical mapping is identity: `needs-triage`, `needs-info`,
`ready-for-agent`, `ready-for-human`, `wontfix`. Categories are the `bug` and
`enhancement` labels. Reuse existing GitHub labels; do not introduce synonyms.
Every active repo has all of them.

| Label | Meaning | Agent action |
|---|---|---|
| `needs-triage` | filed, not yet evaluated | do not start; `/triage` it |
| `needs-info` | waiting on the reporter | do not start |
| `ready-for-agent` | actionable scope and acceptance criteria | pick up (see `issue-tracker.md`) |
| `ready-for-human` | needs judgment, authority or device access | do not start |
| `wontfix` | rejected or already implemented | closed as not planned |

Agent readiness requires an actionable scope and acceptance criteria; missing
authority/device access belongs with a human. Starting work does not change
the label: the linked branch and assignee show that an issue is in progress.
