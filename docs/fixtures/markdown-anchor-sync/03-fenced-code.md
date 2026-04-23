# Fenced Code Fixture

## Short fenced code

```swift
struct Point {
    let x: Int
    let y: Int
}
```

## Long fenced code

```bash
set -euo pipefail

echo "Begin"
for i in $(seq 1 80); do
  printf "line %02d\n" "$i"
done
echo "End"
```

## Tilde fence

~~~json
{
  "enabled": true,
  "threshold": 0.42,
  "items": [1, 2, 3],
  "note": "Fence marker is ~~~"
}
~~~

## Fence containing backticks

```text
Here is a literal sequence: ``` inside code.
And another: ``.
```
