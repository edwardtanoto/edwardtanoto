#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

env_file="/Users/edwardtanoto/Documents/edtnxyz/.env"

load_profile_card_token() {
  if [[ -n "${PROFILE_CARD_TOKEN:-}" ]]; then
    return
  fi

  if [[ ! -f "$env_file" ]]; then
    return
  fi

  local line token
  line="$(grep -E '^(export[[:space:]]+)?PROFILE_CARD_TOKEN=' "$env_file" | tail -n 1 || true)"
  if [[ -z "$line" ]]; then
    return
  fi

  token="$(printf '%s' "$line" | sed -E 's/^export[[:space:]]+//')"
  token="${token#PROFILE_CARD_TOKEN=}"
  token="${token%\"}"
  token="${token#\"}"
  token="${token%\'}"
  token="${token#\'}"
  export PROFILE_CARD_TOKEN="$token"
}

if [[ -n "$(git status --porcelain)" ]]; then
  echo "Working tree has uncommitted changes; refusing to refresh profile card."
  exit 1
fi

git fetch origin main
git merge --ff-only origin/main

load_profile_card_token

if [[ -z "${PROFILE_CARD_TOKEN:-}" ]]; then
  echo "PROFILE_CARD_TOKEN is not set. Add it to the environment or $env_file."
  exit 1
fi

mkdir -p assets
tmp_file="$(mktemp)"
trap 'rm -f "$tmp_file"' EXIT

curl --fail --silent --show-error --location \
  --header "Authorization: Bearer ${PROFILE_CARD_TOKEN}" \
  --output "$tmp_file" \
  "https://www.edtn.xyz/api/profile-card.svg"

if ! grep -q "<svg" "$tmp_file"; then
  echo "Downloaded profile card did not look like SVG."
  exit 1
fi

mv "$tmp_file" assets/profile-card.svg

if git diff --quiet -- assets/profile-card.svg; then
  echo "Profile card is already current."
  exit 0
fi

git add assets/profile-card.svg
git commit -m "Update live profile card"
git push origin main
