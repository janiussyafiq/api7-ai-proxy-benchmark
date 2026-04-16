# api7-ai-proxy-benchmark

Isolates the overhead of the **API7 EE `ai-proxy` plugin** by comparing three request paths against a local NGINX mock that mirrors the OpenAI chat-completion schema.

1. **Direct** — wrk2 → mock (`:1980`)
2. **Gateway, no ai-proxy** — wrk2 → API7 (`:9080`) → mock
3. **Gateway, with ai-proxy** — wrk2 → API7 (`:9080`, plugin enabled) → mock

Subtracting (1) from (2) exposes raw gateway overhead. Subtracting (2) from (3) exposes the plugin's marginal cost.

## Why a mock LLM?

The goal is to isolate the ai-proxy plugin's processing cost (JSON decode → schema validation → body rewrite → re-encode) — not to measure end-to-end LLM performance. Real LLM endpoints add variable inference time (200 ms–30 s+), provider-side rate limits, token throttling, and WAN latency that drown out sub-millisecond gateway overhead. The mock returns a fixed ~200-byte JSON body in microseconds, so any latency delta between scenarios is attributable to the gateway alone. The response shape matches OpenAI's chat-completion schema so the plugin exercises its full code path.

## Environment

- DigitalOcean droplet — Ubuntu 24.04, 4 vCPU / 8 GB, Singapore
- API7 EE installed via `curl -sL https://run.api7.ai/api7/quickstart | bash`
  - `nginx_config.worker_processes: 1`, `error_log_level: warn`
- Mock upstream: `nginx` in Docker, host network, listening on `:1980`
- Load generator: [`bootjp/wrk2`](https://hub.docker.com/r/bootjp/wrk2) in Docker, host network

## Layout

```
config/
  nginx.conf         Mock OpenAI upstream — canned chat-completion JSON on :1980
  ai-proxy.yaml      ADC config: route with ai-proxy plugin enabled
  no-ai-proxy.yaml   ADC config: same route, plugin disabled
  .env.example       Template — ADC_TOKEN, MOCK_HOST, MOCK_PORT
scripts/
  req-body.lua       wrk2 Lua script — minimal chat-completion POST body
  wrk-cmd.md         wrk2 commands for each load phase (1k → 20k RPS)
results/             Raw wrk2 output per `<rps>-<scenario>.txt`
```

## Setup

```bash
cp config/.env.example config/.env
# edit: set ADC_TOKEN, MOCK_HOST (droplet IP), MOCK_PORT

# mock upstream
docker run -d --network host \
  -v $(pwd)/config/nginx.conf:/etc/nginx/nginx.conf nginx

# load generator (req-body.lua mounted at /req-body.lua inside the container)
docker run -d --network host \
  -v $(pwd)/scripts/req-body.lua:/req-body.lua bootjp/wrk2

# apply gateway config — pick one per scenario
envsubst < config/ai-proxy.yaml    | adc sync -f -
envsubst < config/no-ai-proxy.yaml | adc sync -f -
```

## Run

All wrk2 invocations run inside the load-generator container:

```bash
docker exec -it <wrk2_container_id> /bin/sh

wrk -t 4 -c 100 -d 60s -R 5000 --latency \
    -s /req-body.lua \
    http://localhost:9080/v1/chat/completions
```

Full matrix (1k / 5k / 10k / 20k RPS) lives in `scripts/wrk-cmd.md`. Save each run's output to `results/<rps>-<scenario>.txt`.

## Results summary

Sustained throughput (req/sec) at each offered load:

| Scenario                | 1k     | 5k     | 10k    | 20k     |
|-------------------------|--------|--------|--------|---------|
| Direct mock             | 1,000  | 4,976  | 9,907  | 19,793  |
| Gateway, no ai-proxy    | —      | —      | 5,076  | ~5,000  |
| Gateway, with ai-proxy  | 1,000  | 2,491  | 2,597  | 2,578   |

Key findings:

- **ai-proxy ceiling: ~2,580 RPS**, flat regardless of offered load — a hard per-request Lua cost (JSON decode / schema validation / body rewrite / re-encode).
- **Gateway-only ceiling: ~5,000 RPS** — the plugin roughly halves max throughput.
- **Direct NGINX scales linearly to 19,793 RPS** at 1.3 ms avg, confirming the droplet is not the bottleneck.
- **Sub-saturation overhead (1k RPS)**: ai-proxy adds ~0.71 ms at p50 and ~4.55 ms at p99 vs. direct — invisible against real LLM inference times.
- **Above saturation**, latency collapses into FIFO queuing (tens of seconds at 5k+ target) — not per-request cost.

**Production relevance:** most real LLM endpoints rate-limit well below 2,580 RPS per deployment, so the plugin operates in the sub-millisecond regime in practice. The ceiling only matters when aggregating many LLM deployments behind a single APISIX data-plane node.

Full latency distributions and chart: see `results/` and the [visualization artifact](https://claude.ai/public/artifacts/98ec342c-a8e3-46e6-9c58-8cddf1fb743c).

## Notes

- `config/.env` is gitignored — never commit real tokens or upstream IPs.
- YAML configs use `${MOCK_HOST}` / `${MOCK_PORT}` placeholders; `envsubst` expands them at apply time.
