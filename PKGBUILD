# Maintainer: N0t4R0b0t
# linux-atom — a CPU-tuned, slimmed kernel for the Acer Aspire One (Atom N270, i686).
#
# Co-installable with the stock `linux` kernel: distinct pkgbase and
# CONFIG_LOCALVERSION="-atom", so it lands as its own vmlinuz-linux-atom + modules
# dir and Arch's mkinitcpio install hooks generate initramfs-linux-atom.img. Keep the
# stock kernel as the default boot entry until you trust this one.
#
# Pinned to 6.19.11 to match ./config (the machine's own running config, retuned to
# Processor family = Atom). Build it in an i686 chroot (the pkgmirror `atom` chroot is
# ideal). Vanilla kernel.org tree — mainline supports i686 fully; reconcile
# archlinux32's i686 patchset here if you hit anything (see README.md).

pkgbase=linux-atom
pkgname=("$pkgbase")
pkgver=6.19.11
pkgrel=4
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
  linux-atom-syslinux.hook
  linux-atom-syslinux-update
)
sha256sums=('20039d7b6b256c08be2f8fac43c3ff9a620308c703c643cf2f80c3910b9bd59b'
            'SKIP'
            'SKIP'
            'SKIP'
            'SKIP')

prepare() {
  cd $_srcname
  echo "Setting config..."
  cp ../config .config
  # Tune processor family -> Atom, distinct localversion, then normalize.
  scripts/config --disable CONFIG_M686 --disable CONFIG_X86_GENERIC \
                 --enable  CONFIG_MATOM \
                 --set-str CONFIG_LOCALVERSION "-atom"
  # Slim to only the modules this machine loads (aggressive; see README). On by
  # default -- an unslimmed build is only useful for local testing outside
  # pkgmirror (which has no reliable way to pass a custom env var like SLIM
  # through makechrootpkg's fixed --preserve-env allowlist), so build it with
  # `SLIM=0 makepkg -s` locally if you need the full config for comparison.
  if [ "${SLIM:-1}" != "0" ]; then
    make LSMOD="$srcdir/lsmod.atom" localmodconfig
  fi
  make olddefconfig
  make -s kernelrelease > version
  echo "Prepared $pkgbase version $(<version)"
}

build() {
  cd $_srcname
  make all
}

package() {
  pkgdesc="CPU-tuned (Atom), slimmed Linux kernel for the Aspire One"
  depends=('coreutils' 'initramfs' 'kmod')
  optdepends=('linux-firmware: firmware images for some devices'
              'wireless-regdb: correct wireless channels for your country')

  cd $_srcname
  local kernver="$(<version)"
  local modulesdir="$pkgdir/usr/lib/modules/$kernver"

  echo "Installing boot image..."
  # 'install' triggers the mkinitcpio pacman hooks, which read pkgbase for the name.
  install -Dm644 "$(make -s image_name)" "$modulesdir/vmlinuz"
  echo "$pkgbase" | install -Dm644 /dev/stdin "$modulesdir/pkgbase"

  echo "Installing modules..."
  ZSTD_CLEVEL=19 make INSTALL_MOD_PATH="$pkgdir/usr" INSTALL_MOD_STRIP=1 \
    DEPMOD=/doesnt/exist modules_install
  rm -f "$modulesdir"/{source,build}

  echo "Installing syslinux boot-entry hook..."
  # syslinux (unlike GRUB/systemd-boot) never auto-registers a new kernel;
  # this hook adds a LABEL stanza on install/upgrade so the tuned kernel is
  # actually selectable after a plain `pacman -S`/`-Syu`, not just installed.
  install -Dm644 "$srcdir/linux-atom-syslinux.hook" \
    "$pkgdir/usr/share/libalpm/hooks/91-linux-atom-syslinux.hook"
  install -Dm755 "$srcdir/linux-atom-syslinux-update" \
    "$pkgdir/usr/share/libalpm/scripts/linux-atom-syslinux-update"
}
