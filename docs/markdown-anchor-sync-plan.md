# Markdown Anchor Sync Plan

## Branch

- Working branch: `feat/markdown-anchor-sync-plan`
- Base branch for the eventual PR: `upstream/main`

## Goal

Replace the current percent-based markdown split scrolling with anchor-based structural sync that is stable with images, Mermaid, code blocks, and async layout changes.

## Problem Summary

The current sync model compares editor scroll and preview scroll geometrically. That causes:

- jitter and visible re-adjustment while scrolling
- drift between editor and preview
- bad behavior when images or Mermaid reflow after initial render
- poor production quality in split markdown mode

## Target Architecture

Introduce a structural sync pipeline:

1. Parse source markdown into block anchors
2. Render preview blocks with stable source metadata
3. Measure preview block geometry after render and relayout
4. Map editor viewport to nearest source anchor
5. Sync editor and preview using anchor IDs plus local progress within the anchor
6. Preserve the active anchor during async layout changes

## Shared Contracts

### MarkdownSyncAnchor

Represents a block-level source anchor.

Suggested fields:

- `id: String`
- `kind: MarkdownSyncAnchorKind`
- `startLine: Int`
- `endLine: Int`

Suggested kinds:

- heading
- paragraph
- list
- blockquote
- fencedCode
- table
- thematicBreak
- image
- mermaid
- htmlBlock
- other

### Preview Anchor DOM Contract

Every rendered preview block participating in sync should have:

- `data-muxy-anchor-id`
- `data-muxy-line-start`
- `data-muxy-line-end`

### Preview Geometry Contract

The preview bridge should be able to report an ordered list with:

- `anchorID`
- `startLine`
- `endLine`
- `top`
- `height`

### Editor Sync Contract

The editor side should emit:

- `activeAnchorID`
- `localProgress`

Where `localProgress` is `0...1` within the anchor line span.

## Workstreams

### Workstream A: Source Anchors

Owner profile:
- parser and model focused

Scope:
- create `MarkdownSyncAnchor`
- create `MarkdownAnchorParser`
- parse block-level source anchors from raw markdown
- add robust tests

Files likely involved:
- `Muxy/Models/MarkdownSyncAnchor.swift`
- `Muxy/Models/MarkdownAnchorParser.swift`
- `Tests/MuxyTests/Models/MarkdownAnchorParserTests.swift`

Acceptance:
- correct line ranges for headings, paragraphs, lists, fenced code, Mermaid, tables, images, blockquotes
- no UI changes yet

### Workstream B: Preview DOM Anchors

Owner profile:
- markdown renderer and web rendering focused

Scope:
- inject block wrappers or metadata into rendered preview output
- ensure Mermaid/image/code/table blocks have stable wrappers
- decide whether to use marked renderer hooks or post-render DOM wrapping

Files likely involved:
- `Muxy/Models/MarkdownRenderer.swift`
- `Muxy/Views/Markdown/MarkdownTabView.swift`

Acceptance:
- preview DOM exposes stable source metadata for all major block types
- Mermaid still renders correctly
- images still render correctly

### Workstream C: Preview Geometry Measurement

Owner profile:
- WebKit and JS bridge focused

Scope:
- measure anchor geometry in the preview
- remeasure after image load, Mermaid render, resize, and relayout
- bridge geometry data back to Swift
- preserve active anchor during layout changes where possible

Files likely involved:
- `Muxy/Views/Markdown/MarkdownTabView.swift`

Acceptance:
- geometry snapshots are stable and ordered
- image load and Mermaid render do not cause arbitrary position loss

### Workstream D: Editor Anchor Mapping

Owner profile:
- editor viewport and state focused

Scope:
- map editor viewport to visible source anchor
- compute local progress within an anchor
- expose editor anchor sync state cleanly

Files likely involved:
- `Muxy/Views/Editor/CodeEditorRepresentable.swift`
- `Muxy/Models/EditorTabState.swift`
- possibly new dedicated sync state file

Acceptance:
- editor can identify nearest active anchor reliably from viewport position
- no preview changes required yet

### Workstream E: Sync Coordinator

Owner profile:
- architecture and integration focused

Scope:
- create a coordinator that owns sync policy
- replace current percent-based sync flow with anchor-based flow
- handle driver ownership and loop prevention
- integrate editor -> preview and preview -> editor sync

Files likely involved:
- new coordinator file, for example `Muxy/Models/MarkdownSyncCoordinator.swift`
- integration points in editor and web view layers

Acceptance:
- no jitter loops
- predictable split scroll behavior
- graceful behavior during async relayout

### Workstream F: Fixtures and QA

Owner profile:
- testing and validation focused

Scope:
- create markdown fixtures covering real-world cases
- define acceptance checklist
- validate jitter, drift, async layout stability, and Mermaid/image behavior

Suggested fixtures:
- plain prose
- headings and long sections
- standalone images
- large images
- Mermaid diagrams
- long fenced code blocks
- tables
- nested lists
- mixed-content document

Acceptance:
- documented validation checklist exists before merge

## Dependency Order

- A can start immediately
- F can start immediately
- B can start in parallel with A, but should align with A contract
- C depends on B DOM metadata
- D depends on A source anchors
- E depends on A, C, and D

## Merge Risk Hotspots

These files are likely to conflict if multiple people touch them directly:

- `Muxy/Models/MarkdownRenderer.swift`
- `Muxy/Views/Markdown/MarkdownTabView.swift`
- `Muxy/Views/Editor/CodeEditorRepresentable.swift`
- `Muxy/Models/EditorTabState.swift`

Prefer adding new files first and integrating late.

## Recommended Session Orchestration

### Session 1
Focus on Workstream A.

### Session 2
Focus on Workstream B.

### Session 3
Focus on Workstream C.

### Session 4
Focus on Workstream D.

### Session 5
Focus on Workstream E after A, C, and D stabilize.

### Session 6
Focus on Workstream F.

## Instructions For Every Session

1. Read `AGENTS.md`
2. Read this file: `docs/markdown-anchor-sync-plan.md`
3. Stay on branch `feat/markdown-anchor-sync-plan` unless explicitly told otherwise
4. Do not broaden scope beyond your workstream
5. Avoid editing hotspot files unless your workstream explicitly owns them
6. Keep maintainability and build-size impact in mind
7. Build and run tests before claiming completion
8. If you discover unrelated issues, report them separately and do not fold them into the implementation

## Copy-Paste Prompt Templates

### Prompt for Workstream A

You are working on Workstream A from `docs/markdown-anchor-sync-plan.md`.
Read `AGENTS.md` and `docs/markdown-anchor-sync-plan.md` first.
Stay on branch `feat/markdown-anchor-sync-plan`.
Implement the source anchor model and parser only.
Do not modify markdown web rendering or sync behavior yet.
Add tests covering headings, paragraphs, lists, fenced code, Mermaid, images, tables, and blockquotes.
Build and test before finishing.

### Prompt for Workstream B

You are working on Workstream B from `docs/markdown-anchor-sync-plan.md`.
Read `AGENTS.md` and `docs/markdown-anchor-sync-plan.md` first.
Stay on branch `feat/markdown-anchor-sync-plan`.
Implement preview DOM anchor metadata for rendered markdown blocks.
Ensure Mermaid and images still render correctly.
Do not implement final sync behavior yet.
Build and test before finishing.

### Prompt for Workstream C

You are working on Workstream C from `docs/markdown-anchor-sync-plan.md`.
Read `AGENTS.md` and `docs/markdown-anchor-sync-plan.md` first.
Stay on branch `feat/markdown-anchor-sync-plan`.
Implement preview geometry measurement and relayout handling for markdown anchors.
Focus on image load, Mermaid render, resize, and stable geometry export.
Do not redesign source parsing.
Build and test before finishing.

### Prompt for Workstream D

You are working on Workstream D from `docs/markdown-anchor-sync-plan.md`.
Read `AGENTS.md` and `docs/markdown-anchor-sync-plan.md` first.
Stay on branch `feat/markdown-anchor-sync-plan`.
Implement editor viewport to source-anchor mapping and local progress calculation.
Do not implement preview DOM logic.
Build and test before finishing.

### Prompt for Workstream E

You are working on Workstream E from `docs/markdown-anchor-sync-plan.md`.
Read `AGENTS.md` and `docs/markdown-anchor-sync-plan.md` first.
Stay on branch `feat/markdown-anchor-sync-plan`.
Implement the integration coordinator for anchor-based markdown sync.
Assume source anchors, editor mapping, and preview geometry are available or stub them cleanly.
Prioritize loop prevention, stability, and maintainability.
Build and test before finishing.

### Prompt for Workstream F

You are working on Workstream F from `docs/markdown-anchor-sync-plan.md`.
Read `AGENTS.md` and `docs/markdown-anchor-sync-plan.md` first.
Stay on branch `feat/markdown-anchor-sync-plan`.
Create markdown fixtures and a QA checklist for anchor-based sync validation.
Do not broaden into implementation unless needed for tests and fixtures.
Build and test any added validation helpers before finishing.

## Integration Notes

When converging workstreams:
- merge A before D and E
- merge B before C and E
- merge D and C before the final E integration
- run a full build and full tests after every merge wave
- do a dedicated manual QA pass after E
