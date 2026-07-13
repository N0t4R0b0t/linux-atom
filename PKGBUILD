# Maintainer: N0t4R0b0t
# linux-atom — a CPU-tuned, slimmed kernel for the Acer Aspire One (Atom N270, i686).
#
# Co-installable with the stock `linux` kernel: pkgbase is renamed and
# CONFIG_LOCALVERSION="-atom", so it lands as its own /boot/vmlinuz-linux-atom and
# /usr/lib/modules/<ver>-atom. Add a separate boot entry and keep the stock kernel
# as a fallback until you trust it.
#
# The config (./config) is the machine's own running config with:
#   * Processor family = Atom  (CONFIG_MATOM, replacing the generic CONFIG_M686 /
#     X86_GENERIC) — scheduling/alignment tuned for in-order Bonnell.
#   * optional slimming via `make localmodconfig` against ./lsmod.atom (set SLIM=1)
#     — keeps only the modules the machine actually loads (much smaller, faster boot,
#     less RAM on a 1.4 GB box). See README.md for the trade-offs.
#
# NOTE: this template builds a vanilla kernel.org tree. For an archlinux32 machine you
# will likely want to reconcile archlinux32's i686 linux patchset (their `linux`
# package) on top — see README.md. Build it in the pkgmirror i686 chroot.

pkgbase=linux-atom
pkgver=6.19.11
pkgrel=1
_srcname=linux-${pkgver}
arch=('i686')
url="https://www.kernel.org/"
license=('GPL-2.0-only')
makedepends=('bc' 'cpio' 'gettext' 'libelf' 'pahole' 'perl' 'python' 'tar' 'xz')
options=('!strip')
source=(
  "https://cdn.kernel.org/pub/linux/kernel/v6.x/${_srcname}.tar.xz"
  config
  lsmod.atom
)
# Fill in real checksums once the tarball version is pinned (updpkgsums).
sha256sums=('SKIP' 'SKIP' 'SKIP')

export KBUILD_BUILD_HOST=archlinux
export KBUILD_BUILD_USER=$pkgbase
export KBUILD_BUILD_TIMESTAMP="$(date -Ru${SOURCE_DATE_EPOCH:+d @$SOURCE_DATE_EPOCH})"

prepare() {
  cd $_srcname
  echo "Setting config..."
  cp ../config .config

  # Tune the processor family and normalize the config.
  scripts/config --disable CONFIG_M686 --disable CONFIG_X86_GENERIC \
                 --enable  CONFIG_MATOM \
                 --set-str CONFIG_LOCALVERSION "-atom"

  # Optional: slim to only the modules this machine loads (SLIM=1). Aggressive —
  # anything not loaded at capture time is dropped; review before trusting.
  if [ "${SLIM:-0}" = "1" ]; then
    echo "Slimming with localmodconfig (from ../lsmod.atom)..."
    make LSMOD="../lsmod.atom" localmodconfig
  fi

  make olddefconfig
  make -s kernelrelease > version
  echo "Prepared $pkgbase version $(<version)"
}

build() {
  cd $_srcname
  make all
}

_package() {
  pkgdesc="CPU-tuned (Atom) slimmed Linux kernel for the Aspire One"
  depends=('coreutils' 'initramfs' 'kmod')
  optdepends=('wireless-regdb: to set the correct wireless channels of your country'
              'linux-firmware: firmware images needed for some devices')
  provides=(KSMBD-MODULE VIRTUALBOX-GUEST-MODULES WIREGUARD-MODULE)
  replaces=(virtualbox-guest-modules-arch wireguard-arch)

  cd $_srcname
  local kernver="$(<version)"
  local modulesdir="$pkgdir/usr/lib/modules/$kernver"

  echo "Installing boot image..."
  install -Dm644 "$(make -s image_name)" "$modulesdir/vmlinuz"
  echo "$pkgbase" | install -Dm644 /dev/stdin "$modulesdir/pkgbase"

  echo "Installing modules..."
  ZSTD_CLEVEL=19 make INSTALL_MOD_PATH="$pkgdir/usr" INSTALL_MOD_STRIP=1 \
    DEPMOD=/doesnt/exist modules_install
  rm -f "$modulesdir"/{source,build}
}

pkgname=("$pkgbase")
package_linux-atom() { _package; }
