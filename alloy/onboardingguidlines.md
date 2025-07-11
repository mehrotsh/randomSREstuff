# Observability Onboarding Guidelines

## Prerequisites for App Teams

### 1. Kubernetes Cluster Requirements

- **Kubernetes Version**: 1.24+ required
- **RBAC**: Enabled (default in most managed Kubernetes services)
- **Service Mesh**: Optional (Istio/Linkerd support available)
- **Resource Allocation**: Minimum 512Mi memory, 200m CPU available for Alloy agent

### 2. Application Prerequisites

#### Required Annotations for Service Discovery

Your services and pods must include these annotations for automatic discovery:

```yaml
metadata:
  annotations:
    # Required for metrics scraping
    prometheus.io/scrape: "true"
    prometheus.io/port: "8080"           # Your metrics port
    prometheus.io/path: "/metrics"       # Your metrics endpoint (optional, defaults to /metrics)
    
    # Optional for custom configuration
    prometheus.io/scheme: "https"        # If using HTTPS (optional, defaults to http)
    prometheus.io/interval: "30s"        # Custom scrape interval (optional)
```

#### Application Instrumentation Requirements

1. **Metrics**: Expose Prometheus metrics on `/metrics` endpoint
2. **Logs**: Output structured logs in JSON format with these fields:
   ```json
   {
     "timestamp": "2024-01-01T00:00:00Z",
     "level": "info|warn|error|debug",
     "message": "Log message",
     "logger": "component-name"
   }
   ```
3. **Traces**: Send traces to Alloy agent using:
   - OTLP: `http://alloy-agent:4318/v1/traces` (HTTP) or `alloy-agent:4317` (gRPC)
   - Jaeger: `http://alloy-agent:14268/api/traces`

### 3. Network Requirements

#### Required Outbound Connectivity

- Central Observability Cluster: `*.observability.company.com:443`
- Container Registry: For pulling Alloy agent images
- DNS Resolution: For service discovery within the cluster

#### Required Ports (opened by Alloy agent)

- `4317`: OTLP gRPC (traces)
- `4318`: OTLP HTTP (traces)
- `14250`: Jaeger gRPC (traces)
- `14268`: Jaeger HTTP (traces)
- `12345`: Health check and self-monitoring

## Deployment Steps

### Step 1: Get the Helm Chart

```bash
# Add the observability Helm repository
helm repo add observability https://helm-charts.observability.company.com
helm repo update

# Or clone from internal Git repository
git clone https://git.company.com/observability/alloy-agent-helm.git
```

### Step 2: Create Your Values File

Create a `values.yaml` file with your application-specific configuration:

```yaml
# values.yaml - Customize for your application
app:
  name: "my-application"
  team: "my-team"
  environment: "production"
  version: "1.2.3"
  cluster: "prod-cluster-1"
  namespace: "my-app-namespace"
  businessUnit: "engineering"
  costCenter: "eng-001"
  criticality: "high"
  
  serviceDiscovery:
    namespaces: ["my-app-namespace", "shared-services"]

# Optional: Customize resource allocation
alloy:
  resources:
    requests:
      memory: "512Mi"
      cpu: "200m"
    limits:
      memory: "1Gi"
      cpu: "500m"

# Optional: Customize telemetry collection
telemetry:
  traces:
    samplingRate: 0.2  # 20% sampling for high-traffic apps
```

### Step 3: Deploy the Alloy Agent

```bash
# Deploy using Helm
helm install alloy-agent observability/alloy-agent \
  --namespace observability \
  --create-namespace \
  --values values.yaml

# Or using kubectl with rendered templates
helm template alloy-agent observability/alloy-agent \
  --values values.yaml \
  --namespace observability | kubectl apply -f -
```

### Step 4: Verify Deployment

```bash
# Check if Alloy agent is running
kubectl get pods -n observability -l app.kubernetes.io/name=alloy-agent

# Check agent health
kubectl port-forward -n observability svc/alloy-agent 12345:12345
curl http://localhost:12345/-/healthy

# Check agent configuration
kubectl logs -n observability -l app.kubernetes.io/name=alloy-agent
```

### Step 5: Configure Your Applications

Update your application deployments to include the required annotations:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-application
spec:
  template:
    metadata:
      annotations:
        prometheus.io/scrape: "true"
        prometheus.io/port: "8080"
        prometheus.io/path: "/metrics"
    spec:
      containers:
      - name: app
        image: my-app:latest
        ports:
        - containerPort: 8080
          name: metrics
        env:
        # Configure your app to send traces to Alloy
        - name: OTEL_EXPORTER_OTLP_ENDPOINT
          value: "http://alloy-agent:4318"
        - name: OTEL_SERVICE_NAME
          value: "my-application"
        - name: OTEL_RESOURCE_ATTRIBUTES
          value: "service.version=1.2.3,deployment.environment=production"
```

## Validation and Testing

### 1. Metrics Collection

```bash
# Check if metrics are being scraped
kubectl exec -n observability -l app.kubernetes.io/name=alloy-agent -- \
  curl -s http://localhost:12345/metrics | grep prometheus_sd_discovered_targets

# Verify metrics in Grafana
# Navigate to Explore → Mimir → Query: {app_name="my-application"}
```

### 2. Logs Collection

```bash
# Check if logs are being collected
kubectl logs -n observability -l app.kubernetes.io/name=alloy-agent | grep "loki.source.kubernetes"

# Verify logs in Grafana
# Navigate to Explore → Loki → Query: {app_name="my-application"}
```

### 3. Traces Collection

```bash
# Send a test trace (if using OTLP)
curl -X POST http://localhost:4318/v1/traces \
  -H "Content-Type: application/json" \
  -d '{"resourceSpans": [{"resource": {"attributes": [{"key": "service.name", "value": {"stringValue": "test-service"}}]}}]}'

# Verify traces in Grafana
# Navigate to Explore → Tempo → Search for traces
```

## Troubleshooting Common Issues

### 1. No Metrics Being Collected

**Check:**
- Service annotations are correctly set
- Metrics endpoint is accessible: `kubectl port-forward pod/my-app 8080:8080` then `curl http://localhost:8080/metrics`
- Alloy agent has network access to your services

### 2. No Logs Being Collected

**Check:**
- Logs are in JSON format
- Pod is in a namespace that Alloy is monitoring
- Log levels match the configured filter

### 3. No Traces Being Collected

**Check:**
- Application is sending traces to correct endpoint
- Trace sampling rate is not too low
- Network connectivity between app and Alloy agent

### 4. High Resource Usage

**Recommendations:**
- Increase resource limits for Alloy agent
- Reduce metrics scraping frequency
- Implement more aggressive trace sampling
- Filter out high-cardinality metrics

## Support and Escalation

- **Slack**: #observability-support
- **Documentation**: https://docs.observability.company.com
- **Runbooks**: https://runbooks.observability.company.com
- **On-call**: page "observability-oncall" via PagerDuty

## Compliance and Security

### Data Privacy
- Ensure no PII is included in logs or metrics
- Review trace data for sensitive information
- Follow company data retention policies

### Security
- Alloy agent runs with minimal privileges
- Network policies are enforced
- All communication uses TLS where possible

### Compliance
- Observability data is retained according to company policy
- Access controls are enforced through Grafana
- Audit logs are maintained for compliance purposes
