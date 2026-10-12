#!/usr/bin/env bash
# Bump -bin packages in this overlay to their latest upstream GitHub release.
#
#   scripts/bump.sh                      bump every package that has a bump.conf
#   scripts/bump.sh app-misc/jan-bin     bump one package
#   VERSION=1.2.3 scripts/bump.sh <pkg>  pin a version instead of asking GitHub
#
# Each package directory needs:
#   <pn>-9999.ebuild.template   copied to <pn>-<ver>.ebuild (@PV@ -> version)
#   bump.conf                   sourced bash, see below
#
# bump.conf variables:
#   UPSTREAM="owner/repo"       GitHub repo to watch
#   TAG_PREFIX="v"              stripped from the release tag (default: v)
#   ASSETS=(                    one entry per distfile: "<distfile> <asset>"
#     "foo-bin-@PV@.deb Foo_@PV@_amd64.deb"
#   )                           @PV@ is replaced with the version in both
#
# The Manifest is generated with coreutils (no portage needed) and covers only
# the new version, so older ebuilds are removed on every bump.
set -euo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT}"

list_packages() {
	find . -mindepth 3 -maxdepth 3 -name bump.conf -printf '%h\n' \
		| sed 's|^\./||' | sort
}

bump_one() (
	local pkg="${1%/}" pn pkgdir conf template latest ebuild tmp entry
	pn="${pkg#*/}"
	pkgdir="${ROOT}/${pkg}"
	conf="${pkgdir}/bump.conf"
	template="${pkgdir}/${pn}-9999.ebuild.template"

	[[ -f "${conf}" ]] || { echo "${pkg}: no bump.conf" >&2; return 1; }
	[[ -f "${template}" ]] || { echo "${pkg}: no ${pn}-9999.ebuild.template" >&2; return 1; }

	UPSTREAM="" TAG_PREFIX="v" ASSETS=()
	# shellcheck source=/dev/null
	source "${conf}"
	[[ -n "${UPSTREAM}" && ${#ASSETS[@]} -gt 0 ]] \
		|| { echo "${pkg}: bump.conf needs UPSTREAM and ASSETS" >&2; return 1; }

	latest="${VERSION:-}"
	if [[ -z "${latest}" ]]; then
		local auth=() response tag
		[[ -n "${GITHUB_TOKEN:-}" ]] && auth=(-H "Authorization: Bearer ${GITHUB_TOKEN}")
		# Capture the whole response first: piping curl straight into grep -m1
		# closes the pipe early and curl dies with error 23.
		response=$(curl -fsSL "${auth[@]}" "https://api.github.com/repos/${UPSTREAM}/releases/latest")
		tag=$(printf '%s\n' "${response}" | grep -m1 '"tag_name"' | sed -E 's/.*"tag_name": *"([^"]+)".*/\1/')
		latest="${tag#"${TAG_PREFIX}"}"
	fi
	[[ -n "${latest}" ]] || { echo "${pkg}: could not determine latest version" >&2; return 1; }

	ebuild="${pkgdir}/${pn}-${latest}.ebuild"
	if [[ -f "${ebuild}" ]]; then
		echo "${pkg}: already at ${latest}"
		return 0
	fi
	echo "${pkg}: bumping to ${latest}"

	tmp=$(mktemp -d)
	trap 'rm -rf "${tmp}"' EXIT

	: > "${tmp}/Manifest"
	for entry in "${ASSETS[@]}"; do
		local distfile asset size
		read -r distfile asset <<< "${entry//@PV@/${latest}}"
		curl -fsSL -o "${tmp}/${distfile}" \
			"https://github.com/${UPSTREAM}/releases/download/${TAG_PREFIX}${latest}/${asset}"
		size=$(stat -c %s "${tmp}/${distfile}")
		echo "DIST ${distfile} ${size}" \
			"BLAKE2B $(b2sum "${tmp}/${distfile}" | cut -d' ' -f1)" \
			"SHA512 $(sha512sum "${tmp}/${distfile}" | cut -d' ' -f1)" \
			>> "${tmp}/Manifest"
		rm -f "${tmp}/${distfile}"   # don't keep a 1 GB .deb around
	done

	find "${pkgdir}" -maxdepth 1 -name "${pn}-[0-9]*.ebuild" -delete
	sed "s/@PV@/${latest}/g" "${template}" > "${ebuild}"
	sort "${tmp}/Manifest" > "${pkgdir}/Manifest"
	echo "${pkg}: wrote ${pn}-${latest}.ebuild and Manifest"
)

if [[ $# -eq 0 ]]; then
	mapfile -t pkgs < <(list_packages)
else
	pkgs=("$@")
fi

status=0
for pkg in "${pkgs[@]}"; do
	bump_one "${pkg}" || status=1   # one failure doesn't stop the others
done
exit "${status}"
