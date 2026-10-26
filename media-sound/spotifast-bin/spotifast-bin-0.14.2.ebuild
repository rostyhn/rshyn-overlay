# Copyright 2026 Rosty
# Distributed under the terms of the MIT License

EAPI=8

inherit desktop xdg

DESCRIPTION="Native, lightweight Spotify client written in Rust (egui + librespot)"
HOMEPAGE="https://spotifast.rocks https://github.com/crmne/spotifast"
SRC_URI="
	amd64? ( https://github.com/crmne/spotifast/releases/download/v${PV}/spotifast-${PV}-x86_64.AppImage -> ${P}-x86_64.AppImage )
	arm64? ( https://github.com/crmne/spotifast/releases/download/v${PV}/spotifast-${PV}-aarch64.AppImage -> ${P}-aarch64.AppImage )
"
S="${WORKDIR}/squashfs-root"

LICENSE="MIT"
SLOT="0"
KEYWORDS="-* ~amd64 ~arm64"
IUSE="+X wayland"
REQUIRED_USE="|| ( X wayland )"
RESTRICT="strip mirror"

# Linked (ELF NEEDED): alsa-lib, libpulse, libstdc++/libgcc_s, glibc.
# Everything else is dlopen()ed by winit/glutin/MPRIS at runtime, so ELF
# scanning won't find it -- it has to be listed here explicitly.
# libpulse works fine against pipewire-pulse.
RDEPEND="
	>=sys-libs/glibc-2.39
	media-libs/alsa-lib
	media-libs/libpulse
	media-libs/libglvnd
	sys-apps/dbus
	x11-libs/libxkbcommon
	X? (
		x11-libs/libX11
		x11-libs/libXcursor
		x11-libs/libXi
		x11-libs/libXrender
		x11-libs/libxkbcommon[X]
	)
	wayland? ( dev-libs/wayland )
"
BDEPEND="sys-fs/squashfs-tools[zstd]"

QA_PREBUILT="usr/bin/spotifast"

src_unpack() {
	local appimage
	use amd64 && appimage="${P}-x86_64.AppImage"
	use arm64 && appimage="${P}-aarch64.AppImage"

	# The AppImage is an ELF runtime with a squashfs appended. The squashfs
	# starts right after the ELF section header table:
	#   offset = e_shoff + e_shentsize * e_shnum
	# Extracting this way avoids executing the downloaded binary in the sandbox.
	local f="${DISTDIR}/${appimage}" shoff shentsize shnum
	shoff=$(od -An -t u8 -j 40 -N 8 "${f}" | tr -d ' ') || die
	shentsize=$(od -An -t u2 -j 58 -N 2 "${f}" | tr -d ' ') || die
	shnum=$(od -An -t u2 -j 60 -N 2 "${f}" | tr -d ' ') || die

	unsquashfs -q -n -o $(( shoff + shentsize * shnum )) \
		-d "${S}" "${f}" || die "unsquashfs failed"
}

src_install() {
	dobin usr/bin/spotifast

	domenu usr/share/applications/spotifast.desktop
	doicon -s scalable usr/share/icons/hicolor/scalable/apps/spotifast.svg

	dodoc usr/share/doc/spotifast/README.md
}
