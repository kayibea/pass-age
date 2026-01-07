#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: pass age <pass-name>" >&2
  exit 1
fi

file="$1.gpg"
store="${PASSWORD_STORE_DIR:-$HOME/.password-store}"

cd "$store"
git rev-parse --is-inside-work-tree >/dev/null

decrypt_first_line() {
  "$GPG" "${GPG_OPTS[@]}" --decrypt 2>/dev/null | sed -n '1p' || true
}

get_password_hash() {
  decrypt_first_line |
    sha1sum |
    cut -d' ' -f1
}

head_hash="$(
  git show "HEAD:$file" 2>/dev/null |
    get_password_hash
)" || {
  echo "Error: $file does not exist at HEAD" >&2
  exit 1
}

last_change=""

while read -r commit; do
  hash="$(
    git show "$commit:$file" 2>/dev/null |
      get_password_hash
  )" ||
    continue

  if [[ "$hash" != "$head_hash" ]]; then
    last_change="$commit"
    break
  fi
done < <(git log --format=%H -- "$file")

# never changed → use first commit where file exists
if [[ -z "$last_change" ]]; then
  last_change="$(
    git log --format=%H --reverse -- "$file" | head -n1
  )"
fi

git show -s --format='%ct%x09%cr%x09'"${file%.*}" "$last_change"
