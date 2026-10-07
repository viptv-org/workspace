# Domain documentation

Layout: single-context per owning repository, with existing design documents
authoritative across the workspace.

Use the existing design-owned vocabulary and decisions. Before changing domain
behavior read `design/plans/backend-v2/BACKEND_V2.md`,
`design/plans/backend-v2/IMPLEMENTATION_V2.md`, the target repository's
`DESIGN_REF` and relevant `design/docs/adr/` decisions. Client
geometry and interaction rules remain in the existing design specifications.

Read an existing owning-repo `GLOSSARY.md` or `GLOSSARY-MAP.md` and relevant ADRs
when present. Proceed silently when absent. This workspace adds no duplicate
glossary or domain model. Surface conflicts with design decisions explicitly.

Subagents follow `AGENTS.md`: use `gpt-6.1-sol` with high reasoning (`high`) for
implementation, testing, investigation and review, including retained workers.
