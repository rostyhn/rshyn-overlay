#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" > /dev/null 2>&1 && pwd)"
REPO_ROOT="$(dirname -- "${SCRIPT_DIR}")"
PKGDIR="${REPO_ROOT}/app-misc/jan-bin"
TEMPLATE="${PKGDIR}/jan-bin-9999.ebuild.template"  # keep a stable template, see below

response=$(curl -fsSL https://api.github.com/repos/janhq/jan/releases/latest)
latest_tag=$(printf '%s' "${response}" | grep -m1 '"tag_name"' | sed -E 's/.*"v([^"]+)".*/\1/')

if [[ -z "$latest_tag" ]]; then
  echo "ERROR: failed to determine latest tag" >&2
  exit 1
fi

ebuild_path="${PKGDIR}/jan-bin-${latest_tag}.ebuild"

if [[ -f "${ebuild_path}" ]]; then
  echo "Already at ${latest_tag}, nothing to do."
  exit 0
fi

# Render the template with the new version
sed "s/@PV@/${latest_tag}/g" "${TEMPLATE}" > "${ebuild_path}"

# Pull the asset once so we can hash it for the Manifest
asset_url="https://github.com/janhq/jan/releases/download/v${latest_tag}/Jan_${latest_tag}_amd64.deb"
distfile="jan-bin-${latest_tag}.deb"
curl -fsSL -o "/tmp/${distfile}" "${asset_url}"

size=$(stat -c%s "/tmp/${distfile}")
blake2b=$(b2sum -l 512 "/tmp/${distfile}" | cut -d' ' -f1)
sha512=$(sha512sum "/tmp/${distfile}" | cut -d' ' -f1)

cat > "${PKGDIR}/Manifest" <<EOF
DIST ${distfile} ${size} BLAKE2B ${blake2b} SHA512 ${sha512}
EOF

git add "${ebuild_path}" "${PKGDIR}/Manifest"
