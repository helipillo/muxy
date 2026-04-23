# Mermaid Fixture

This document includes Mermaid blocks. Mermaid typically renders asynchronously which can cause preview relayout.

## Flowchart

```mermaid
graph TD
    A[Start] --> B{Decision}
    B -->|Yes| C[Do thing]
    B -->|No| D[Do other thing]
    C --> E[End]
    D --> E[End]
```

## Sequence

```mermaid
sequenceDiagram
    participant U as User
    participant E as Editor
    participant P as Preview
    U->>E: Scroll
    E->>P: Emit active anchor + progress
    P-->>E: Apply scroll
```

A paragraph after Mermaid.
