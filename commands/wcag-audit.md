---
description: "Audit the codebase against WCAG AA: contrast, semantics, labels, focus, and use of color"
---

Run a WCAG accessibility audit on: $ARGUMENTS

**Project settings:** Read `.claude/project.md` for project-specific configuration (file paths, design system doc, docs repo, etc.) before executing. Use those values throughout this workflow.

**IMPORTANT: This workflow requires EXECUTION, not description. When a step says "do X", actually do it. Do not describe what you would do or ask for permission - execute the step.**

**Output location:** Check project.md for an "Audit Output" section. If a WCAG/accessibility audit path is specified there, use it. Otherwise default to the plans directory, file named `wcag-audit.md`.

This is a **code-based audit** — findings come from reading source files and computing contrast ratios, not from screenshots or browser automation.

## Scope

Parse `$ARGUMENTS`:
- A path (file or directory) → audit those files
- A component/page name → find and audit it plus the shared components it imports
- Empty → audit the whole source directory: shared UI primitives first, then pages/views

## Process

1. **Load the design context:**
   - Read the project's Design System doc (path from project.md) if one exists — note any documented contrast rules and approved token combinations
   - Read the global CSS / theme config to build a token map: token name → resolved hex value (follow `var()` chains)
   - Note which tokens are documented as text colors vs fills

2. **Compute the palette's baseline contrast matrix** — for every documented text-token/background-token combination, compute the WCAG ratio:
   ```bash
   node -e '
   function lum(h){const c=h.replace("#","");const[r,g,b]=[0,2,4].map(i=>parseInt(c.substr(i,2),16)/255).map(v=>v<=0.03928?v/12.92:Math.pow((v+0.055)/1.055,2.4));return 0.2126*r+0.7152*g+0.0722*b}
   function cr(a,b){const[x,y]=[lum(a),lum(b)].sort((p,q)=>q-p);return((x+0.05)/(y+0.05)).toFixed(2)}
   // console.log(cr("#FG","#BG")) for each pair
   '
   ```
   Thresholds: **4.5:1** for text under 24px (under 18.66px if bold); **3:1** for larger text and for UI component boundaries/states (WCAG 1.4.11). Any token combination that fails at its typical usage size is a systemic finding — flag it once at the token level, then flag usages.

3. **Audit every file in scope.** Record file, line, and the offending code for each finding:

   **Contrast (1.4.3 / 1.4.6):**
   - Text using tokens or utility classes that fail the matrix from step 2 at their rendered size
   - Arbitrary hex/rgb/oklch colors and non-semantic utility classes (`text-gray-400`) — compute their ratio against their actual background
   - Opacity-reduced text (`text-.../50`, `opacity-*` on text elements)
   - Light text on light fills (white on pale/tinted backgrounds)
   - Text over images or gradients with no contrast guarantee (no scrim/overlay)

   **Non-text contrast & boundaries (1.4.11):**
   - Inputs, toggles, and cards whose only boundary is a background difference below 3:1
   - Focus indicators removed (`outline-none`) without a visible replacement (`focus-visible:` styles) — also check keyboard focus order isn't broken by positive `tabIndex`
   - Disabled-looking styling on enabled controls

   **Semantics & structure (1.3.1, 2.4.6, 4.1.2):**
   - Clickable `div`/`span` with onClick instead of `button`/`a` (no keyboard access)
   - Heading levels skipped or multiple h1s per page
   - Lists built from divs where `ul`/`ol` semantics matter
   - Landmarks: main content not in `main`, nav not in `nav` (flag once per layout, not per page)

   **Labels & alternatives (1.1.1, 2.4.6, 3.3.2):**
   - `img` without `alt`; meaningful icons without accessible names; decorative icons not `aria-hidden`
   - Icon-only buttons without `aria-label`
   - Inputs whose only label is a placeholder; labels not programmatically associated (`htmlFor`/wrapping)
   - Error messages not associated with their field (`aria-describedby` / `aria-invalid`)

   **Use of color (1.4.1):**
   - Status/meaning conveyed ONLY by color (a dot, border, or tint) with no text or icon carrying the same information
   - Links distinguishable from text only by color within prose

   **Interaction (2.5.8, 2.1.1):**
   - Interactive targets visibly smaller than 24x24px with no spacing compensation
   - Custom interactive widgets (dropdowns, dialogs, tabs) missing keyboard handling or ARIA roles/states — if the project uses a headless/accessible library (Radix, Base UI, shadcn, Astryx), verify custom-built widgets against what the library would have provided

4. **Write the audit report** to the output location:
   - **Summary** — overall state, counts by severity, the systemic (token-level) findings first
   - **Findings table** ranked by severity, each with: file:line, offending code, WCAG criterion, computed ratio where applicable, and a concrete fix
     - **FAIL** — violates WCAG AA
     - **WARN** — passes technically but fragile, or AAA-only concern worth knowing about
   - Findings in shared/base components come first and note the blast radius (every consumer is affected)
   - If an area is clean, say so plainly — do not pad the report with invented findings

5. **Present the summary** to the user with the top findings, then **ask whether to apply fixes** (all, FAILs only, or none). If yes:
   - Apply minimal diffs — fix the accessibility issue without redesigning anything
   - Fix shared components first, then page-level instances
   - Run the project's CI checks from project.md conventions (typecheck, lint, tests) before committing
   - Do not change design tokens without asking first — token changes affect everything
   - Commit with a descriptive message following project conventions

## CRITICAL CONSTRAINTS

**DO NOT:**
- Use screenshots or browser automation — this audit reads code
- Redesign components while fixing — minimal diffs that resolve the finding only
- Flag compliant patterns (e.g. small uppercase labels in an AA-passing color, or WCAG AAA criteria presented as failures)
- Change design tokens without explicit user approval
- Edit anything before the user has chosen what to fix in step 5
