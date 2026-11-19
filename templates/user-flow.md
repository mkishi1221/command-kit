# {Product} — User flow

<!--
Rules: planning-doc-spec.md §1. This describes the whole product as the user experiences it, in the order they meet it. It is the source the roadmap is derived from, not a plan.
- Present tense — true of the finished product, not of what's built yet.
- Every step has Sees / Does / System. Edge cases and failure states are sub-steps.
- Sections are lettered (A, B…), steps numbered within (A1, A2…). The roadmap points at a step by its section, so keep the numbering stable.
- Mark shipped steps `✅ shipped YYYY-MM-DD` for continuity — nothing else about build state lives here.
- Never here: build order, priorities, phases, dates; implementation nouns (tables, routes, endpoints, components, state); anything about HOW a step is built.
- Boundary test: naming something that exists in the repo rather than something the user perceives? It belongs elsewhere.
-->

## Section A — {Name}

### A1 — {Step name}

- **Sees:** {what is on screen at this point}
- **Does:** {the action the user takes}
- **System:** {what the product does in response, as the user perceives its effect}

  - **A1a — {edge case / failure state}:** {Sees / Does / System for this branch}
  - **A1b — {edge case / failure state}:** {…}

### A2 — {Step name} ✅ shipped {YYYY-MM-DD}

- **Sees:** {…}
- **Does:** {…}
- **System:** {…}

## Section B — {Name}

### B1 — {Step name}

- **Sees:** {…}
- **Does:** {…}
- **System:** {…}

---

## Out of scope

<!-- Things a reader would expect here and won't find, each with the reason. -->

- {Thing not covered} — {why it's absent}

## Open questions

<!-- Only steps where two answers would produce genuinely different flows. State both answers, not a preference. -->

- {Step / decision} — {answer 1} vs {answer 2}
