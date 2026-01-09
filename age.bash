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
  local out
  if ! out="$("$GPG" "${GPG_OPTS[@]}" --decrypt 2>/dev/null)"; then
    return 1
  fi

  sed -n '1p' <<<"$out" | tr -d '\n\r'
}

get_password_hash() {
  local password
  if ! password="$(decrypt_first_line)"; then
    return 1
  fi

  printf '%s' "$password" | sha1sum | cut -d' ' -f1
}

print_commit_info() {
  local commit=$1
  git show -s --format='%ct%x09%cr%x09'"${file%.*}" "$commit"
}

head_hash="$(
  git show "HEAD:$file" 2>/dev/null |
    get_password_hash
)" || {
  echo "Error: $file does not exist at HEAD or decryption failed" >&2
  exit 1
}

while read -r commit path; do
  hash="$(
    git show "$commit:$path" 2>/dev/null |
      get_password_hash
  )" || continue

  if [[ "$hash" != "$head_hash" ]]; then
    print_commit_info "$commit"
    exit 0
  fi
done < <(
  git log --follow --pretty=format:'%H' --name-status -- "$file" |
    awk '
    /^[0-9a-f]{40}$/ { commit=$0; next }
    /^[AMD]/ { print commit, $2 }
  '
)

first_commit="$(git log --follow --format='%H' -- "$file" | tail -n 1)"

print_commit_info "$first_commit"
