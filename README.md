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
2. **Slims** the config (by default) to just the drivers the machine actually loads, via
   `make localmodconfig` against a captured module list — instead of building every
   driver a general-purpose Arch config enables as a module (nouveau, amdgpu, and
   everything else this machine will never touch).

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

**Through pkgmirror** (recommended): point it at this repo directly —

```bash
bin/add-package.sh atom linux-atom --source git \
  --url https://github.com/N0t4R0b0t/linux-atom.git
```

or via the dashboard: add-package with source `git (custom repo)`. Every build
pulls this repo fresh; edit `config`/`PKGBUILD` here and the next build picks it
up, no local vendoring needed. Slimming is on by default (see below) — pkgmirror
has no reliable way to pass a custom env var like `SLIM` through
`makechrootpkg`'s fixed `--preserve-env` allowlist, so the PKGBUILD defaults to
slimmed rather than depending on one being set.

**Locally**, in an i686 chroot (the pkgmirror `atom` chroot is ideal — it's
already set up):

```bash
makepkg -s              # tuned + slimmed (the default)
SLIM=0 makepkg -s       # tuned only, full config — for comparison/debugging
```

Before the first build, pin the kernel version and refresh checksums:

```bash
updpkgsums     # fills the SKIP sha256sums
```

## Slimming caveat

`localmodconfig` keeps only modules present in `lsmod.atom` (captured at one point in
time) plus dependencies. Anything **not loaded at capture** (a USB device you hadn't
plugged in, a filesystem you rarely mount) gets dropped. Re-capture `lsmod` with all
your hardware attached before relying on the slimmed build, and always keep the stock
kernel as a fallback.

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
