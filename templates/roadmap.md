# {Product} — Roadmap

<!--
Rules: planning-doc-spec.md §2. This file arbitrates BUILD ORDER and the reason for it — nothing else.
- Unit = a heading (name + flow section) + a working-days estimate with a coarse target + a succinct, complete statement of what a user can do when it ships (as many lines as the behaviour has parts; no prose, no editorialising).
- A unit is a user-facing capability, not a UI piece or build step — no "loading screen", "progressive reveal", "span editing", "undo/redo"; those are sprint-plan slices. The whole redaction gate is one unit, not eight.
- Order IS the dependency. Add a "Why here:" line ONLY where position isn't explained by the entity model or the journey.
- Never here: file paths, component/endpoint names, field/column names, task verbs (add/implement/create/refactor), per-unit entity lists (the model table's `Lands in` is the source).
- Written once per phase, mostly read. Editing more than ~once per unit means the change belongs in the sprint plan.
- Mark a shipped unit `[x]`. No dates-done, no PR numbers, no "superseded by".
-->

## Capacity

{N} working days/week ({which days}). Estimates below convert to targets at this rate.

## Entity model

<!-- Names only, no fields. `Lands in` is the single source for which unit an entity arrives in. -->

| Entity | Relationship | Lands in |
|---|---|---|
| {Entity} | standalone | {P1.1} |
| {Entity} | references {Entity} | {P1.2} |
| {Entity} | owned by {Entity} | {P2.1} |

---

## Phase 1 — {Name} ({Flow section})

### P1.1 — {Unit name} ({Flow section})

{What a user can do once this ships — succinct and complete, no prose or editorialising.}
Est: {N} days · Target: {coarse target, e.g. wk of DD Mon}

### P1.2 — {Unit name} ({Flow section})

{What a user can do once this ships — succinct and complete, no prose or editorialising.}
Est: {N} days · Target: {coarse target}

---

## Phase 2 — {Name} ({Flow section})

### P2.1 — {Unit name} ({Flow section})

{What a user can do once this ships — succinct and complete, no prose or editorialising.}
Est: {N} days · Target: {coarse target}
Why here: {reason — ONLY because position isn't explained by the entity model or journey order}
