set positional-arguments

_default:
    @just --list

# Show vLLM dispatcher help, or run: just vllm ACTION [choices...] [-- compose args...]
vllm *args:
    @if [ "$#" -eq 0 ]; then just _vllm help; else just _vllm "$@"; fi

# Interactively choose vLLM image options. Defaults to the build-images action.
wizard *args:
    @if [ "$#" -eq 0 ]; then just _vllm build-images; else just _vllm "$@"; fi

# Build the selected vLLM image. Missing choices are prompted interactively.
build-images *args:
    @just _vllm build-images "$@"

# Launch the selected vLLM service. Pass compose up args after --, for example: just up ... -- -d
up *args:
    @just _vllm up "$@"

# Stop the selected vLLM service.
down *args:
    @just _vllm down "$@"

# Print installed package/runtime versions from the selected image.
check-versions *args:
    @just _vllm check-versions "$@"

_vllm action *args:
    #!/usr/bin/env bash
    set -euo pipefail

    action="${1:-help}"
    shift || true

    rocm=""
    vllm=""
    patch=""
    aiter=""
    dry_run=0
    passthrough=0
    compose_args=()

    usage() {
        cat <<'USAGE'
    Usage:
      just build-images [choices...] [-- compose build args...]
      just up           [choices...] [-- compose up args...]
      just down         [choices...] [-- compose down args...]
      just check-versions [choices...]
      just wizard [build-images|up|down|check-versions]
      just vllm ACTION [choices...]

    Choices:
      rocm=713|714        or bare rocm713 / rocm714
      vllm=latest|nightly or bare latest / nightly
      patch=gfx12x|none   or bare patched / unpatched
      aiter=bundled|latest

    Notes:
      - Missing choices prompt interactively when a terminal is available.
      - aiter=latest only applies to patch=gfx12x; unpatched images use bundled AITER.
      - Image tags and container names include the selected flavors and resolved
        ROCm/vLLM versions from the .env files.
      - Add --dry-run to print the manual podman commands without running them.

    Examples:
      just build-images rocm=714 vllm=nightly patch=gfx12x aiter=bundled
      just build-images rocm713 latest unpatched
      just up rocm=713 vllm=latest patch=gfx12x aiter=latest -- -d
      just vllm plan rocm=714 vllm=nightly patch=gfx12x aiter=bundled
    USAGE
    }

    die() {
        echo "error: $*" >&2
        exit 1
    }

    env_value() {
        local file="$1"
        local key="$2"
        awk -F= -v key="$key" '
            $1 == key {
                sub(/^[^=]*=/, "")
                print
                exit
            }
        ' "$file"
    }

    tagify() {
        printf '%s' "$1" \
            | tr '[:upper:]' '[:lower:]' \
            | sed -E 's/[^a-z0-9_.-]+/-/g; s/^-+//; s/-+$//; s/-+/-/g'
    }

    tty_read() {
        local prompt="$1"
        local answer

        [[ -r /dev/tty ]] || die "$prompt requires an interactive terminal"
        printf '%s' "$prompt" > /dev/tty
        IFS= read -r answer < /dev/tty
        printf '%s' "$answer"
    }

    prompt_rocm() {
        local answer
        while [[ -z "$rocm" ]]; do
            answer="$(tty_read 'ROCm SDK [1] rocm714, [2] rocm713 (default: rocm714): ')"
            case "${answer:-1}" in
                1|714|7.14|rocm714|rocm7.14) rocm="714" ;;
                2|713|7.13|rocm713|rocm7.13) rocm="713" ;;
                *) echo "Choose 1/rocm714 or 2/rocm713." > /dev/tty ;;
            esac
        done
    }

    prompt_vllm() {
        local answer
        while [[ -z "$vllm" ]]; do
            answer="$(tty_read 'vLLM wheel stream [1] latest, [2] nightly (default: latest): ')"
            case "${answer:-1}" in
                1|latest|vllm-latest) vllm="latest" ;;
                2|nightly|vllm-nightly) vllm="nightly" ;;
                *) echo "Choose 1/latest or 2/nightly." > /dev/tty ;;
            esac
        done
    }

    prompt_patch() {
        local answer
        while [[ -z "$patch" ]]; do
            answer="$(tty_read 'Patch image [1] gfx12x/R9700 patched, [2] unpatched (default: patched): ')"
            case "${answer:-1}" in
                1|yes|true|patched|patch|gfx12x|gfx12x-patched) patch="gfx12x" ;;
                2|no|false|none|unpatched|no-patch) patch="none" ;;
                *) echo "Choose 1/patched or 2/unpatched." > /dev/tty ;;
            esac
        done
    }

    prompt_aiter() {
        local answer
        while [[ -z "$aiter" ]]; do
            answer="$(tty_read 'AITER wheel [1] bundled with vLLM, [2] latest override (default: bundled): ')"
            case "${answer:-1}" in
                1|bundled|default|no|false) aiter="bundled" ;;
                2|latest|yes|true|aiter-latest) aiter="latest" ;;
                *) echo "Choose 1/bundled or 2/latest." > /dev/tty ;;
            esac
        done
    }

    print_cmd() {
        printf '+ '
        printf '%q ' "$@"
        printf '\n'
    }

    run_cmd() {
        print_cmd "$@"
        if [[ "$dry_run" == 1 ]]; then
            return 0
        fi
        "$@"
    }

    action="${action,,}"
    case "$action" in
        build|build-image|build-images) action="build-images" ;;
        run|start|up) action="up" ;;
        stop|down) action="down" ;;
        check|versions|check-versions) action="check-versions" ;;
        plan|print|dry-run)
            action="plan"
            dry_run=1
            ;;
        help|-h|--help)
            usage
            exit 0
            ;;
        *)
            die "unknown action '$action'. Run 'just vllm' for usage."
            ;;
    esac

    while (($#)); do
        arg="$1"
        shift

        if [[ "$passthrough" == 1 ]]; then
            compose_args+=("$arg")
            continue
        fi

        case "$arg" in
            --)
                passthrough=1
                ;;
            --dry-run|dry-run|dryrun|plan=1|print=1)
                dry_run=1
                ;;
            --wizard|wizard|wizard=1)
                ;;
            rocm=*|--rocm=*)
                rocm="${arg#*=}"
                ;;
            vllm=*|--vllm=*)
                vllm="${arg#*=}"
                ;;
            patch=*|--patch=*)
                patch="${arg#*=}"
                ;;
            aiter=*|--aiter=*)
                aiter="${arg#*=}"
                ;;
            713|7.13|rocm713|rocm7.13)
                rocm="713"
                ;;
            714|7.14|rocm714|rocm7.14)
                rocm="714"
                ;;
            latest|vllm-latest)
                vllm="latest"
                ;;
            nightly|vllm-nightly)
                vllm="nightly"
                ;;
            patched|patch|gfx12x|gfx12x-patched)
                patch="gfx12x"
                ;;
            unpatched|no-patch)
                patch="none"
                ;;
            aiter-latest|latest-aiter)
                aiter="latest"
                ;;
            aiter-bundled|bundled-aiter|bundled)
                aiter="bundled"
                ;;
            *)
                die "unknown choice '$arg'. Run 'just vllm' for usage."
                ;;
        esac
    done

    rocm="${rocm,,}"
    vllm="${vllm,,}"
    patch="${patch,,}"
    aiter="${aiter,,}"

    case "$rocm" in
        "" ) ;;
        713|7.13|rocm713|rocm7.13) rocm="713" ;;
        714|7.14|rocm714|rocm7.14) rocm="714" ;;
        *) die "rocm must be 713 or 714, got '$rocm'" ;;
    esac

    case "$vllm" in
        "" ) ;;
        latest|vllm-latest) vllm="latest" ;;
        nightly|vllm-nightly) vllm="nightly" ;;
        *) die "vllm must be latest or nightly, got '$vllm'" ;;
    esac

    case "$patch" in
        "" ) ;;
        1|yes|true|patched|patch|gfx12x|gfx12x-patched) patch="gfx12x" ;;
        0|no|false|none|unpatched|no-patch) patch="none" ;;
        *) die "patch must be gfx12x or none, got '$patch'" ;;
    esac

    case "$aiter" in
        "" ) ;;
        latest|aiter-latest|yes|true|1) aiter="latest" ;;
        bundled|default|aiter-bundled|no|false|0) aiter="bundled" ;;
        *) die "aiter must be bundled or latest, got '$aiter'" ;;
    esac

    if [[ -z "$rocm" ]]; then prompt_rocm; fi
    if [[ -z "$vllm" ]]; then prompt_vllm; fi
    if [[ -z "$patch" ]]; then prompt_patch; fi

    if [[ "$patch" == "none" ]]; then
        if [[ "$aiter" == "latest" ]]; then
            die "aiter=latest requires patch=gfx12x; unpatched images use AITER bundled by the vLLM wheel"
        fi
        aiter="bundled"
    elif [[ -z "$aiter" ]]; then
        prompt_aiter
    fi

    rocm_env=".env/env.rocm${rocm}"
    vllm_env=".env/env.vllm.${vllm}"
    aiter_env=".env/aiter-latest.env"

    [[ -f "$rocm_env" ]] || die "missing $rocm_env"
    [[ -f "$vllm_env" ]] || die "missing $vllm_env"
    if [[ "$patch" == "gfx12x" && "$aiter" == "latest" ]]; then
        [[ -f "$aiter_env" ]] || die "missing $aiter_env"
    fi

    rocm_version="$(env_value "$rocm_env" ROCM_SDK_CORE_VERSION)"
    vllm_version="$(env_value "$vllm_env" VLLM_VERSION)"
    [[ -n "$rocm_version" ]] || die "ROCM_SDK_CORE_VERSION is not set in $rocm_env"
    [[ -n "$vllm_version" ]] || die "VLLM_VERSION is not set in $vllm_env"

    rocm_tag="rocm${rocm}-sdk$(tagify "$rocm_version")"
    vllm_tag="vllm-${vllm}-$(tagify "$vllm_version")"
    base_tag="${rocm_tag}-${vllm_tag}-unpatched-aiter-bundled"
    aiter_tag="bundled"

    compose_env_files=(--env-file "$rocm_env" --env-file "$vllm_env")
    if [[ "$patch" == "gfx12x" && "$aiter" == "latest" ]]; then
        aiter_wheel="$(env_value "$aiter_env" AITER_LATEST_WHEEL_FILENAME)"
        if [[ "$aiter_wheel" =~ ^amd_aiter-([^-]+)- ]]; then
            aiter_tag="latest-$(tagify "${BASH_REMATCH[1]}")"
        else
            aiter_tag="latest"
        fi
        compose_env_files+=(--env-file "$aiter_env")
    fi

    if [[ "$patch" == "gfx12x" ]]; then
        target_tag="${rocm_tag}-${vllm_tag}-gfx12x-patched-aiter-${aiter_tag}"
        profile="vllm-rocm-wheel-gfx12x-patched"
    else
        target_tag="$base_tag"
        profile="vllm-rocm-wheel"
    fi
    base_service="vllm-rocm-wheel"
    target_service="$profile"

    for tag in "$base_tag" "$target_tag"; do
        if ((${#tag} > 128)); then
            die "generated image tag is too long (${#tag} chars): $tag"
        fi
    done

    base_image="localhost/vllm-rocm-wheel:${base_tag}"
    target_image="localhost/vllm-rocm-wheel:${target_tag}"
    base_container="vllm-rocm-wheel-${base_tag}"
    target_container="vllm-rocm-wheel-${target_tag}"

    compose_env=(
        "VLLM_BASE_IMAGE=$base_image"
        "VLLM_BASE_CONTAINER_NAME=$base_container"
        "VLLM_PATCHED_BASE_IMAGE=$base_image"
        "VLLM_PATCHED_IMAGE=$target_image"
        "VLLM_PATCHED_CONTAINER_NAME=$target_container"
    )

    run_compose() {
        run_cmd env "${compose_env[@]}" podman compose "${compose_env_files[@]}" "$@"
    }

    print_selection() {
        cat <<EOF
    Selected vLLM image:
      rocm:  rocm${rocm} (${rocm_env}, SDK ${rocm_version})
      vllm:  ${vllm} (${vllm_env}, ${vllm_version})
      patch: ${patch}
      aiter: ${aiter}
      base:  ${base_image}
      target: ${target_image}
    EOF
    }

    print_selection

    case "$action" in
        build-images)
            run_compose --profile vllm-rocm-wheel build "${compose_args[@]}" "$base_service"
            if [[ "$patch" == "gfx12x" ]]; then
                run_compose --profile vllm-rocm-wheel-gfx12x-patched build "${compose_args[@]}" "$target_service"
            fi
            ;;
        up)
            run_compose --profile "$profile" up "${compose_args[@]}" "$target_service"
            ;;
        down)
            run_compose --profile "$profile" down "${compose_args[@]}"
            ;;
        check-versions)
            run_cmd podman run --rm --entrypoint python "$target_image" -c 'import importlib.metadata as md, os, torch; versions = {d.metadata["Name"].lower(): d.version for d in md.distributions()}; [print(f"{name}:", versions.get(name, "not installed")) for name in ("vllm", "amd-aiter", "flydsl", "torch", "triton", "flash-attn", "rocm-sdk-core", "rocm-sdk-devel", "rocm-sdk-libraries", "rocm-sdk-device-gfx1201")]; print("torch.version.hip:", torch.version.hip); [print(f"{key}:", os.environ.get(key)) for key in ("ROCM_PATH", "HIP_PATH", "HIPBLASLT_TENSILE_LIBPATH", "ROCBLAS_TENSILE_LIBPATH")]'
            ;;
        plan)
            run_compose --profile vllm-rocm-wheel build "${compose_args[@]}" "$base_service"
            if [[ "$patch" == "gfx12x" ]]; then
                run_compose --profile vllm-rocm-wheel-gfx12x-patched build "${compose_args[@]}" "$target_service"
            fi
            run_compose --profile "$profile" up "${compose_args[@]}" "$target_service"
            ;;
    esac
