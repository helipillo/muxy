#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
OPENUSAGE_REPO="robinebers/openusage"
ICONS_DIR="$PROJECT_ROOT/Muxy/Resources/ProviderIcons"

mkdir -p "$ICONS_DIR"

PROVIDERS="amp antigravity claude codex copilot cursor factory gemini jetbrains-ai-assistant kimi kiro minimax opencode-go windsurf zai perplexity"

echo "==> Downloading provider icons from OpenUsage"
for provider in $PROVIDERS; do
    icon_url="https://raw.githubusercontent.com/$OPENUSAGE_REPO/main/plugins/$provider/icon.svg"
    output_file="$ICONS_DIR/${provider}.svg"

    echo "    Downloading $provider icon..."
    if curl -sfL "$icon_url" -o "$output_file" 2>/dev/null; then
        echo "        OK: $output_file"
    else
        echo "        SKIP: No icon found for $provider"
        rm -f "$output_file"
    fi
done

echo "==> Done. Icons downloaded to $ICONS_DIR"
ls -la "$ICONS_DIR/"