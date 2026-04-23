# Markdown Anchor Sync QA Checklist

This checklist is for validating anchor-based markdown editor/preview sync using the fixtures in:

- `docs/fixtures/markdown-anchor-sync/`

## Test setup

- Open any fixture `*.md` file.
- Enable markdown split mode (editor + preview).
- Start each run with the preview scrolled to the top.
- If there is any “sync driver” toggle (editor drives preview vs preview drives editor), validate both directions.

## Core acceptance

### Alignment quality

For each fixture, verify:

- [ ] When the editor caret is placed at the start of a block, the preview scrolls so the corresponding rendered block is at (or near) the top of the preview viewport.
- [ ] When the editor is scrolled so the viewport is centered inside a long block (especially `02-long-sections.md`), the preview lands in the corresponding block with similar within-block progress.
- [ ] The active block does not frequently “flip-flop” between adjacent anchors when the editor scroll position is near a boundary.

Suggested focus fixtures:

- `02-long-sections.md` (within-anchor progress)
- `01-headings.md` (dense headings)
- `09-mixed-content.md` (real-world transitions)

### Jitter and loop prevention

- [ ] Slow scroll in the editor: preview follows smoothly without visible oscillation (no repeated micro-adjustments).
- [ ] Fast scroll / page jumps in the editor (Page Down, scroll bar drag): preview converges quickly without overshooting and snapping back.
- [ ] If preview scrolling can also drive the editor, perform the same checks in reverse.

Suggested focus fixtures:

- `00-prose.md`
- `02-long-sections.md`
- `03-fenced-code.md`

### Relayout stability

While positioned mid-document (not near the top), trigger relayout events and verify the active anchor is preserved:

- [ ] Resize the window wider and narrower: preview remains aligned to the same logical block.
- [ ] Toggle anything that changes layout (sidebar, inspector, line wrap, theme, font size): preview does not “lose” its place.
- [ ] After relayout settles, there is no delayed jump to a different block.

Suggested focus fixtures:

- `07-tables.md` (wrapping changes row heights)
- `03-fenced-code.md` (code wrapping / horizontal scroll)
- `09-mixed-content.md`

## Async content acceptance

### Image behavior

- [ ] `05-images.md`: standalone image blocks are treated as their own anchors (scrolling should snap to the image block reliably).
- [ ] `06-large-image.md`: when the large image loads and the preview height changes, the preview does not jump to a different section.
- [ ] After image load completes, alignment recovers to the same anchor without requiring additional user scroll input.

### Mermaid behavior

- [ ] `04-mermaid.md`: when Mermaid renders after initial markdown parse, the preview preserves the active anchor.
- [ ] After Mermaid render completes, there is no visible drift (editor and preview still reference the same logical section).
- [ ] Re-render triggers (theme change, window resize) do not cause the preview to jump to unrelated content.

## Optional stress scenarios

- [ ] With `09-mixed-content.md`, continuously scroll for 10 to 20 seconds: verify no cumulative drift appears.
- [ ] Rapidly alternate between scrolling up and down across block boundaries: verify anchor selection is stable.
- [ ] Switch tabs away and back while mid-document: verify sync state restores without a jump.

## Reporting template

When filing issues, include:

- fixture file name
- direction (editor -> preview, preview -> editor)
- approximate anchor (heading text, or nearby content)
- reproduction steps
- what changed (scroll, resize, image load, Mermaid render)
- expected vs actual behavior

## Automated checks

- [x] `swift build` (2026-04-23)
- [x] `swift test` (2026-04-23)
