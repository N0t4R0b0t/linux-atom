#!/usr/bin/env bash
# tune-config.sh <base-config> [out]
#
# Reproduce the linux-atom config transform from any base kernel config (e.g. a fresh
# archlinux32 `linux` config or the machine's /proc/config.gz): set the processor
# family to Atom and give it a distinct localversion. Slimming (localmodconfig) is a
# separate build-time step (SLIM=1 in the PKGBUILD) since it needs the kernel tree.
set -euo pipefail

base="${1:?usage: tune-config.sh <base-config> [out]}"
out="${2:-config}"
[ -f "$base" ] || { echo "no such file: $base" >&2; exit 1; }

sed -e 's/^CONFIG_M686=y/# CONFIG_M686 is not set\nCONFIG_MATOM=y/' \
    -e 's/^CONFIG_X86_GENERIC=y/# CONFIG_X86_GENERIC is not set/' \
    -e 's/^CONFIG_LOCALVERSION="[^"]*"/CONFIG_LOCALVERSION="-atom"/' \
    "$base" > "$out"

# Ensure the settings exist even if the base lacked them.
grep -q '^CONFIG_MATOM=y' "$out" || printf 'CONFIG_MATOM=y\n' >> "$out"
grep -q '^CONFIG_LOCALVERSION=' "$out" || printf 'CONFIG_LOCALVERSION="-atom"\n' >> "$out"

echo "wrote $out"
grep -E '^CONFIG_MATOM=|^# CONFIG_M686|^# CONFIG_X86_GENERIC|^CONFIG_LOCALVERSION=' "$out"
