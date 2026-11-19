---
description: "Audit design tokens: colors, fonts, spacing, borders, transparency, and visual consistency"
---

Audit the visual design system for consistency and correctness: $ARGUMENTS

**Project settings:** Read `.claude/project.md` for project-specific configuration (GitHub repo, file paths, docs repo, etc.) before executing. Use those values throughout this workflow.

**IMPORTANT: This workflow requires EXECUTION, not description. When a step says "do X", actually do it. Do not describe what you would do or ask for permission - execute the step.**

**Output location:** Check project.md for "Audit Output" section. If configured, use the design audit path specified there. Otherwise default to the plans directory, file named `design-audit.md`.

**Audience:** This audit is designed to be handed to a UI/UX designer as a complete picture of the current visual state of the app, informing a redesign. Write it so a designer who has never seen the codebase can understand the current design system, its strengths, weaknesses, and inconsistencies.

**Process:**

1. **Scan the design system foundations** by reading these files (adapt paths to the project's structure):
   - Global CSS file — CSS custom properties (`:root` and `.dark` themes)
   - Tailwind/theme config — extended theme tokens
   - Root layout — font loading and body classes
   - UI component primitives — scan all shared/base components

2. **Audit Colors** — Search the source directory for color usage:

   **Design Tokens (CSS Variables):**
   - List all CSS custom properties for color (from `:root` and `.dark`)
   - Check for unused tokens (defined but never referenced)
   - Check for missing dark mode counterparts

   **Hardcoded Colors:**
   - Find all hardcoded hex values (`#xxx`, `#xxxxxx`, `#xxxxxxxx`)
   - Find all hardcoded `rgb()`, `rgba()`, `hsl()`, `hsla()`, `oklch()` values used directly in components (not in token definitions)
   - Find all utility color classes using non-token colors (e.g., `text-red-500`, `bg-blue-200` instead of semantic tokens)
   - For each hardcoded color: note the file, line, and what token it should use instead

   **Color Consistency:**
   - Are similar colors used for the same purpose across components?
   - Are semantic colors used correctly?
   - Are there colors that are very close but not identical (possible accidents)?

   **Opacity/Transparency:**
   - Find all opacity values
   - Check for consistent opacity scales
   - Find hardcoded alpha values that should be tokens

3. **Audit Typography** — Search for font usage:

   **Font Families:**
   - What fonts are loaded
   - Find all font family declarations
   - Check for hardcoded font-family strings vs using tokens

   **Font Sizes:**
   - Catalog all text size classes used across components
   - Find any hardcoded font-size values
   - Check for consistent size scale usage
   - Identify if heading hierarchy is consistent

   **Font Weights:**
   - Catalog all font weight classes
   - Check for consistency

   **Line Heights & Letter Spacing:**
   - Find leading/line-height and tracking/letter-spacing values
   - Check for hardcoded values

   **Text Colors:**
   - Verify text colors use semantic tokens
   - Flag any hardcoded text colors

4. **Audit Spacing** — Search for spacing patterns:

   **Padding & Margin:**
   - Catalog the spacing scale actually used
   - Find any hardcoded pixel values
   - Check for consistent spacing patterns
   - Identify spacing values outside the standard scale

   **Gaps:**
   - Catalog gap usage in flex/grid layouts

   **Component Internal Spacing:**
   - Check if similar components use the same internal spacing

5. **Audit Borders & Rounded Corners**:

   **Border Width, Colors, Radius:**
   - Catalog border usage
   - Verify borders use tokens
   - Check radius consistency across similar components

   **Dividers & Separators:**
   - How are section dividers implemented? Consistent approach?

6. **Audit Shadows & Elevation**:
   - Catalog all shadow classes
   - Check for consistent elevation system
   - Catalog z-index values for coherent stacking

7. **Audit Transitions & Animations**:
   - Catalog transition and animation classes
   - Check for consistent timing
   - Find components missing transitions

8. **Component Inventory**:

   **UI Library Components:**
   - List every shared/base component with its variants and sizes
   - Note installed but unused components
   - Note customizations to defaults

   **Custom Components:**
   - List all custom components
   - For each: purpose, where it's used, and whether it duplicates a base component

   **Component Usage Map:**
   - Which components appear on which pages/routes

9. **Iconography Audit**:
   - What icon package is used
   - Icon sizing patterns and inconsistencies
   - Icon style consistency (outline vs filled)

10. **UX Patterns Audit**:
    - Loading states inventory
    - Empty states inventory
    - Error state patterns
    - Success/feedback patterns
    - Confirmation patterns
    - Toast/notification system

11. **Form Patterns Audit**:
    - Input styles and layout
    - Validation and error display
    - Button placement

12. **Interactive States Audit**:
    - Hover, focus, active, disabled state coverage
    - Missing states flagged

13. **Navigation & Information Architecture**:
    - Route/page map
    - Navigation patterns and hierarchy
    - How current location is indicated

14. **Responsive Design Audit**:
    - Breakpoint strategy and usage
    - Layout adaptation patterns
    - Touch targets

15. **Dark Mode Audit** (if applicable):
    - Completeness assessment
    - Quality issues

16. **Image & Media Treatment**:
    - Image display patterns
    - Avatar system
    - Fallback/placeholder approach

17. **Microcopy & Content Patterns**:
    - Button label conventions
    - Error message tone
    - Placeholder and empty state copy quality

18. **Accessibility (Visual Design Perspective)**:
    - Color contrast (WCAG AA)
    - Focus visibility
    - Touch/click target sizing

19. **Cross-UI Inconsistency Detection** — This is the most important section. Go page by page and compare how the same type of UI element is implemented. Flag every mismatch.

    **Dialogs & Modals:**
    - Find every dialog/modal in the app
    - Compare: width, padding, header style, close button placement, overlay color, border radius, animation
    - Flag any dialog that deviates from the majority pattern

    **Cards:**
    - Find every card-like container across all pages
    - Compare: padding, border, radius, shadow, background, hover effect
    - Flag cards that look different when they should look the same

    **Page Headers & Titles:**
    - Compare page-level headings across all routes
    - Check: font size, weight, color, spacing below, alignment
    - Flag pages where the header treatment differs

    **Tables & Data Lists:**
    - Compare all table/list implementations
    - Check: header style, row padding, hover state, border between rows, text alignment
    - Flag inconsistencies

    **Buttons in Context:**
    - Compare how buttons are used across pages (not just the component definition)
    - Check: are primary/secondary/destructive variants used consistently for the same action types?
    - Are button sizes consistent within similar contexts (e.g., all form submit buttons same size)?
    - Is spacing between button groups consistent?

    **Section Containers & Content Areas:**
    - Compare how content sections are wrapped across pages
    - Check: max-width, padding, background, vertical spacing between sections
    - Flag pages that use different container patterns

    **Labels, Badges & Tags:**
    - Compare all badge/tag/label elements
    - Check: size, padding, font, border-radius, color coding
    - Flag inconsistencies in how status/category is communicated

    **Empty & Placeholder States:**
    - Compare empty states across different features
    - Check: icon usage, message style, CTA button placement
    - Flag features missing empty states entirely

    **Page Layout Structure:**
    - Compare overall page structure across routes
    - Check: sidebar presence, content width, header/footer consistency
    - Flag pages that break the layout pattern

    For each inconsistency found, document:
    - **What:** The specific mismatch (e.g., "Dialog X uses 24px padding, Dialog Y uses 16px")
    - **Where:** File paths and line numbers for both sides
    - **Which is correct:** Recommend which version should be the standard (based on majority usage or design system)

---

20. **Generate the audit document** with these sections:
    - Design System Overview
    - Color Palette (token inventory, hardcoded colors, opacity)
    - Typography (font config, type scale, weight & style)
    - Spacing System
    - Borders & Radius
    - Shadows & Elevation
    - Component Inventory (library + custom)
    - Iconography
    - UX Patterns (loading, empty, error, feedback)
    - Form Patterns
    - Interactive States
    - Navigation & Information Architecture
    - Responsive Design
    - Dark Mode
    - Image & Media
    - Microcopy & Content Tone
    - Accessibility (Design)
    - Transitions & Animations
    - **Cross-UI Inconsistencies (by element type — dialogs, cards, headers, tables, buttons, containers, badges, empty states, layout)**
    - Consistency Issues Summary (prioritized: 🔴 Fix Now, 🟡 Fix Soon, 🟢 Nice to Have)
    - Recommendations for Redesign
    - Changelog

21. **Be specific:**
    - Use actual file paths and line numbers
    - Show the actual values found
    - Include counts and frequencies
    - Provide concrete "change X to Y" recommendations
    - Use plain language a designer can understand

22. **Add metadata:**
    - "Last updated: [date]" at the top
    - Note at the top: "This is a living document. Run `/design-audit` to regenerate."

**If the file already exists:** Update it in place, preserving the changelog section and adding a new entry.

**If the file doesn't exist:** Create it fresh.

23. **Commit and push changes:**
    - Pull latest changes: `git pull origin <current-branch>`
    - Stage the audit file
    - Commit with message: `"Update design audit: [brief summary of findings]"`
    - Push to current branch
