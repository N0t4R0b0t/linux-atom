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
| `linux-atom-syslinux.hook` | pacman hook, fires on install/upgrade of this package     |
| `linux-atom-syslinux-update` | script the hook runs — registers the syslinux boot entry |
| `acerhdf.conf` | modprobe.d config — switches fan control from BIOS to kernel (`acerhdf`) |

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

**Real incident (2026-07-15)**: no USB keyboard/mouse was plugged in when `lsmod.atom`
was captured, so `localmodconfig` dropped USB HID support entirely. This isn't just
"this machine doesn't need it" — `mkinitcpio`'s own `keyboard` hook expects
`usbhid` to exist and **fails the initramfs build without it**
(`module not found: usbhid`, `the image may not be complete`). `pkgrel=5` force-enables
`CONFIG_USB_HID`/`CONFIG_HID`/`CONFIG_HID_GENERIC`/`CONFIG_USB_HIDDEV` after the
`localmodconfig` step regardless of what the capture saw — treat USB HID as close to
essential, not a candidate for aggressive slimming, on any machine using this template.

## archlinux32 patches (production note)

This template builds a **vanilla** kernel.org tree. archlinux32 carries an i686-specific
patchset in their own `linux` package. For a production kernel you should base this on
**archlinux32's `linux` PKGBUILD** (rename its `pkgbase` to `linux-atom`, swap in this
`config`, keep their patches/prepare steps) rather than vanilla. This repo gives you the
tuned config + slimming inputs; reconcile them onto archlinux32's package for the real build.

## Installing

The machine boots via **syslinux**, which — unlike GRUB or systemd-boot — never
auto-registers a newly installed kernel in its menu. This package ships a pacman
hook (`91-linux-atom-syslinux.hook` → `linux-atom-syslinux-update`) that adds a
`LABEL linux-atom` stanza to `/boot/syslinux/syslinux.cfg` automatically on
install/upgrade. It's idempotent (skips if the entry already exists) and only
ever *appends* — it never touches `DEFAULT` or edits an existing `linux-atom`
entry, so it can't clobber hand-tuning or silently change what boots by
default. After installing, select "Arch Linux (linux-atom, tuned)" at the
syslinux menu to test it; the stock kernel stays the default until you
manually flip `DEFAULT` in `syslinux.cfg`.

## Benchmarks (2026-07-15, real machine)

Compared the tuned+slimmed kernel (`6.19.11-atom`) against the stock
archlinux32 kernel (`6.19.11-arch1-1.0`) on the actual Aspire One, rebooting
between runs and waiting for load average to settle (`< 0.15`) before each
test — an early pass showed clearly boot-noise-inflated latency (max 130ms+)
until this discipline was applied.

**Raw CPU/crypto throughput — no measurable difference**, and that's expected,
not a failure: `sysbench`/`openssl` are the same stock binaries on both boots
(userspace packages aren't affected by which kernel is running), and their hot
loops never leave userspace. `-march=atom -mtune=atom` only affects code
actually *compiled* with those flags — the kernel has little influence on raw
arithmetic/crypto throughput, which is dominated by the CPU-bound loop itself.

| sysbench | atom | stock | diff |
|---|---|---|---|
| CPU, 1 thread | 43.02 ev/s | 42.89 ev/s | +0.3% (noise) |
| CPU, 2 threads | 70.13 ev/s | 69.98 ev/s | +0.2% (noise) |
| memory | 134,817 ops/s | 133,092 ops/s | +1.3% |
| openssl sha256 (16B) | 4849.5k | 4869.0k | -0.4% (noise) |
| openssl aes-256-cbc (16B) | 12085.5k | 12137.8k | -0.4% (noise) |

**Memory footprint — small, real, directionally consistent wins** from
slimming, though tiny relative to the machine's 1.4GB total RAM (<1.5%
either way):

| metric | atom | stock | diff |
|---|---|---|---|
| `vmlinuz` size | 8.16 MB | 9.88 MB | **-17.5%** |
| Slab | 32,028 kB | 35,568 kB | **-10%** |
| SReclaimable | 10,896 kB | 13,956 kB | **-22%** |
| modules loaded | 82 | 87 | 5 fewer |
| total module memory | 10,580 KiB | 10,396 KiB | +2% (small anomaly, not chased down) |
| `initramfs` size | 14.32 MB | 14.46 MB | -1% |

**Scheduler/context-switch behavior — mixed, not a clean sweep:**

| sysbench threads | atom | stock | diff |
|---|---|---|---|
| 2 threads/4 locks — events | 4,894 | 4,905 | tie |
| 2 threads/4 locks — max latency | 39.37ms | 73.80ms | atom smoother tail |
| fork+exec 3000× `/bin/true` — wall time | 10.051s | 9.554s | **stock ~5% faster** |
| 4 threads/8 locks — events | 2,794 | 2,333 | **atom +20%** |
| 4 threads/8 locks — avg latency | 14.33ms | 17.14ms | **atom -16%** |

Under light contention it's a wash; under plain fork/exec (process creation,
no contention) stock is actually a bit faster. The tuned kernel's real edge
shows up specifically under **oversubscribed thread contention** (4 threads
on this 2-thread CPU) — the scenario closest to real desktop multitasking —
where it does ~20% more work at lower, more consistent latency. Not a
universal win, but a believable, honest one where it plausibly matters most.

Raw output saved on the machine under `~/bench/` (`bench-*.txt`,
`mem-*.txt`, `kernel-bench-*.txt` per kernel version).

## Fan control (acerhdf, kernel-mode)

The Aspire One has a dedicated Linux fan/thermal driver, `acerhdf`
(`CONFIG_ACERHDF=m`, already enabled in `./config` — confirmed loaded and
reporting real temperatures on this machine, model `AOA110`, BIOS `v0.3310`).
By default the driver only *monitors* — the BIOS still makes the actual
fan on/off decision. `acerhdf.conf` switches that over to the kernel
(`options acerhdf kernelmode=1`), the standard, documented way to actually
use this driver (see its own boot dmesg message) — more responsive/tunable
than the stock BIOS curve.

Deliberately **not** overriding `fanon`/`fanoff` — acerhdf auto-detects the
right thresholds from a per-model/per-BIOS-version table, confirmed correct
here (`fanon=60°C`, `fanoff=53°C`, both sane vendor-calibrated values). Don't
hand-tune those without real thermal-load data backing a change.

**Checked and ruled out** (2026-07-15): a distinctly separate, software-
controllable "palm rest" LED doesn't appear to exist on this model —
`/sys/class/leds/` only shows keyboard lock lights, MMC activity, and the
WiFi radio-state LED (`phy0-led`, automatically tied to radio on/off, not
independently addressable). Matches known reports that Acer's ACPI-WMI
implementation on Aspire-One-era hardware is incompletely supported by
`acer-wmi`. Also **not pursuing CPU overclocking**: the N270's thermal
design has essentially no headroom, this hardware has no safe CMOS-reset
path if a bad BIOS setting bricks it, and the Linux-side FSB-modification
tools that exist for this class of hardware are Windows-only.
