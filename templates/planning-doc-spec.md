# Planning document spec

Defines what each of the three planning documents is for, what it contains, what it must not contain, and how they hand off to each other.

---

## The principle underneath

Every rule in this spec derives from one constraint: **no state that exists only in your head or your terminal.**

Three mechanisms enforce it, and they're the same move applied to three kinds of state:

| State | Mechanism |
|-------|-----------|
| Repo | Every slice ends green and committed |
| Environment | Entity lifecycles close (create → verify → recover → destroy) so the system can return to a known state |
| Correctness | Verification happens through the product, and the test ships with the slice |

Rules people understand the reason for survive contact with a deadline. Rules they don't, don't.

---

## The three documents at a glance

| | User flow | Roadmap | Sprint plan |
|---|---|---|---|
| **Atomic unit** | Journey step | Shippable unit | PR / slice |
| **Question it answers** | What does the product do? | In what order do we build it, and why? | What changes in the repo next? |
| **Tense** | Present — true of the finished product | Future — true about sequence | Imperative — true about the next change |
| **Changes when** | The product changes | Direction changes — roughly once per phase, not as work progresses | A PR lands |
| **Read** | Once, for orientation | At the start of a unit | Every session, every turn |

The discriminator is the **unit**, not the altitude. "Is this a shippable unit or a PR?" is answerable by inspecting the thing. "Is this high-level enough?" is not, which is why detail-level boundaries drift.

---

## 1. User flow

### Purpose
Describe the entire product as the user experiences it, in the order they encounter it. It is the source the roadmap is derived from, not a plan in itself.

### Contains
- Numbered journey steps in narrative order
- Sees / Does / System for every step
- Edge cases and failure states as sub-steps
- `✅ shipped <date>` markers on steps that exist, for continuity
- Out of scope: things a reader would expect and won't find, with reasons
- Open questions: steps where two answers would produce different flows

### Does not contain
- Build order, priorities, phases, dates
- Implementation nouns: tables, routes, endpoints, components, state
- Anything about how a step is built

### Boundary test
If you're naming something that exists in the repo rather than something the user perceives, it belongs elsewhere.

---

## 2. Roadmap

### Purpose
Decide and record **build order, and the reason for it**. This is the only document that arbitrates sequence, and sequence is a real decision with real consequences — build in the wrong order and you get features connected to nothing, which can't be verified.

Order comes from the journey, adjusted for risk. Where the two disagree, the roadmap says so explicitly.

### Contains
- **Capacity** — working days per week, so estimates convert to dates
- **Entity model** — entities, relationships, and which unit each lands in. **Names only, no fields.**
- **Units in build order** — each one a heading (name plus flow section), an estimate in working days with a coarse target, and a **succinct, complete statement of what a user can do when it ships** — as many lines as the behaviour genuinely has parts, and no more. Capture everything; use no prose and no editorialising — no rationale, no reassurance, no adjective that doesn't change what ships. Plus a reason **only where the position isn't self-explanatory** (see below)

Everything in the roadmap is ordered. There is no parking lot — an unordered unit isn't a plan, and a section that collects them never empties.

Three fields, and each earns its place: the flow section is the pointer up, the estimate is the timeline, the behaviour is the exit criterion. Nothing else. Entities per unit duplicate the model table's `Lands in` column. Lifecycle closure is a rule that belongs in this spec, not a field repeated on every unit. Deferred scope is already implied by the exit criterion — anything not in it isn't in the unit.

### Does not contain
- File paths, component names, endpoint names
- Field or column names
- Task verbs: `add`, `implement`, `create`, `refactor`

### Boundary tests
- **Naming a field?** Sprint plan.
- **Task verb?** Sprint plan.
- **Naming a UI piece or interaction** — a dialog, a loader, progressive reveal, drag-to-resize, undo/redo, span editing? Sprint plan. It's a slice of building a capability, not a capability.
- **Granularity scan:** read down the unit list. Every entry should sit at the same altitude. A roadmap reads like a sprint plan most often because of one stray implementation detail sitting next to three genuine units, not because the whole level is wrong.

### Dependency is carried by the order

Dependency is not stated as a separate structure. The order **is** the dependency, and it's legible from what's already in the document: the entity model shows that projects reference users, so projects come after users. The flow shows you can't demonstrate publishing without an account. Restating those as a graph would be a third copy of facts that already live in two places, and it's the copy that goes stale silently.

The exception is narrow: **when a unit's position is not explained by the entity model or the journey, say why in one line.** Out-of-journey-order placement is the case that's genuinely invisible. Everywhere else, silence — which makes the annotations that do appear worth reading.

### Stability

The roadmap is written once per product phase and mostly read. It is not regenerated as work progresses.

That's a usable misfiling detector: **if you're editing the roadmap more than about once per unit, whatever keeps changing belongs in the sprint plan.** Edit frequency is easier to notice than a category error, and it catches the same drift.

### What makes a unit a unit
Not size. A unit can be fifteen slices and still be a unit. Two tests:

- **Verifiable inside:** each slice within it is independently verifiable — if nothing inside can be verified until the whole thing lands, it's a blocking phase, at any size.
- **A capability, not a slice of one:** a unit is something a user can newly do or have, named as such. The mechanics of building it — a loading screen, a confirm dialog, progressive reveal, span editing, undo/redo, drag-to-resize — are slices, and live in the sprint plan. If a "unit" is a widget, an interaction, or a build step rather than a user-facing capability, collapse it into the capability it serves. The whole redaction gate is one unit; highlight, detection, and confirm are its slices.

---

## 3. Sprint plan

### Purpose
Break one roadmap unit into PR-sized vertical slices. This is the working document — re-read every session, mutated every turn. Its checkbox state means *committed and green*, not *some code exists*.

### Contains
Per slice:
- **Goal** — one line, what a user can do after this lands
- **Migration** — the schema change, and whether it is additive
- **Code** — full CRUD for the entity or field group in scope
- **UI** — the surface that makes it verifiable
- **Tests** — behaviour-level, shipping in the same PR
- **Verification** — the steps to confirm it works, through the product
- **State** — one checkbox per slice, not per sub-task

### Does not contain
- Rationale, user value, alternatives considered — that's the roadmap
- Anything explaining why this unit comes now

### Slice rules
1. **Vertical means whole.** Migration + CRUD + UI + tests ship in one PR. Never split by operation — shipping create without delete is a one-way door in the test environment.
2. **Split by data scope, not by operation.** If the schema is large, break the schema into chunks and ship the migration across several PRs. Never land a big schema in one go — it's the least reviewable kind of diff, silent when wrong, and hardest to reverse.
3. **Additive only.** Additive migrations compose; each leaves the system green. A slice that must alter or drop something a previous slice shipped is three PRs (expand → migrate → contract) *and* a signal that a fixed decision was made too late. Note it as such.
4. **Size is a number.** Estimate lines changed (additions + deletions, excluding lockfiles and generated output), and derive the rating mechanically from the count: **S** <500 · **M** 500–800, allowed only where it genuinely has to ship as one unit, with a **Justification:** line · **L** 801–1000 · **XL** >1000. **L and XL must be split before planning** — a task that lands is S or M. The number is the truth, not a semantic judgement: it can be checked against git afterwards and the estimate calibrates; the letter is only its band.
5. **Green at every boundary.** Each slice leaves the system deployable. The commit is the recovery point.

### Verification hierarchy
1. **Through the product.** If you need to inspect the database to know a slice landed, the slice wasn't vertical. That's the diagnostic.
2. **The test is the surface** where there genuinely isn't one — background jobs, webhooks, retention jobs. State the contract explicitly rather than letting it default.
3. **Dashboard checks** (Supabase logs etc.) are an acknowledged edge case, not a pattern to spread.

### Why tests ship inside the slice
A test written later is written against the code that exists — it records what was built, not what was intended. Those coincide only if the code was already right, so a retrofitted test can detect that behaviour *changed* but never that it was wrong. The slice is the only moment intent and implementation are independently available to check against each other.

Two consequences:
- Tests must be **behaviour-level**. An implementation-level test records how it was built, not what it was for, and can't do this job.
- Tests mark which behaviours are **load-bearing**. Without them every line looks equally arbitrary and equally safe to change — which is when an agent "improves" something deliberate.

---

## Cross-cutting rules

### Single-source
Any fact stated in two documents will diverge. Each fact lives in exactly one document; the others reference it by name.

- The roadmap **names** units. The sprint plan **defines** slices.
- The roadmap never contains the word for an individual slice.
- The sprint plan never restates why a unit comes now.

### Handoff
```
flow step  →  roadmap unit  →  sprint plan slices
  (what)        (order + why)      (PRs)
```
One flow step may produce several units across different passes. One unit produces many slices.

### Depth on the first pass
A unit is built as deep as **the union of** what the next journey step needs and what the build loop needs. The second is invisible on a user-journey map because the person building it isn't on the map — password reset and delete account are build-loop requirements, not deferred features.

Where an item is early, record which applies:
- **Lifecycle closure** — needed to keep working (reset, delete)
- **Model shape** — changes the data model if added later (additional auth providers, account linking)
- **User value** — the feature itself

### Changing the plan

When something needs to change, first establish **breadth** — the highest document affected. Then change from there downward. Never upward, never sideways.

Breadth is determined by what the change *touches*, not by what kind of change it is:

| If it changes… | Enters at | Propagates to |
|---|---|---|
| What the user does or sees, structurally | User flow | Roadmap, then sprint plan |
| Entities, relationships, or build order | Roadmap | Sprint plan |
| Neither | Sprint plan | — |

So "we need middle names" enters at the sprint plan: it adds a field to an entity that already exists, in a unit that's already ordered. Nothing above it moves. "We need organisations, and users belong to one" enters at the roadmap, because it adds an entity and changes what has to be built before what. Same category of request — different breadth, because they touch different things.

Determining breadth first is what stops a journey change being patched into a sprint plan, which is the failure mode that makes the documents disagree.

### No filler

These documents say what needs to be built. Nothing else.

The test for any line: **does it change what gets built, or how it's verified?** If not, cut it.

Specifically, don't write:

- Overview, Background, Purpose or Summary sections that restate what's below
- Change history — "this was moved", "no longer does X", "changed from Y". Git has it, and a line describing a state that no longer exists competes with the one that's live. Completion is different and belongs, as current state: `[x]` on a roadmap unit or a sprint slice, and `✅ shipped <date>` on a user-flow step (the ship date is the one piece of history that earns its place — a stable fact about a step that still exists). PR numbers and "superseded by" notes are still history and don't
- Status commentary — "in progress", "going well", "blocked on Dave"
- Hedged options — "we may want to consider", "one approach could be"
- Rationale for anything unsurprising. Reasons are for the exceptions
- The same fact in two places for readability. It reads better right up until the two copies disagree
- Prose where a list would do. These are read by an agent, not presented to a room

Two costs, not one. Filler confuses — an agent has no memory to arbitrate which line is live, so a stale or hedged line is read as current instruction. And filler is re-read: the sprint plan is loaded every turn, so anything in it is paid for on every turn of the unit. The flow and roadmap are read roughly once per unit. Tightness matters most at the bottom.

### Sprint plan entry format

One task = one PR, written as a checkbox line plus indented fields. The CRUD, UI and test breakdown lives in the generated issue, not here — this file names the PR and nothing more.

```
- [ ] `/feature [title]` #[issue] (Dependencies: [Sn.n / none], Complexity: ~[n] lines → [S|M|L|XL])
  - **Design reference:** `[path]` ([flow section])
  - [What it does]
  - [Schema: none / includes migration NNN for X]
  - **Review focus:** [what isn't obvious from the title]
  - **Verify:** [one path through the product]
```

Field rules:

- **Title carries the weight.** If it needs a paragraph to explain it, the slice is too big.
- **Design reference points, never restates.** Copying the flow or design doc into here creates the second copy that eventually disagrees.
- **What it does** is one line. Two only where behaviour genuinely branches.
- **Justification** appears on M entries only, and is the sole reason line permitted in the file — it says why the slice can't ship under 500 lines, not why it's prioritised.
- **Review focus** is for what Claude wouldn't check anyway. If it would, don't write it.
- **Verify** is one path through the product, not a test matrix.
- **Completion is the checkbox.** No dates, no PR numbers, no "split into #27", no "superseded by".
- **No sprint preamble.** Why a sprint comes now is the roadmap's job.

### The escape valve
If you're arguing about which document something goes in, it probably doesn't matter. These rules exist to stop the roadmap and sprint plan converging, not to make every line adjudicable.

