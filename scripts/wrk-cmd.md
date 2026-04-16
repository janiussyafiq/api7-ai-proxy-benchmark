# Performance Test Commands

## Phase 1: Baseline (1k RPS)

### Via Gateway
```bash
wrk -t 4 -c 50 -d 30s -R 1000 --latency -s /req-body.lua http://localhost:9080/v1/chat/completions
```

### Direct Mock
```bash
wrk -t 4 -c 50 -d 30s -R 1000 --latency -s /req-body.lua http://localhost:1980/v1/chat/completions
```

---

## Phase 2: Medium (5k RPS)

### Via Gateway
```bash
wrk -t 4 -c 100 -d 60s -R 5000 --latency -s /req-body.lua http://localhost:9080/v1/chat/completions
```

### Direct Mock
```bash
wrk -t 4 -c 100 -d 60s -R 5000 --latency -s /req-body.lua http://localhost:1980/v1/chat/completions
```

---

## Phase 3: High (10k RPS)

### Via Gateway
```bash
wrk -t 4 -c 200 -d 60s -R 10000 --latency -s /req-body.lua http://localhost:9080/v1/chat/completions
```

### Direct Mock
```bash
wrk -t 4 -c 200 -d 60s -R 10000 --latency -s /req-body.lua http://localhost:1980/v1/chat/completions
```

---

## Phase 4: Extreme (20k RPS)

### Via Gateway
```bash
wrk -t 4 -c 400 -d 60s -R 20000 --latency -s /req-body.lua http://localhost:9080/v1/chat/completions
```

### Direct Mock
```bash
wrk -t 4 -c 400 -d 60s -R 20000 --latency -s /req-body.lua http://localhost:1980/v1/chat/completions
```

---

## Phase 5: Without `ai-proxy` plugin

```bash
wrk -t 4 -c 100 -d 60s -R 10000 --latency -s /req-body.lua http://localhost:9080/v1/chat/completions
wrk -t 4 -c 200 -d 60s -R 20000 --latency -s /req-body.lua http://localhost:9080/v1/chat/completions
```