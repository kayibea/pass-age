#!/usr/bin/env bash
set -euo pipefail

if [[ $# -gt 1 ]]; then
  echo "Usage: pass ages [subfolder]" >&2
  exit 1
fi

folder="${1:-.}"
store="${PASSWORD_STORE_DIR:-$HOME/.password-store}"

cd "$store"

if [[ ! -d "$folder" ]]; then
  echo "Error: folder '$folder' does not exist in store '$store'" >&2
  exit 1
fi

while IFS= read -r -d '' file; do
  file="${file#./}"
  file="${file%.gpg}"
  pass age "$file"
done < <(
  find "$folder" -type f -name '*.gpg' -not -path '*/.*' -print0 |
    sort -z
)
