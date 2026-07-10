#!/usr/bin/env bash
set -euo pipefail

library_dir="${1:?hipBLASLt library directory is required}"
gfx_arch="${2:?GPU architecture is required}"
arch_dir="${library_dir}/${gfx_arch}"

if [[ -d "${arch_dir}" ]]; then
    for artifact in "${arch_dir}"/*; do
        [[ -e "${artifact}" ]] || continue
        name="${artifact##*/}"
        [[ -e "${library_dir}/${name}" ]] \
            || ln -s "${gfx_arch}/${name}" "${library_dir}/${name}"
    done
fi

[[ -e "${library_dir}/Kernels.so-000-${gfx_arch}.hsaco" ]]
[[ -e "${library_dir}/TensileLibrary_lazy_${gfx_arch}.dat" \
    || -e "${library_dir}/TensileLibrary_lazy_${gfx_arch}.dat.zlib" ]]
