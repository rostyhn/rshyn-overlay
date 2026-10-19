EAPI=8

inherit desktop xdg

DESCRIPTION="Client for running LLMs locally"
HOMEPAGE="https://jan.ai https://github.com/janhq/jan"
SRC_URI="https://github.com/janhq/jan/releases/download/v0.8.6/Jan_0.8.6_amd64.deb -> ${P}.deb"

LICENSE="Apache-2.0"
SLOT="0"
KEYWORDS="-* ~amd64"
IUSE="bun uv"
RESTRICT="mirror strip bindist test"

RDEPEND="
	dev-libs/glib:2
	dev-libs/openssl:0=
	dev-libs/libffi:=
	dev-libs/fribidi
	media-libs/fontconfig
	media-libs/libepoxy
	media-libs/libpng:0=
	net-libs/libsoup:3.0
	net-libs/webkit-gtk:4.1
	sys-apps/dbus
	x11-libs/cairo
	x11-libs/gdk-pixbuf:2
	x11-libs/gtk+:3
	x11-libs/pango
    	dev-libs/libayatana-appindicator
	|| ( sys-apps/systemd sys-apps/systemd-utils )
	bun? ( dev-lang/bun )
	uv? ( dev-python/uv )
"

QA_PREBUILT="usr/bin/Jan-Desktop"

S="${WORKDIR}"

src_unpack() {
	mkdir -p "${WORKDIR}"/deb-extract || die
	pushd "${WORKDIR}"/deb-extract >/dev/null || die
	ar x "${DISTDIR}/${P}.deb" || die
	tar -xf data.tar.* || die
	popd >/dev/null || die
}

src_install() {
	local SRCDIR="${WORKDIR}/deb-extract"

	exeinto /usr/bin
	doexe "${SRCDIR}"/usr/bin/Jan-Desktop
	dosym Jan /usr/bin/jan

	# resources dir must stay named exactly "Jan" next to the binary --
	# Tauri resolves it relative to the executable name
	insinto /usr/lib/Jan/resources
	doins "${SRCDIR}"/usr/lib/Jan/resources/LICENSE
	exeinto /usr/lib/Jan/resources/bin

	domenu "${SRCDIR}"/usr/share/applications/Jan.desktop

	insinto /usr/share/icons/hicolor/32x32/apps
	doins "${SRCDIR}"/usr/share/icons/hicolor/32x32/apps/Jan-Desktop.png
	insinto /usr/share/icons/hicolor/128x128/apps
	doins "${SRCDIR}"/usr/share/icons/hicolor/128x128/apps/Jan-Desktop.png
	insinto /usr/share/icons/hicolor/256x256@2/apps
	doins "${SRCDIR}"/usr/share/icons/hicolor/256x256@2/apps/Jan-Desktop.png

	dodoc "${SRCDIR}"/usr/lib/Jan/resources/LICENSE
}

pkg_postinst() {
	if ! use bun; then
		elog "Jan's MCP server uses 'bun' to run JS-based MCP servers."
		elog "Jan comes bundled with it, but it was dropped in order to avoid"
		elog "conflicts with existing installations. Emerge with USE=\"bun\" to pull in dev-lang/bun."
	fi
	if ! use uv; then
		elog "Jan's MCP server uses 'uv' to run Python-based MCP servers."
		elog "Python-based MCP servers. Jan comes bundled with it, but it was"
		elog "dropped in order to avoid conflicts with existing installations."
		elog "Emerge with USE=\"uv\" to pull in dev-python/uv."
	fi
}
