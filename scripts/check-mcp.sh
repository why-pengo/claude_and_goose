#!/usr/bin/env bash
# Check if github-mcp-server is installed and print its version.
#
# Usage:
#   ./scripts/check-mcp.sh              # standard path check
  OLLAMA_HOST=http://other.local:11434 ./scripts/check-ollama.sh
set -euo pipefail
  
if ! command -v github-mcp-server >/dev/null; then
  echo "Error: github-mcp-server not found on PATH" >&2
ex  t 1
fi
  
github-mcp-server --version
