# GitHub Copilot Prompt — Devin AI SRE PoC: Uninstrumented Golang Application

---

## 🎯 Context & Goal

You are building the **starting point** for a Devin AI proof-of-concept in an SRE context.
The goal of this PoC is to let Devin autonomously instrument a Golang application using OpenTelemetry.
Therefore, **this app must have zero instrumentation** — no traces, no metrics, no logs beyond basic `fmt` or `log` stdlib calls.

Devin will later:
- Add OpenTelemetry SDK (traces, metrics, logs) to the Go app
- Wire up a Grafana Alloy agent to collect and forward telemetry
- Route all signals to a Grafana LGTM stack (Loki + Grafana + Tempo + Mimir) running in the same Docker Compose environment

Your job is to create the **application only** — a realistic, multi-service Golang app that is:
- Rich in observable surface area (HTTP handlers, DB calls, downstream HTTP calls, background workers, error paths)
- Free of any OTel imports, SDKs, tracing middleware, or metric collectors
- Packaged as Docker Compose services (app only — Alloy and LGTM will be added by Devin)

---

## 📐 Application Design Requirements

### Service: `order-service` (primary Go HTTP API)

Build a realistic e-commerce **Order Service** with the following HTTP endpoints:

| Method | Path | Behavior |
|--------|------|----------|
| `POST` | `/orders` | Create a new order (write to SQLite or Postgres) |
| `GET` | `/orders/:id` | Fetch order by ID |
| `GET` | `/orders` | List all orders (paginated) |
| `POST` | `/orders/:id/pay` | Simulate payment via downstream HTTP call to `payment-service` |
| `POST` | `/orders/:id/cancel` | Cancel an order with business logic validation |
| `GET` | `/health` | Health check (returns 200 OK) |
| `GET` | `/ready` | Readiness check (checks DB connectivity) |

**Deliberate failure scenarios built-in** (these make instrumentation interesting):
- `/orders/:id/pay` should have a configurable `PAYMENT_FAILURE_RATE` env var (e.g., `0.3` = 30% failures)
- `/orders` list should introduce a simulated latency via `SLOW_QUERY_RATE` env var
- Create order should validate payload and return `400` on bad input
- Fetch a non-existent order should return `404`

### Service: `payment-service` (downstream Go HTTP service)

A lightweight Go HTTP service that simulates payment processing:

| Method | Path | Behavior |
|--------|------|----------|
| `POST` | `/payments` | Process a payment (simulate success/failure) |
| `GET` | `/health` | Health check |

- Reads `FAILURE_RATE` env var to randomly return `500` errors
- Adds artificial latency via `LATENCY_MS` env var (simulates slow payment gateway)
- Returns structured JSON responses

### Background Worker (inside `order-service`)

- A goroutine that runs every `N` seconds (configurable via `WORKER_INTERVAL_SECONDS`)
- Scans for `pending` orders older than a threshold and marks them `expired`
- This gives Devin something interesting to instrument with background job metrics

---

## 🗂️ Project Structure

Generate the following layout:

```
devin-sre-poc/
├── docker-compose.yml
├── order-service/
│   ├── Dockerfile
│   ├── main.go
│   ├── handler/
│   │   ├── order.go
│   │   └── health.go
│   ├── service/
│   │   └── order_service.go
│   ├── repository/
│   │   └── order_repo.go
│   ├── client/
│   │   └── payment_client.go
│   ├── worker/
│   │   └── expiry_worker.go
│   ├── model/
│   │   └── order.go
│   └── go.mod / go.sum
├── payment-service/
│   ├── Dockerfile
│   ├── main.go
│   ├── handler/
│   │   └── payment.go
│   └── go.mod / go.sum
├── scripts/
│   ├── load_test.sh        # sustained normal load
│   ├── chaos_test.sh       # triggers failure paths
│   ├── spike_test.sh       # sudden burst load
│   └── README.md
└── README.md
```

---

## ⚙️ Technical Specifications

### Language & Framework
- **Go 1.22+**
- Use **`net/http`** standard library (no Gin, Fiber, Echo) — this forces Devin to instrument at the middleware level, which is more educational
- Use **`database/sql`** with **`lib/pq`** (Postgres) or **`mattn/go-sqlite3`** for persistence
- Use **`encoding/json`** for request/response handling
- Structured logging using **`log/slog`** (Go 1.21+ stdlib) — basic, no OTel log bridge

### Database
- Use **PostgreSQL** (via Docker Compose service) with a simple `orders` table
- Include an `init.sql` for schema creation
- Schema:

```sql
CREATE TABLE orders (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    customer_id TEXT NOT NULL,
    item_sku TEXT NOT NULL,
    quantity INT NOT NULL,
    total_amount DECIMAL(10,2) NOT NULL,
    status TEXT NOT NULL DEFAULT 'pending', -- pending | paid | cancelled | expired
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);
```

### Docker Compose (`docker-compose.yml`)
Include only:
- `order-service`
- `payment-service`
- `postgres`

**Do NOT include** Grafana Alloy, Loki, Tempo, Mimir, or Grafana — Devin will add these.

Add placeholder comments in `docker-compose.yml` where Devin should inject the observability stack:

```yaml
# TODO (Devin): Add grafana-alloy service here
# TODO (Devin): Add lgtm stack services here (loki, tempo, mimir, grafana)
# TODO (Devin): Add alloy config volume mount
```

### Environment Variables (document in README)

**order-service:**
```
DB_HOST, DB_PORT, DB_USER, DB_PASSWORD, DB_NAME
PAYMENT_SERVICE_URL
PAYMENT_FAILURE_RATE       # float 0.0–1.0, default 0.2
SLOW_QUERY_RATE            # float 0.0–1.0, default 0.1
WORKER_INTERVAL_SECONDS    # int, default 30
PORT                       # default 8080
```

**payment-service:**
```
FAILURE_RATE               # float 0.0–1.0, default 0.3
LATENCY_MS                 # int, default 200
PORT                       # default 8090
```

---

## 📜 Load & Chaos Test Scripts

### `scripts/load_test.sh` — Sustained Normal Load
```bash
#!/bin/bash
# Uses curl in a loop to simulate realistic traffic
# Mix of: create order, get order, list orders, pay order
# Run for duration specified as arg: ./load_test.sh 120 (seconds)
# Target: ORDER_SERVICE_URL env or default http://localhost:8080
```
Requirements:
- Runs a loop for N seconds (arg or default 60s)
- Randomizes customer IDs and SKUs
- Creates orders then pays them (success path)
- Prints a summary at the end (total requests, errors)
- Uses only `curl`, `bash`, `jq` — no external tools

### `scripts/chaos_test.sh` — Failure Injection
```bash
#!/bin/bash
# Deliberately triggers error paths:
# - POST /orders with invalid payload (400s)
# - GET /orders/<nonexistent-uuid> (404s)
# - POST /orders/<id>/pay when payment-service is under high failure rate
# - Rapid concurrent requests to trigger race conditions
```
Requirements:
- Fires bad payloads to generate 4xx errors
- Uses `&` for parallelism (10 concurrent requests at once)
- Optionally accepts a `--duration` flag

### `scripts/spike_test.sh` — Traffic Spike
```bash
#!/bin/bash
# Simulates a sudden burst: 50 concurrent order creations
# Then ramps down. Good for testing latency percentile instrumentation.
```

---

## 🚫 Hard Constraints (Do Not Violate)

1. **Zero OpenTelemetry imports** — no `go.opentelemetry.io/*` packages anywhere
2. **Zero Prometheus imports** — no `github.com/prometheus/client_golang`
3. **No custom metrics code** — no counters, histograms, or gauges
4. **No tracing middleware** — no context propagation beyond what's idiomatic Go
5. **No structured trace IDs** in responses — plain JSON only
6. **No external HTTP middleware libraries** (no gorilla/mux, no Chi) — use `net/http` only
7. All logging must use Go's stdlib `log/slog` at `INFO`/`ERROR` level only — no log levels that assume trace correlation

---

## ✅ Quality Checklist for Copilot Output

Before finalising, ensure:
- [ ] `docker compose up` brings up all 3 services cleanly
- [ ] All endpoints return correct status codes
- [ ] `PAYMENT_FAILURE_RATE=1.0` makes every payment fail with `500`
- [ ] `PAYMENT_FAILURE_RATE=0.0` makes every payment succeed
- [ ] `SLOW_QUERY_RATE=1.0` makes every list query slow (>500ms)
- [ ] Background worker goroutine starts and logs its activity
- [ ] `scripts/load_test.sh` runs without errors on a fresh `docker compose up`
- [ ] `scripts/chaos_test.sh` generates a visible mix of 4xx/5xx responses
- [ ] README includes: architecture diagram (ASCII), env vars table, how to run, and a note for Devin on what instrumentation is expected

---

## 📝 README Requirements

The README should include:

1. **Architecture Overview** (ASCII diagram showing order-service → payment-service → postgres)
2. **Why This App** — explain it's designed to be instrumented by Devin
3. **Running the App** — `docker compose up --build`
4. **Running Test Scripts** — with example commands
5. **For Devin** section — a clear brief:
   - Instrument using OpenTelemetry Go SDK (traces, metrics, logs)
   - Deploy Grafana Alloy as the collector (config provided separately)
   - Forward to LGTM stack on same Docker network
   - Expected dashboards: request rate, error rate, latency p50/p95/p99, DB query durations, background worker execution time
   - Suggested OTel span names and metric names to use

---

## 💡 Copilot Instructions

Generate all files in the structure above. Follow idiomatic Go conventions:
- Use `context.Context` propagation throughout (even without tracing — this makes Devin's job of adding spans easier)
- Add `//nolint` comments where appropriate
- Keep handler, service, and repository layers clearly separated
- Use dependency injection (pass DB and HTTP client as constructor args)
- Add meaningful error wrapping using `fmt.Errorf("...: %w", err)`

Start with `docker-compose.yml`, then `order-service/main.go`, then work through each package in the order: model → repository → service → client → worker → handler → Dockerfile. Then generate `payment-service`. Finally generate all three scripts and the README.
