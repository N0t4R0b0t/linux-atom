# linux-atom

A CPU-tuned, slimmed Linux kernel package for the **Acer Aspire One (Intel Atom
N270, i686)** running Arch Linux 32. Built to be consumed by
[pkgmirror](https://github.com/N0t4R0b0t/customArchForArch)'s `atom` repo (or built
standalone in its i686 build chroot).

## Why

The stock archlinux32 kernel is built **generic** (`CONFIG_M686` + `CONFIG_X86_GENERIC`).
On the in-order Bonnell Atom, instruction scheduling/alignment matters a lot, and on a
**1.4 GB** machine a slimmer kernel means faster boot and more free RAM. So this package:

1. **Tunes the processor family** to Atom (`CONFIG_MATOM`) — the biggest safe win on an
   in-order core (`-march` alone barely helps a kernel, which mostly disables SIMD and
   runtime-dispatches its hot asm).
2. **Optionally slims** the config to just the drivers the machine actually loads, via
   `make localmodconfig` against a captured module list.

It is **co-installable with the stock `linux`** — `pkgbase=linux-atom` and
`CONFIG_LOCALVERSION="-atom"`, so it installs as `vmlinuz-linux-atom` with its own
modules dir. Keep the stock kernel as a fallback boot entry until you trust this one.

## Files

| File          | What                                                                 |
|---------------|----------------------------------------------------------------------|
| `PKGBUILD`    | builds `linux-atom` (+ headers) from a kernel.org tree with `config`  |
| `config`      | the machine's **own running config**, retuned: `MATOM`, `-atom` localversion |
| `lsmod.atom`  | the machine's loaded modules — input for `localmodconfig` slimming    |
| `tune-config.sh` | reproduces the config transform from any base config               |

## Building

Build in an i686 chroot (the pkgmirror `atom` chroot is ideal — it's already set up):

```bash
# tuned only (safe):
makepkg -s

# tuned + slimmed (aggressive — see caveat):
SLIM=1 makepkg -s
```

Or wire it into pkgmirror as a local override: drop this repo's contents into
`pkgbuilds/atom/linux-atom/` and add `linux-atom` to a group (e.g. a `kernel` group),
then build it through the normal pipeline.

Before the first build, pin the kernel version and refresh checksums:

```bash
updpkgsums     # fills the SKIP sha256sums
```

## Slimming caveat

`localmodconfig` keeps only modules present in `lsmod.atom` (captured at one point in
time) plus dependencies. Anything **not loaded at capture** (a USB device you hadn't
plugged in, a filesystem you rarely mount) gets dropped. Re-capture `lsmod` with all
your hardware attached before relying on `SLIM=1`, and always keep the stock kernel as
a fallback.

## archlinux32 patches (production note)

This template builds a **vanilla** kernel.org tree. archlinux32 carries an i686-specific
patchset in their own `linux` package. For a production kernel you should base this on
**archlinux32's `linux` PKGBUILD** (rename its `pkgbase` to `linux-atom`, swap in this
`config`, keep their patches/prepare steps) rather than vanilla. This repo gives you the
tuned config + slimming inputs; reconcile them onto archlinux32's package for the real build.

## Installing

After building/installing the package, add a bootloader entry for
`vmlinuz-linux-atom` + `initramfs-linux-atom.img` (the machine uses **syslinux**), keep
the stock `linux` entry as default fallback, and boot `linux-atom` to test. Once happy,
make it the default.
