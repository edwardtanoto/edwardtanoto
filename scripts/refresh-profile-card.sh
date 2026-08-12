#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

env_file="/Users/edwardtanoto/Documents/edtnxyz/.env"
site_root="/Users/edwardtanoto/Documents/edtnxyz"

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

render_from_local_site() {
  if [[ ! -d "$site_root" ]]; then
    echo "Local site repo is missing at $site_root."
    return 1
  fi

  (
    cd "$site_root"
    set -a
    if [[ -f .env ]]; then
      source .env
    fi
    set +a
    npx tsx -e 'import { GET } from "./src/app/api/profile-card.svg/route"; void (async () => { const headers = new Headers(); if (process.env.PROFILE_CARD_TOKEN) headers.set("authorization", `Bearer ${process.env.PROFILE_CARD_TOKEN}`); const res = await GET(new Request("http://local/profile-card.svg", { headers })); if (!res.ok) throw new Error(`render failed ${res.status}`); process.stdout.write(await res.text()); })();'
  )
}

if [[ -n "$(git status --porcelain)" ]]; then
  echo "Working tree has uncommitted changes; refusing to refresh profile card."
  exit 1
fi

git fetch origin main
git merge --ff-only origin/main

mkdir -p assets
tmp_file="$(mktemp)"
trap 'rm -f "$tmp_file"' EXIT

load_profile_card_token

if [[ -n "${PROFILE_CARD_TOKEN:-}" ]]; then
  curl --fail --silent --show-error --location \
    --header "Authorization: Bearer ${PROFILE_CARD_TOKEN}" \
    --output "$tmp_file" \
    "https://www.edtn.xyz/api/profile-card.svg"
else
  render_from_local_site > "$tmp_file"
fi

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
