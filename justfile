set positional-arguments

_default:
    @just --list

# Image tags are based on these argument values:
#   .env/env.rocm713       -> rocm713
#   .env/env.rocm714       -> rocm714
#   .env/env.rocm715       -> rocm715
#   .env/env.vllm.latest   -> vllm-latest
#   gfx12x-patched         -> gfx12x-patched
#   .env/env.aiter.bundled -> aiter-bundled

# Build the selected vLLM image(s).
[arg("aiter_env", long="aiter-env")]
[arg("patch", long)]
[arg("rocm_env", long="rocm-env")]
[arg("vllm_env", long="vllm-env")]
build-images rocm_env=".env/env.rocm713" vllm_env=".env/env.vllm.latest" patch="gfx12x-patched" aiter_env=".env/env.aiter.bundled" *compose_args:
    #!/usr/bin/env bash
    set -euo pipefail

    rocm_env="$1"
    vllm_env="$2"
    patch="$3"
    aiter_env="$4"
    shift 4
    if [[ "${1:-}" == "--" ]]; then
        shift
    fi

    choice_tag() {
        local value="${1##*/}"
        value="${value#env.}"
        value="${value//./-}"
        value="${value//_/-}"
        printf '%s' "$value"
    }

    [[ -f "$rocm_env" ]] || { echo "Missing ROCm env file: $rocm_env" >&2; exit 1; }
    [[ -f "$vllm_env" ]] || { echo "Missing vLLM env file: $vllm_env" >&2; exit 1; }
    [[ -f "$aiter_env" ]] || { echo "Missing AITER env file: $aiter_env" >&2; exit 1; }

    rocm_tag="$(choice_tag "$rocm_env")"
    vllm_tag="$(choice_tag "$vllm_env")"
    aiter_tag="$(choice_tag "$aiter_env")"

    case "$patch" in
        gfx12x-patched)
            profile="vllm-rocm-wheel-gfx12x-patched"
            ;;
        unpatched)
            profile="vllm-rocm-wheel"
            if [[ "$aiter_tag" != "aiter-bundled" ]]; then
                echo "unpatched builds use bundled AITER; use .env/env.aiter.bundled" >&2
                exit 1
            fi
            ;;
        *)
            echo "patch must be gfx12x-patched or unpatched, got: $patch" >&2
            exit 1
            ;;
    esac

    base_tag="${rocm_tag}-${vllm_tag}-unpatched-aiter-bundled"
    target_tag="${rocm_tag}-${vllm_tag}-${patch}-${aiter_tag}"
    if [[ "$patch" == "unpatched" ]]; then
        target_tag="$base_tag"
    fi

    base_image="localhost/vllm-rocm-wheel:${base_tag}"
    target_image="localhost/vllm-rocm-wheel:${target_tag}"
    base_container="vllm-rocm-wheel-${base_tag}"
    target_container="vllm-rocm-wheel-${target_tag}"

    run_compose() {
        local command=(
            env
            "VLLM_BASE_IMAGE=$base_image"
            "VLLM_BASE_CONTAINER_NAME=$base_container"
            "VLLM_PATCHED_BASE_IMAGE=$base_image"
            "VLLM_PATCHED_IMAGE=$target_image"
            "VLLM_PATCHED_CONTAINER_NAME=$target_container"
            podman compose
            "$@"
        )
        printf 'Running:'
        printf ' %q' "${command[@]}"
        printf '\n'
        "${command[@]}"
    }

    run_compose \
        --env-file "$rocm_env" \
        --env-file "$vllm_env" \
        --env-file "$aiter_env" \
        --profile vllm-rocm-wheel \
        build "$@" vllm-rocm-wheel

    if [[ "$profile" == "vllm-rocm-wheel-gfx12x-patched" ]]; then
        run_compose \
            --env-file "$rocm_env" \
            --env-file "$vllm_env" \
            --env-file "$aiter_env" \
            --profile vllm-rocm-wheel-gfx12x-patched \
            build "$@" vllm-rocm-wheel-gfx12x-patched
    fi

# Example with compose up args:
#   just up .env/env.rocm715 .env/env.vllm.latest gfx12x-patched .env/env.aiter.bundled -- -d

# Launch the selected vLLM service.
[arg("aiter_env", long="aiter-env")]
[arg("patch", long)]
[arg("rocm_env", long="rocm-env")]
[arg("vllm_env", long="vllm-env")]
up rocm_env=".env/env.rocm713" vllm_env=".env/env.vllm.latest" patch="gfx12x-patched" aiter_env=".env/env.aiter.bundled" *compose_args:
    #!/usr/bin/env bash
    set -euo pipefail

    rocm_env="$1"
    vllm_env="$2"
    patch="$3"
    aiter_env="$4"
    shift 4
    if [[ "${1:-}" == "--" ]]; then
        shift
    fi

    choice_tag() {
        local value="${1##*/}"
        value="${value#env.}"
        value="${value//./-}"
        value="${value//_/-}"
        printf '%s' "$value"
    }

    [[ -f "$rocm_env" ]] || { echo "Missing ROCm env file: $rocm_env" >&2; exit 1; }
    [[ -f "$vllm_env" ]] || { echo "Missing vLLM env file: $vllm_env" >&2; exit 1; }
    [[ -f "$aiter_env" ]] || { echo "Missing AITER env file: $aiter_env" >&2; exit 1; }

    rocm_tag="$(choice_tag "$rocm_env")"
    vllm_tag="$(choice_tag "$vllm_env")"
    aiter_tag="$(choice_tag "$aiter_env")"

    case "$patch" in
        gfx12x-patched)
            profile="vllm-rocm-wheel-gfx12x-patched"
            service="vllm-rocm-wheel-gfx12x-patched"
            ;;
        unpatched)
            profile="vllm-rocm-wheel"
            service="vllm-rocm-wheel"
            if [[ "$aiter_tag" != "aiter-bundled" ]]; then
                echo "unpatched runs use bundled AITER; use .env/env.aiter.bundled" >&2
                exit 1
            fi
            ;;
        *)
            echo "patch must be gfx12x-patched or unpatched, got: $patch" >&2
            exit 1
            ;;
    esac

    base_tag="${rocm_tag}-${vllm_tag}-unpatched-aiter-bundled"
    target_tag="${rocm_tag}-${vllm_tag}-${patch}-${aiter_tag}"
    if [[ "$patch" == "unpatched" ]]; then
        target_tag="$base_tag"
    fi

    base_image="localhost/vllm-rocm-wheel:${base_tag}"
    target_image="localhost/vllm-rocm-wheel:${target_tag}"
    base_container="vllm-rocm-wheel-${base_tag}"
    target_container="vllm-rocm-wheel-${target_tag}"

    run_compose() {
        local command=(
            env
            "VLLM_BASE_IMAGE=$base_image"
            "VLLM_BASE_CONTAINER_NAME=$base_container"
            "VLLM_PATCHED_BASE_IMAGE=$base_image"
            "VLLM_PATCHED_IMAGE=$target_image"
            "VLLM_PATCHED_CONTAINER_NAME=$target_container"
            podman compose
            "$@"
        )
        printf 'Running:'
        printf ' %q' "${command[@]}"
        printf '\n'
        "${command[@]}"
    }

    run_compose \
        --env-file "$rocm_env" \
        --env-file "$vllm_env" \
        --env-file "$aiter_env" \
        --profile "$profile" \
        up -d "$@" "$service" chatui

# Stop/remove every generated vLLM wheel container, regardless of parameter combo.
down:
    #!/usr/bin/env bash
    set -euo pipefail

    containers=()
    while IFS= read -r name; do
        case "$name" in
            vllm-rocm-wheel-*|chatui) containers+=("$name") ;;
        esac
    done < <(podman ps -a --format '{{ "{{" }}.Names{{ "}}" }}')

    if ((${#containers[@]} == 0)); then
        echo "No generated vLLM wheel or chatui containers are present."
        exit 0
    fi

    podman rm -f "${containers[@]}"

# Follow logs for the one running generated vLLM wheel container.
logs tail="200":
    #!/usr/bin/env bash
    set -euo pipefail

    tail="$1"
    containers=()
    while IFS= read -r name; do
        case "$name" in
            vllm-rocm-wheel-*) containers+=("$name") ;;
        esac
    done < <(podman ps --format '{{ "{{" }}.Names{{ "}}" }}')

    case "${#containers[@]}" in
        0)
            echo "No running generated vLLM wheel container found." >&2
            exit 1
            ;;
        1)
            exec podman logs --tail "$tail" -f "${containers[0]}"
            ;;
        *)
            echo "Multiple running generated vLLM wheel containers found:" >&2
            printf '  %s\n' "${containers[@]}" >&2
            echo "Stop the extra containers or run podman logs directly for the one you want." >&2
            exit 1
            ;;
    esac

# Remove host cache directories mounted into vLLM containers.
clear-vllm-caches:
    #!/usr/bin/env bash
    set -euo pipefail

    cache_dirs=(
        # "$HOME/.cache/huggingface"
        "$HOME/.cache/vllm"
        "$HOME/.cache/triton"
        "$HOME/.cache/torchinductor"
        "$HOME/.cache/aiter"
        "$HOME/.cache/comgr"
        "$HOME/.cache/tvm-ffi"
    )

    printf 'Removing vLLM host cache directories:\n'
    for dir in "${cache_dirs[@]}"; do
        printf '  %s\n' "$dir"
        rm -rf -- "$dir"
    done

# Print installed package/runtime versions from the selected image.
[arg("aiter_env", long="aiter-env")]
[arg("patch", long)]
[arg("rocm_env", long="rocm-env")]
[arg("vllm_env", long="vllm-env")]
check-versions rocm_env=".env/env.rocm713" vllm_env=".env/env.vllm.latest" patch="gfx12x-patched" aiter_env=".env/env.aiter.bundled":
    #!/usr/bin/env bash
    set -euo pipefail

    rocm_env="$1"
    vllm_env="$2"
    patch="$3"
    aiter_env="$4"

    choice_tag() {
        local value="${1##*/}"
        value="${value#env.}"
        value="${value//./-}"
        value="${value//_/-}"
        printf '%s' "$value"
    }

    rocm_tag="$(choice_tag "$rocm_env")"
    vllm_tag="$(choice_tag "$vllm_env")"
    aiter_tag="$(choice_tag "$aiter_env")"

    case "$patch" in
        gfx12x-patched) ;;
        unpatched)
            if [[ "$aiter_tag" != "aiter-bundled" ]]; then
                echo "unpatched images use bundled AITER; use .env/env.aiter.bundled" >&2
                exit 1
            fi
            ;;
        *)
            echo "patch must be gfx12x-patched or unpatched, got: $patch" >&2
            exit 1
            ;;
    esac

    base_tag="${rocm_tag}-${vllm_tag}-unpatched-aiter-bundled"
    target_tag="${rocm_tag}-${vllm_tag}-${patch}-${aiter_tag}"
    if [[ "$patch" == "unpatched" ]]; then
        target_tag="$base_tag"
    fi

    target_image="localhost/vllm-rocm-wheel:${target_tag}"

    podman run --rm --entrypoint python "$target_image" -c 'import importlib.metadata as md, os, torch; versions = {d.metadata["Name"].lower(): d.version for d in md.distributions()}; [print(f"{name}:", versions.get(name, "not installed")) for name in ("vllm", "amd-aiter", "flydsl", "torch", "triton", "flash-attn", "rocm-sdk-core", "rocm-sdk-devel", "rocm-sdk-libraries", "rocm-sdk-device-gfx1201")]; print("torch.version.hip:", torch.version.hip); [print(f"{key}:", os.environ.get(key)) for key in ("ROCM_PATH", "HIP_PATH", "HIPBLASLT_TENSILE_LIBPATH", "ROCBLAS_TENSILE_LIBPATH")]'

fullbuild:
    #!/usr/bin/env bash
    set -euo pipefail

    set -a
    source .env/env.fullbuild
    set +a

    podman build \
        --build-arg GPU_ARCH \
        --build-arg MAX_JOBS \
        --build-arg VLLM_REF \
        --build-arg VLLM_VERSION \
        --build-arg AITER_REF \
        --build-arg FLASH_ATTN_REF \
        --target runtime \
        --tag localhost/vllm-fullbuild:review \
        --file docker/Dockerfile.fullbuild .