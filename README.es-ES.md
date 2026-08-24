

# vLLM en Radeon AI PRO R9700

Comila y ejecuta vLLM desde el código fuente para GPU AMD Radeon AI PRO R9700. La configuración predeterminada está dirigida a dos R9700 (`gfx1201`) y sirve un modelo a través de la API compatible con OpenAI de vLLM, con la interfaz de chat de Hugging Face como frontend.

## Requisitos

- Podman con `podman compose` (`docker compose` podría funcionar, pero no ha sido probado)
- [`just`](https://just.systems/)
- Una o más GPU R9700; la configuración incluida asume dos

## Compilación y ejecución

El `justfile` proporciona el flujo de trabajo completo:

```sh
# Build localhost/vllm-fullbuild:latest.
just build

# Start vLLM and Chat UI in the background.
just up

# Follow service logs.
just logs

# Stop and remove the containers.
just down
```

La API compatible con OpenAI de vLLM está disponible en `http://localhost:8000/v1`, y la interfaz de chat está disponible en `http://localhost:8001`.

Ejecuta `just --list` para ver todas las recetas disponibles.

## Configuración

Las versiones de compilación y las revisiones del código fuente están fijadas en `env/env.fullbuild`. La compilación utiliza `Dockerfile.fullbuild` para instalar el stack de PyTorch/ROCm fijado y compilar Flash Attention, AITER y vLLM para `gfx1201`.

La configuración de tiempo de ejecución está en `compose.yaml`, e incluye el modelo, los argumentos de línea de comandos de vLLM, la cantidad de GPU, los puertos y las cachés montadas. El modelo predeterminado es `Qwen/Qwen3.6-27B-FP8` con el paralelismo de tensores configurado para dos GPU.

El entorno de tiempo de ejecución se divide entre:

- `env/2xr9700.vllm.common` para la configuración de ROCm de dos GPU
- `env/aiter-unified-attention.env` para la atención unificada de AITER

Edita estos archivos y `compose.yaml` para que coincidan con tu hardware y modelo antes de compilar o iniciar los servicios.

Para eliminar las cachés generadas en el host de vLLM, Triton, TorchInductor, AITER, COMGR y TVM FFI, ejecuta:

```sh
just clear-vllm-caches
```

La caché de modelos de Hugging Face se conserva intencionalmente.

## Enfoque archivado

El enfoque anterior de múltiples perfiles e imagen parcheada permanece en [`archive/`](archive/) como referencia.

## Benchmark

Las versiones de VLLM/ROCm/AITER fijadas en el commit actual (el que agrega este benchmark al readme) mostraron estas velocidades:

(nota que esta es la velocidad para una sola solicitud, sin solicitudes concurrentes)

| modelo               |           prueba |              t/s |       pico t/s |         ttfr (ms) |      est_ppt (ms) |     e2e_ttft (ms) |
|:---------------------|-----------------:|-----------------:|---------------:|------------------:|------------------:|------------------:|
| Qwen/Qwen3.6-27B-FP8 |          pp2048 | 2385.71 ± 330.07 |                |   880.24 ± 112.31 |   874.79 ± 112.31 |   880.24 ± 112.31 |
| Qwen/Qwen3.6-27B-FP8 |            tg32 |   105.10 ± 29.82 | 108.55 ± 30.82 |                   |                   |                   |
| Qwen/Qwen3.6-27B-FP8 |  pp2048 @ d1024 |   2935.75 ± 9.05 |                |    1052.21 ± 3.22 |    1046.76 ± 3.22 |    1054.72 ± 3.10 |
| Qwen/Qwen3.6-27B-FP8 |    tg32 @ d1024 |     76.51 ± 4.68 |   79.00 ± 4.84 |                   |                   |                   |
| Qwen/Qwen3.6-27B-FP8 |  pp2048 @ d2048 | 2692.73 ± 214.37 |                |  1536.21 ± 119.54 |  1530.76 ± 119.54 |  1536.21 ± 119.54 |
| Qwen/Qwen3.6-27B-FP8 |    tg32 @ d2048 |   109.08 ± 31.38 | 112.68 ± 32.43 |                   |                   |                   |
| Qwen/Qwen3.6-27B-FP8 |  pp2048 @ d4096 |  2844.92 ± 85.41 |                |   2167.18 ± 65.82 |   2161.73 ± 65.82 |   2167.18 ± 65.82 |
| Qwen/Qwen3.6-27B-FP8 |    tg32 @ d4096 |   127.89 ± 68.65 | 132.13 ± 70.98 |                   |                   |                   |
| Qwen/Qwen3.6-27B-FP8 |  pp2048 @ d8192 |  2775.16 ± 96.64 |                |  3700.08 ± 125.89 |  3694.63 ± 125.89 |  3700.08 ± 125.89 |
| Qwen/Qwen3.6-27B-FP8 |    tg32 @ d8192 |   156.02 ± 66.06 | 161.26 ± 68.33 |                   |                   |                   |
| Qwen/Qwen3.6-27B-FP8 | pp2048 @ d16384 |  2864.09 ± 28.21 |                |   6442.09 ± 63.74 |   6436.64 ± 63.74 |   6442.09 ± 63.74 |
| Qwen/Qwen3.6-27B-FP8 |   tg32 @ d16384 |    92.89 ± 16.83 |  95.94 ± 17.39 |                   |                   |                   |
| Qwen/Qwen3.6-27B-FP8 | pp2048 @ d32000 |  2667.29 ± 29.15 |                | 12772.24 ± 140.57 | 12766.79 ± 140.57 | 12772.24 ± 140.57 |
| Qwen/Qwen3.6-27B-FP8 |   tg32 @ d32000 |   112.20 ± 66.73 | 115.93 ± 69.02 |                   |                   |                   |
| Qwen/Qwen3.6-27B-FP8 | pp2048 @ d64000 |   2307.39 ± 3.96 |                |  28630.69 ± 48.97 |  28625.24 ± 48.97 |  28630.69 ± 48.97 |
| Qwen/Qwen3.6-27B-FP8 |   tg32 @ d64000 |   117.57 ± 23.28 | 121.43 ± 24.07 |                   |                   |                   |
