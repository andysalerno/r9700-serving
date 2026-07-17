#!/usr/bin/env bash
set -euo pipefail

# The default nightly version updates env.rocm715. Pass AMD's stable
# rocm-sdk-core index to inspect the version pinned by env.rocm714.
url="${1:-https://rocm.nightlies.amd.com/whl-multi-arch/rocm-sdk-core/}"

curl -fsSL "$url" \
  | grep -oE 'rocm_sdk_core-[^"<> ]+-py3-none-linux_x86_64\.whl' \
  | sed -E 's/^rocm_sdk_core-//; s/-py3-none-linux_x86_64\.whl$//' \
  | sort -uV \
  | tail -n 1
