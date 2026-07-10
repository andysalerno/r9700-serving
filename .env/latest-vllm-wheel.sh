#!/usr/bin/env bash
set -euo pipefail

url="${1:-https://wheels.vllm.ai/rocm/nightly/rocm723/vllm/}"

curl -fsSL "$url" \
  | grep -oE 'vllm-[^"<> ]+\.whl' \
  | sed -E 's/^vllm-//; s/-(cp|py)[^-]*-.*$//' \
  | sed -E 's/%2[Bb]/+/g' \
  | sort -uV \
  | tail -n 1
