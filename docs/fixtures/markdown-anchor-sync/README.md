# Markdown Anchor Sync Fixtures

These fixtures are intended for manual QA of anchor-based markdown editor/preview sync.

Open any `*.md` file in Muxy and enable split markdown mode (editor + preview). Use them to validate:

- anchor alignment quality (editor viewport vs preview viewport)
- scroll jitter and loop prevention
- stability across relayout (resize window, toggle sidebar, font size)
- image and Mermaid async layout changes

## Fixture index

- `00-prose.md`: plain prose blocks
- `01-headings.md`: dense heading hierarchy
- `02-long-sections.md`: long single-paragraph anchors + long sections
- `03-fenced-code.md`: fenced code blocks (short and long, multiple fence markers)
- `04-mermaid.md`: Mermaid diagrams that render after initial markdown load
- `05-images.md`: standalone images and images surrounded by text
- `06-large-image.md`: large image that should cause relayout after decode
- `07-tables.md`: tables with alignment and wide cells
- `08-nested-lists.md`: deeply nested lists and mixed list content
- `09-mixed-content.md`: real-world mixed document

Images live in `./images/`.
