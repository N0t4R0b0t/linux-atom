# Maintainer: N0t4R0b0t
# linux-atom7 — the 7.x-series branch of linux-atom: a CPU-tuned, slimmed kernel for the Acer Aspire One (Atom N270, i686).
#
# Co-installable with the stock `linux` kernel: distinct pkgbase and
# CONFIG_LOCALVERSION="-atom7", so it lands as its own vmlinuz-linux-atom7 + modules
# dir and Arch's mkinitcpio install hooks generate initramfs-linux-atom7.img. Also
# co-installable with the 6.19 `linux-atom` (main branch): hook, update script and
# modprobe conf are all renamed to avoid file conflicts. Keep a known-good kernel
# as the default boot entry until you trust this one.
#
# Started from the 6.19 branch's ./config (the machine's own running
# config, retuned to Processor family = Atom; recapture after first boot on 7.x). Build it in an i686 chroot (the pkgmirror `atom` chroot is
# ideal). Vanilla kernel.org tree — mainline supports i686 fully; reconcile
# archlinux32's i686 patchset here if you hit anything (see README.md).

pkgbase=linux-atom7
pkgname=("$pkgbase")
pkgver=7.2.6
pkgrel=1
_srcname=linux-${pkgver}
arch=('i686')
url="https://www.kernel.org/"
license=('GPL-2.0-only')
makedepends=('bc' 'cpio' 'gettext' 'libelf' 'pahole' 'perl' 'python' 'tar' 'xz')
options=('!strip')
source=(
  "https://cdn.kernel.org/pub/linux/kernel/v7.x/${_srcname}.tar.xz"
  config
  lsmod.atom
  linux-atom7-syslinux.hook
  linux-atom7-syslinux-update
  acerhdf.conf
)
sha256sums=('039aef84f2b0994aeda3f4fcfc3d02ec9d7a9bbb9020ea264c43f446c860f606'
            'SKIP'
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
                 --set-str CONFIG_LOCALVERSION "-atom7"
  # Slim to only the modules this machine loads (aggressive; see README). On by
  # default -- an unslimmed build is only useful for local testing outside
  # pkgmirror (which has no reliable way to pass a custom env var like SLIM
  # through makechrootpkg's fixed --preserve-env allowlist), so build it with
  # `SLIM=0 makepkg -s` locally if you need the full config for comparison.
  if [ "${SLIM:-1}" != "0" ]; then
    make LSMOD="$srcdir/lsmod.atom" localmodconfig
    # localmodconfig only keeps what's loaded at lsmod-capture time -- it
    # dropped USB HID entirely (no USB keyboard/mouse was plugged in when
    # lsmod.atom was captured), which isn't just "this machine doesn't need
    # it": mkinitcpio's own `keyboard` hook expects usbhid to exist and fails
    # the initramfs build without it ("module not found: usbhid", "the image
    # may not be complete") -- confirmed 2026-07-15 on a real install. Force
    # USB HID support back on regardless of what the capture saw; it's close
    # to essential (any USB keyboard/mouse, plus early-boot input generally),
    # not a niche driver worth the aggressive slimming applied elsewhere.
    scripts/config --enable CONFIG_USB_HID --enable CONFIG_HID \
                    --enable CONFIG_HID_GENERIC --enable CONFIG_USB_HIDDEV
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
  install -Dm644 "$srcdir/linux-atom7-syslinux.hook" \
    "$pkgdir/usr/share/libalpm/hooks/91-linux-atom7-syslinux.hook"
  install -Dm755 "$srcdir/linux-atom7-syslinux-update" \
    "$pkgdir/usr/share/libalpm/scripts/linux-atom7-syslinux-update"

  echo "Installing acerhdf kernel-mode fan control config..."
  # BIOS controls the fan by default even with acerhdf loaded; kernelmode=1
  # hands control to the driver instead -- the documented, standard way to
  # use it, confirmed correct on this machine (model AOA110, BIOS v0.3310)
  # with acerhdf's own auto-detected fanon/fanoff thresholds.
  install -Dm644 "$srcdir/acerhdf.conf" \
    "$pkgdir/usr/lib/modprobe.d/linux-atom7-acerhdf.conf"
}
