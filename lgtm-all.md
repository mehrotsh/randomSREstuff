# LGTM Stack Implementation Plan for Azure Kubernetes Service

## Executive Summary

This document outlines a comprehensive plan to implement a production-ready observability platform using the Grafana LGTM stack (Loki, Grafana, Tempo, Mimir) on Azure Kubernetes Service (AKS). The solution includes a dual-agent Grafana Alloy architecture for scalable telemetry collection and processing.

## 1. Infrastructure and Capacity Planning

### 1.1 LGTM Stack Component Sizing

#### Mimir (Metrics)
**Production Sizing:**
- **Frontend/Query-frontend**: 3 replicas, 2 CPU, 4Gi memory
- **Querier**: 6 replicas, 4 CPU, 8Gi memory
- **Ingester**: 12 replicas, 4 CPU, 16Gi memory, 100Gi SSD storage
- **Store-gateway**: 6 replicas, 2 CPU, 8Gi memory
- **Compactor**: 3 replicas, 4 CPU, 8Gi memory
- **Ruler**: 3 replicas, 2 CPU, 4Gi memory

**Storage Requirements:**
- Azure Blob Storage for long-term metrics (1TB+ with lifecycle policies)
- Premium SSD for ingester local storage (100Gi per replica)

#### Loki (Logs)
**Production Sizing:**
- **Gateway**: 3 replicas, 1 CPU, 2Gi memory
- **Distributor**: 6 replicas, 2 CPU, 4Gi memory
- **Ingester**: 9 replicas, 4 CPU, 8Gi memory, 150Gi SSD storage
- **Querier**: 6 replicas, 4 CPU, 8Gi memory
- **Query-frontend**: 3 replicas, 2 CPU, 4Gi memory
- **Compactor**: 2 replicas, 2 CPU, 4Gi memory

**Storage Requirements:**
- Azure Blob Storage for chunk storage (2TB+ with lifecycle policies)
- Premium SSD for ingester WAL (150Gi per replica)

#### Tempo (Traces)
**Production Sizing:**
- **Distributor**: 6 replicas, 2 CPU, 4Gi memory
- **Ingester**: 9 replicas, 4 CPU, 8Gi memory, 100Gi SSD storage
- **Querier**: 6 replicas, 4 CPU, 8Gi memory
- **Query-frontend**: 3 replicas, 2 CPU, 4Gi memory
- **Compactor**: 3 replicas, 2 CPU, 4Gi memory

**Storage Requirements:**
- Azure Blob Storage for trace storage (1TB+ with lifecycle policies)
- Premium SSD for ingester local storage (100Gi per replica)

#### Grafana
**Production Sizing:**
- **Grafana**: 3 replicas, 2 CPU, 4Gi memory
- **PostgreSQL**: 3 replicas, 2 CPU, 4Gi memory, 100Gi Premium SSD

### 1.2 AKS Node Pool Strategy

#### LGTM Node Pool
- **Instance Type**: Standard_D16s_v3 (16 cores, 64GB RAM)
- **Node Count**: 12-24 nodes (auto-scaling enabled)
- **Disk**: 512GB Premium SSD OS disk
- **Network**: Accelerated networking enabled
- **Taints**: `lgtm=true:NoSchedule`

#### Alloy Node Pool (Sink Agents)
- **Instance Type**: Standard_D4s_v3 (4 cores, 16GB RAM)
- **Node Count**: 3-6 nodes (auto-scaling enabled)
- **Disk**: 128GB Premium SSD OS disk
- **Taints**: `alloy-sink=true:NoSchedule`

### 1.3 High Availability and Scaling

#### Multi-Zone Deployment
```yaml
nodeAffinity:
  requiredDuringSchedulingIgnoredDuringExecution:
    nodeSelectorTerms:
    - matchExpressions:
      - key: topology.kubernetes.io/zone
        operator: In
        values: ["eastus-1", "eastus-2", "eastus-3"]

podAntiAffinity:
  preferredDuringSchedulingIgnoredDuringExecution:
  - weight: 100
    podAffinityTerm:
      labelSelector:
        matchExpressions:
        - key: app.kubernetes.io/name
          operator: In
          values: ["mimir-ingester"]
      topologyKey: topology.kubernetes.io/zone
```

#### Horizontal Pod Autoscaling
```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: mimir-querier-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: mimir-querier
  minReplicas: 6
  maxReplicas: 20
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 80
```

### 1.4 Storage and Retention Planning

#### Retention Policies
- **Metrics**: 15 days high-resolution, 90 days downsampled, 1 year aggregated
- **Logs**: 30 days full retention, 90 days compressed
- **Traces**: 7 days full retention, 30 days sampled

#### Azure Storage Configuration
```yaml
# Mimir storage config
blocks_storage:
  backend: azure
  azure:
    storage_account_name: "lgtmmetricsstore"
    container_name: "mimir-blocks"
    endpoint_suffix: "core.windows.net"
  bucket_store:
    max_chunk_pool_bytes: 2147483648
    chunk_pool_min_bucket_size_bytes: 262144
    max_sample_count: 50000000
```

## 2. Alloy Agent Telemetry Collection Strategy

### 2.1 Dual-Agent Architecture

#### Source Alloy Agent (Application Clusters/VMs)
**Deployment Model**: DaemonSet for Kubernetes, Binary for VMs

**Key Responsibilities**:
- Collect logs, metrics, and traces from applications
- Enrich telemetry with environment-specific labels
- Apply local filtering and sampling
- Buffer and batch data for efficient transmission
- Handle network failures with retry logic

#### Sink Alloy Agent (LGTM Cluster)
**Deployment Model**: Deployment with multiple replicas

**Key Responsibilities**:
- Receive telemetry from Source Agents
- Validate data format and structure
- Apply global filtering and routing rules
- Distribute data to appropriate LGTM components
- Provide observability into the collection pipeline

### 2.2 Source Alloy Agent Configuration Template

```alloy
// Source Alloy Agent Configuration Template
// Environment: ${ENVIRONMENT}
// Application: ${APPLICATION_NAME}
// Cluster: ${CLUSTER_NAME}

logging {
  level = "info"
  format = "json"
}

// Kubernetes Service Discovery
discovery.kubernetes "pods" {
  role = "pod"
  namespaces {
    names = ["${APPLICATION_NAMESPACE}"]
  }
}

discovery.kubernetes "services" {
  role = "service"
  namespaces {
    names = ["${APPLICATION_NAMESPACE}"]
  }
}

// Prometheus Metrics Collection
prometheus.scrape "app_metrics" {
  targets = discovery.kubernetes.pods.targets
  forward_to = [prometheus.relabel.add_labels.receiver]
  scrape_interval = "30s"
  scrape_timeout = "10s"
  
  // Only scrape pods with prometheus annotations
  honor_labels = true
  metrics_path = "/metrics"
}

// Add environment labels to metrics
prometheus.relabel "add_labels" {
  forward_to = [prometheus.remote_write.sink.receiver]
  
  rule {
    source_labels = ["__meta_kubernetes_pod_name"]
    target_label = "pod"
  }
  
  rule {
    source_labels = ["__meta_kubernetes_namespace"]
    target_label = "namespace"
  }
  
  rule {
    replacement = "${ENVIRONMENT}"
    target_label = "environment"
  }
  
  rule {
    replacement = "${APPLICATION_NAME}"
    target_label = "application"
  }
  
  rule {
    replacement = "${CLUSTER_NAME}"
    target_label = "cluster"
  }
  
  // Drop high-cardinality metrics
  rule {
    source_labels = ["__name__"]
    regex = "(.*_bucket|.*_count|.*_sum).*{.*user_id.*}"
    action = "drop"
  }
}

// Remote write to Sink Alloy
prometheus.remote_write "sink" {
  endpoint {
    url = "https://alloy-sink.lgtm.internal/api/v1/push"
    
    headers = {
      "X-Source-Cluster" = "${CLUSTER_NAME}",
      "X-Application" = "${APPLICATION_NAME}",
    }
    
    basic_auth {
      username = "${ALLOY_USERNAME}"
      password = "${ALLOY_PASSWORD}"
    }
  }
  
  wal {
    truncate_frequency = "2h"
    min_keepalive_time = "5m"
    max_keepalive_time = "8h"
  }
  
  queue_config {
    capacity = 10000
    max_shards = 50
    batch_send_deadline = "5s"
  }
}

// Log Collection
loki.source.kubernetes "app_logs" {
  targets = discovery.kubernetes.pods.targets
  forward_to = [loki.process.add_labels.receiver]
}

// Process and enrich logs
loki.process "add_labels" {
  forward_to = [loki.write.sink.receiver]
  
  stage.json {
    expressions = {
      level = "level",
      timestamp = "timestamp",
      message = "message",
    }
  }
  
  stage.labels {
    values = {
      level = "",
      environment = "${ENVIRONMENT}",
      application = "${APPLICATION_NAME}",
      cluster = "${CLUSTER_NAME}",
    }
  }
  
  // Drop debug logs in production
  stage.match {
    selector = '{level="debug"} |= ""'
    action = "drop"
    drop_counter_reason = "debug_logs_filtered"
  }
  
  // Sample info logs (keep 1 in 10)
  stage.sampling {
    rate = 0.1
    selector = '{level="info"}'
  }
}

// Remote write logs to Sink Alloy
loki.write "sink" {
  endpoint {
    url = "https://alloy-sink.lgtm.internal/loki/api/v1/push"
    
    headers = {
      "X-Source-Cluster" = "${CLUSTER_NAME}",
      "X-Application" = "${APPLICATION_NAME}",
    }
    
    basic_auth {
      username = "${ALLOY_USERNAME}"
      password = "${ALLOY_PASSWORD}"
    }
  }
}

// OpenTelemetry Traces Collection
otelcol.receiver.otlp "app_traces" {
  grpc {
    endpoint = "0.0.0.0:4317"
  }
  
  http {
    endpoint = "0.0.0.0:4318"
  }
  
  output {
    traces = [otelcol.processor.batch.default.input]
  }
}

// Batch and sample traces
otelcol.processor.batch "default" {
  output {
    traces = [otelcol.processor.probabilistic_sampler.default.input]
  }
}

otelcol.processor.probabilistic_sampler "default" {
  sampling_percentage = 1.0  // 1% sampling
  
  output {
    traces = [otelcol.exporter.otlp.sink.input]
  }
}

// Export traces to Sink Alloy
otelcol.exporter.otlp "sink" {
  client {
    endpoint = "https://alloy-sink.lgtm.internal:4317"
    
    headers = {
      "X-Source-Cluster" = "${CLUSTER_NAME}",
      "X-Application" = "${APPLICATION_NAME}",
    }
    
    auth = otelcol.auth.basic.default.handler
  }
}

otelcol.auth.basic "default" {
  username = "${ALLOY_USERNAME}"
  password = "${ALLOY_PASSWORD}"
}
```

### 2.3 Sink Alloy Agent Configuration

```alloy
// Sink Alloy Agent Configuration
logging {
  level = "info"
  format = "json"
}

// Receive metrics from Source Agents
prometheus.receive_http "source_metrics" {
  http {
    listen_address = "0.0.0.0"
    listen_port = 9090
  }
  
  forward_to = [prometheus.relabel.validate_source.receiver]
}

// Validate and route metrics
prometheus.relabel "validate_source" {
  forward_to = [prometheus.remote_write.mimir.receiver]
  
  // Ensure required labels are present
  rule {
    source_labels = ["environment"]
    regex = "(dev|staging|prod)"
    action = "keep"
  }
  
  rule {
    source_labels = ["application"]
    regex = ".+"
    action = "keep"
  }
  
  // Add ingestion timestamp
  rule {
    replacement = "{{ .Timestamp }}"
    target_label = "__tmp_ingestion_time"
  }
}

// Forward to Mimir
prometheus.remote_write "mimir" {
  endpoint {
    url = "http://mimir-gateway.lgtm.svc.cluster.local/api/v1/push"
  }
}

// Receive logs from Source Agents
loki.source.api "source_logs" {
  http {
    listen_address = "0.0.0.0"
    listen_port = 3100
  }
  
  forward_to = [loki.process.validate_source.receiver]
}

// Validate and route logs
loki.process "validate_source" {
  forward_to = [loki.write.loki.receiver]
  
  stage.match {
    selector = '{environment=""}'
    action = "drop"
    drop_counter_reason = "missing_environment_label"
  }
  
  stage.match {
    selector = '{application=""}'
    action = "drop"
    drop_counter_reason = "missing_application_label"
  }
  
  // Add ingestion metadata
  stage.labels {
    values = {
      __tmp_ingestion_time = "{{ .Timestamp }}",
    }
  }
}

// Forward to Loki
loki.write "loki" {
  endpoint {
    url = "http://loki-gateway.lgtm.svc.cluster.local/loki/api/v1/push"
  }
}

// Receive traces from Source Agents
otelcol.receiver.otlp "source_traces" {
  grpc {
    endpoint = "0.0.0.0:4317"
  }
  
  http {
    endpoint = "0.0.0.0:4318"
  }
  
  output {
    traces = [otelcol.processor.attributes.validate_source.input]
  }
}

// Validate trace attributes
otelcol.processor.attributes "validate_source" {
  action {
    key = "environment"
    action = "upsert"
    from_attribute = "environment"
  }
  
  action {
    key = "application"
    action = "upsert"
    from_attribute = "application"
  }
  
  output {
    traces = [otelcol.exporter.otlp.tempo.input]
  }
}

// Forward to Tempo
otelcol.exporter.otlp "tempo" {
  client {
    endpoint = "http://tempo-distributor.lgtm.svc.cluster.local:4317"
    tls {
      insecure = true
    }
  }
}
```

## 3. Application Onboarding Documentation

### 3.1 Prerequisites Checklist

Before onboarding an application:
- [ ] Application exposes Prometheus metrics on `/metrics` endpoint
- [ ] Application implements structured logging (JSON preferred)
- [ ] Application supports OpenTelemetry tracing (optional but recommended)
- [ ] Required Azure resources are provisioned
- [ ] Network connectivity is established between source and sink clusters

### 3.2 Step-by-Step Onboarding Guide

#### Step 1: Generate Application-Specific Configuration

```bash
#!/bin/bash
# generate-alloy-config.sh

APPLICATION_NAME="$1"
ENVIRONMENT="$2"
CLUSTER_NAME="$3"
NAMESPACE="$4"

if [[ -z "$APPLICATION_NAME" || -z "$ENVIRONMENT" || -z "$CLUSTER_NAME" || -z "$NAMESPACE" ]]; then
  echo "Usage: $0 <app-name> <environment> <cluster-name> <namespace>"
  exit 1
fi

# Create application-specific directory
mkdir -p "configs/${APPLICATION_NAME}-${ENVIRONMENT}"

# Generate config from template
envsubst < templates/source-alloy-config.alloy > "configs/${APPLICATION_NAME}-${ENVIRONMENT}/config.alloy"

# Generate Kubernetes manifests
envsubst < templates/alloy-daemonset.yaml > "configs/${APPLICATION_NAME}-${ENVIRONMENT}/daemonset.yaml"

echo "Generated configuration for ${APPLICATION_NAME} in ${ENVIRONMENT}"
echo "Files created in: configs/${APPLICATION_NAME}-${ENVIRONMENT}/"
```

#### Step 2: Deploy Source Alloy Agent

```yaml
# alloy-daemonset.yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: alloy-${APPLICATION_NAME}
  namespace: ${APPLICATION_NAMESPACE}
  labels:
    app.kubernetes.io/name: alloy
    app.kubernetes.io/instance: ${APPLICATION_NAME}
    app.kubernetes.io/component: source-agent
spec:
  selector:
    matchLabels:
      app.kubernetes.io/name: alloy
      app.kubernetes.io/instance: ${APPLICATION_NAME}
  template:
    metadata:
      labels:
        app.kubernetes.io/name: alloy
        app.kubernetes.io/instance: ${APPLICATION_NAME}
    spec:
      serviceAccountName: alloy-${APPLICATION_NAME}
      containers:
      - name: alloy
        image: grafana/alloy:v1.0.0
        args:
        - run
        - /etc/alloy/config.alloy
        - --storage.path=/tmp/alloy
        - --server.http.listen-addr=0.0.0.0:12345
        - --cluster.enabled=false
        env:
        - name: HOSTNAME
          valueFrom:
            fieldRef:
              fieldPath: spec.nodeName
        - name: ENVIRONMENT
          value: "${ENVIRONMENT}"
        - name: APPLICATION_NAME
          value: "${APPLICATION_NAME}"
        - name: CLUSTER_NAME
          value: "${CLUSTER_NAME}"
        - name: APPLICATION_NAMESPACE
          value: "${APPLICATION_NAMESPACE}"
        envFrom:
        - secretRef:
            name: alloy-credentials
        ports:
        - containerPort: 12345
          name: http-metrics
        - containerPort: 4317
          name: otlp-grpc
        - containerPort: 4318
          name: otlp-http
        volumeMounts:
        - name: config
          mountPath: /etc/alloy
        - name: varlog
          mountPath: /var/log
          readOnly: true
        - name: varlibdockercontainers
          mountPath: /var/lib/docker/containers
          readOnly: true
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
          limits:
            cpu: 500m
            memory: 512Mi
      volumes:
      - name: config
        configMap:
          name: alloy-config-${APPLICATION_NAME}
      - name: varlog
        hostPath:
          path: /var/log
      - name: varlibdockercontainers
        hostPath:
          path: /var/lib/docker/containers
      tolerations:
      - operator: Exists
        effect: NoSchedule
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: alloy-${APPLICATION_NAME}
  namespace: ${APPLICATION_NAMESPACE}
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: alloy-${APPLICATION_NAME}
rules:
- apiGroups: [""]
  resources: ["nodes", "nodes/metrics", "services", "endpoints", "pods"]
  verbs: ["get", "list", "watch"]
- apiGroups: [""]
  resources: ["configmaps"]
  verbs: ["get"]
- apiGroups: ["networking.k8s.io"]
  resources: ["ingresses"]
  verbs: ["get", "list", "watch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: alloy-${APPLICATION_NAME}
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: alloy-${APPLICATION_NAME}
subjects:
- kind: ServiceAccount
  name: alloy-${APPLICATION_NAME}
  namespace: ${APPLICATION_NAMESPACE}
```

#### Step 3: Application Instrumentation Requirements

```yaml
# application-deployment.yaml (example annotations)
apiVersion: apps/v1
kind: Deployment
metadata:
  name: sample-app
  namespace: ${APPLICATION_NAMESPACE}
spec:
  template:
    metadata:
      annotations:
        # Prometheus scraping annotations
        prometheus.io/scrape: "true"
        prometheus.io/port: "8080"
        prometheus.io/path: "/metrics"
        
        # Log collection annotations
        loki.io/scrape: "true"
        
        # Tracing annotations (if supported)
        tracing.io/enabled: "true"
        tracing.io/port: "4317"
    spec:
      containers:
      - name: app
        image: sample-app:latest
        ports:
        - containerPort: 8080
          name: http
        - containerPort: 4317
          name: otlp-grpc
        env:
        - name: OTEL_EXPORTER_OTLP_ENDPOINT
          value: "http://localhost:4317"
        - name: OTEL_SERVICE_NAME
          value: "${APPLICATION_NAME}"
        - name: OTEL_RESOURCE_ATTRIBUTES
          value: "environment=${ENVIRONMENT},application=${APPLICATION_NAME}"
```

### 3.3 Validation and Testing

```bash
#!/bin/bash
# validate-onboarding.sh

APPLICATION_NAME="$1"
ENVIRONMENT="$2"
NAMESPACE="$3"

echo "Validating onboarding for ${APPLICATION_NAME} in ${ENVIRONMENT}..."

# Check if Alloy agent is running
kubectl get daemonset alloy-${APPLICATION_NAME} -n ${NAMESPACE}

# Check metrics collection
kubectl port-forward -n ${NAMESPACE} daemonset/alloy-${APPLICATION_NAME} 12345:12345 &
PORT_FORWARD_PID=$!

sleep 5

# Verify Alloy is scraping metrics
curl -s http://localhost:12345/metrics | grep -E "(prometheus_sd_discovered_targets|loki_source_entries_total)"

# Check if data is reaching LGTM stack
echo "Checking Grafana for ${APPLICATION_NAME} data..."

# Clean up
kill $PORT_FORWARD_PID

echo "Validation complete. Check Grafana dashboards for data visualization."
```

## 4. Alerting Strategy

### 4.1 Change Management Minimization Approach

#### Dashboard-First Alerting
Instead of creating alerts for every threshold, use dashboard panels with threshold visualization:

```json
{
  "alert": {
    "conditions": [],
    "executionErrorState": "alerting",
    "for": "5m",
    "frequency": "10s",
    "handler": 1,
    "name": "High Error Rate - ${application}",
    "noDataState": "no_data"
  },
  "targets": [
    {
      "expr": "rate(http_requests_errors_total{application=\"${application}\"}[5m]) / rate(http_requests_total{application=\"${application}\"}[5m]) > 0.05",
      "legendFormat": "Error Rate"
    }
  ],
  "thresholds": [
    {
      "colorMode": "critical",
      "fill": true,
      "line": true,
      "op": "gt",
      "value": 0.05
    }
  ]
}
```

#### Parameterized Rule Groups
```yaml
# alerting-rules-template.yaml
groups:
  - name: application-sli-alerts
    interval: 30s
    rules:
      - alert: HighErrorRate
        expr: |
          (
            rate(http_requests_errors_total{application=~"{{ .Values.application_regex }}"}[5m]) 
            / 
            rate(http_requests_total{application=~"{{ .Values.application_regex }}"}[5m])
          ) > {{ .Values.error_rate_threshold | default 0.05 }}
        for: {{ .Values.error_rate_duration | default "5m" }}
        labels:
          severity: warning
          tier: "{{ .Values.tier | default "tier2" }}"
          team: "{{ .Values.team }}"
        annotations:
          summary: "High error rate detected for {{ .Values.application_name }}"
          description: |
            Application {{ $labels.application }} has an error rate of {{ $value | humanizePercentage }}
            which is above the threshold of {{ .Values.error_rate_threshold | humanizePercentage }}.
            
      - alert: HighLatency
        expr: |
          histogram_quantile(0.95, 
            rate(http_request_duration_seconds_bucket{application=~"{{ .Values.application_regex }}"}[5m])
          ) > {{ .Values.latency_threshold | default 0.5 }}
        for: {{ .Values.latency_duration | default "5m" }}
        labels:
          severity: warning
          tier: "{{ .Values.tier | default "tier2" }}"
          team: "{{ .Values.team }}"
        annotations:
          summary: "High latency detected for {{ .Values.application_name }}"
          description: |
            Application {{ $labels.application }} has a 95th percentile latency of {{ $value }}s
            which is above the threshold of {{ .Values.latency_threshold }}s.
```

### 4.2 Alert Categories and Rules

#### Infrastructure-Level Alerts
```yaml
groups:
  - name: infrastructure-alerts
    rules:
      - alert: NodeMemoryPressure
        expr: node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes < 0.1
        for: 5m
        labels:
          severity: warning
          category: infrastructure
        annotations:
          summary: "Node memory pressure detected"
          
      - alert: PodCrashLooping
        expr: rate(kube_pod_container_status_restarts_total[15m]) > 0
        for: 5m
        labels:
          severity: critical
          category: infrastructure
        annotations:
          summary: "Pod is crash looping"
          
      - alert: PersistentVolumeUsageHigh
        expr: kubelet_volume_stats_used_bytes / kubelet_volume_stats_capacity_bytes > 0.9
        for: 5m
        labels:
          severity: warning
          category: infrastructure
        annotations:
          summary: "Persistent volume usage is high"
```

#### LGTM Stack Health Alerts
```yaml
groups:
  - name: lgtm-health-alerts
    rules:
      - alert: MimirIngesterDown
        expr: up{job="mimir-ingester"} == 0
        for: 2m
        labels:
          severity: critical
          category: lgtm-health
        annotations:
          summary: "Mimir ingester is down"
          
      - alert: LokiHighCardinality
        expr: loki_ingester_streams > 100000
        for: 10m
        labels:
          severity: warning
          category: lgtm-health
        annotations:
          summary: "Loki ingester has high stream cardinality"
          
      - alert: TempoIngesterDiskUsageHigh
        expr: node_filesystem_avail_bytes{mountpoint="/tempo-data"} / node_filesystem_size_bytes{mountpoint="/tempo-data"} < 0.1
        for: 5m
        labels:
          severity: critical
          category: lgtm-health
        annotations:
          summary: "Tempo ingester disk usage is high"
```

#### Application-Level Alert Templates
```yaml
groups:
  - name: application-golden-signals
    rules:
      - alert: ApplicationDown
        expr: up{job=~".*app.*"} == 0
        for: 1m
        labels:
          severity: critical
          category: availability
        annotations:
          summary: "Application {{ $labels.job }} is down"
          
      - alert: ApplicationHighErrorRate
        expr: |
          (
            rate(http_requests_errors_total[5m]) 
            / 
            rate(http_requests_total[5m])
          ) > 0.05
        for: 5m
        labels:
          severity: warning
          category: errors
        annotations:
          summary: "High error rate for {{ $labels.application }}"
          
      - alert: ApplicationHighLatency
        expr: |
          histogram_quantile(0.95, 
            rate(http_request_duration_seconds_bucket[5m])
          ) > 0.5
        for: 5m
        labels:
          severity: warning
          category: latency
        annotations:
          summary: "High latency for {{ $labels.application }}"
          
      - alert: ApplicationLowThroughput
        expr: rate(http_requests_total[5m]) < 10
        for: 10m
        labels:
          severity: warning
          category: saturation
        annotations:
          summary: "Low throughput for {{ $labels.application }}"
```

### 4.3 Alert Routing and Notification

```yaml
# alertmanager-config.yaml
global:
  smtp_smarthost: 'smtp.company.com:587'
  smtp_from: 'alerts@company.com'

route:
  group_by: ['alertname', 'severity', 'tier']
  group_wait: 30s
  group_interval: 5m
  repeat_interval: 12h
  receiver: 'default-receiver'
  routes:
    # Critical infrastructure alerts
    - match:
        severity: critical
        category: infrastructure
      receiver: 'infrastructure-team'
      group_wait: 10s
      repeat_interval: 5m
      
    # LGTM stack health
    - match:
        category: lgtm-health
      receiver: 'platform-team'
      group_wait: 30s
      
    # Application alerts by tier
    - match:
        tier: tier1
      receiver: 'tier1-oncall'
      group_wait: 10s
      repeat_interval: 30m
      
    - match:
        tier: tier2
      receiver: 'tier2-team'
      group_wait: 2m
      repeat_interval: 4h
      
    - match:
        tier: tier3
      receiver: 'tier3-team'
      group_wait: 5m
      repeat_interval: 12h

receivers:
  - name: 'default-receiver'
    email_configs:
    - to: 'platform-team@company.com'
      subject: 'LGTM Alert: {{ .GroupLabels.alertname }}'
      
  - name: 'infrastructure-team'
    pagerduty_configs:
    - service_key: 'infrastructure-pagerduty-key'
      description: '{{ .GroupLabels.alertname }}: {{ .CommonAnnotations.summary }}'
      
  - name: 'platform-team'
    slack_configs:
    - api_url: 'https://hooks.slack.com/services/platform-alerts'
      channel: '#platform-alerts'
      title: 'LGTM Stack Alert'
      text: '{{ range .Alerts }}{{ .Annotations.summary }}{{ end }}'
      
  - name: 'tier1-oncall'
    pagerduty_configs:
    - service_key: 'tier1-pagerduty-key'
      description: 'CRITICAL: {{ .CommonAnnotations.summary }}'
    slack_configs:
    - api_url: 'https://hooks.slack.com/services/tier1-alerts'
      channel: '#tier1-oncall'
      
  - name: 'tier2-team'
    slack_configs:
    - api_url: 'https://hooks.slack.com/services/tier2-alerts'
      channel: '#tier2-alerts'
      
  - name: 'tier3-team'
    email_configs:
    - to: 'tier3-team@company.com'
      subject: 'Tier 3 Alert: {{ .GroupLabels.alertname }}'

inhibit_rules:
  - source_match:
      severity: 'critical'
    target_match:
      severity: 'warning'
    equal: ['alertname', 'application']
```

## 5. Project Planning and Execution

### 5.1 Epic Breakdown

#### Epic 1: Infrastructure Foundation
**Objective**: Establish the core AKS infrastructure and LGTM stack deployment

**Duration**: 4 weeks  
**Dependencies**: Azure subscription, networking setup  
**Team Size**: 5 engineers

#### Epic 2: Alloy Agent Architecture
**Objective**: Implement dual-agent Grafana Alloy architecture

**Duration**: 3 weeks  
**Dependencies**: Epic 1 completion  
**Team Size**: 3 engineers

#### Epic 3: Application Onboarding Framework
**Objective**: Create standardized onboarding process and tooling

**Duration**: 2 weeks  
**Dependencies**: Epic 2 completion  
**Team Size**: 2 engineers

#### Epic 4: Observability and Alerting
**Objective**: Implement comprehensive monitoring and alerting

**Duration**: 3 weeks  
**Dependencies**: Epic 1, Epic 2 completion  
**Team Size**: 4 engineers

#### Epic 5: Test Application Integration
**Objective**: Onboard first test application and validate end-to-end flow

**Duration**: 1 week  
**Dependencies**: All previous epics  
**Team Size**: 2 engineers

### 5.2 Detailed Issue Breakdown

#### Epic 1: Infrastructure Foundation

**Issue 1.1: AKS Cluster Provisioning**
```
As a DevOps engineer, I want to provision a production-ready AKS cluster for the LGTM stack
So that we have a scalable and highly available platform for observability services

Acceptance Criteria:
- [ ] AKS cluster provisioned with multi-zone node pools
- [ ] LGTM node pool with appropriate sizing (Standard_D16s_v3)
- [ ] Alloy sink node pool configured with taints
- [ ] Azure CNI networking configured
- [ ] Azure AD integration enabled
- [ ] RBAC policies configured
- [ ] Pod Security Standards implemented
- [ ] Network policies configured for security
- [ ] Monitoring and logging enabled for cluster
```

**Issue 1.2: Storage Infrastructure Setup**
```
As a platform engineer, I want to configure persistent storage for LGTM components
So that we can reliably store metrics, logs, and traces with appropriate retention

Acceptance Criteria:
- [ ] Azure Blob Storage accounts created for long-term storage
- [ ] Storage classes configured for different performance tiers
- [ ] Persistent volumes provisioned for LGTM components
- [ ] Backup and recovery procedures documented
- [ ] Storage monitoring and alerting configured
- [ ] Lifecycle policies configured for cost optimization
```

**Issue 1.3: Networking and Security Configuration**
```
As a security engineer, I want to configure network security for the LGTM platform
So that we maintain security compliance while enabling observability data flow

Acceptance Criteria:
- [ ] Network security groups configured
- [ ] Private endpoints configured for Azure services
- [ ] TLS certificates provisioned and managed
- [ ] Ingress controllers configured with authentication
- [ ] Service mesh integration (if applicable)
- [ ] Network policies for pod-to-pod communication
- [ ] Firewall rules for cross-cluster communication
```

**Issue 1.4: LGTM Stack Deployment**
```
As a platform engineer, I want to deploy the core LGTM stack components
So that we have a functioning observability platform

Acceptance Criteria:
- [ ] Mimir deployed with proper sizing and configuration
- [ ] Loki deployed with retention policies configured
- [ ] Tempo deployed with sampling configuration
- [ ] Grafana deployed with authentication integration
- [ ] All components are highly available (multi-replica)
- [ ] Health checks and readiness probes configured
- [ ] Inter-component communication verified
- [ ] Basic dashboards imported and functional
```

#### Epic 2: Alloy Agent Architecture

**Issue 2.1: Source Alloy Agent Template Development**
```
As a DevOps engineer, I want to create reusable Alloy agent configurations
So that applications can be onboarded consistently with proper telemetry collection

Acceptance Criteria:
- [ ] Source agent configuration template created
- [ ] Environment variable substitution implemented
- [ ] Kubernetes service discovery configured
- [ ] Metrics collection and filtering rules defined
- [ ] Log collection and processing pipelines created
- [ ] Trace collection and sampling configured
- [ ] Local buffering and retry logic implemented
- [ ] Configuration validation scripts created
```

**Issue 2.2: Sink Alloy Agent Implementation**
```
As a platform engineer, I want to deploy centralized Alloy agents on the LGTM cluster
So that we can validate, process, and route telemetry data efficiently

Acceptance Criteria:
- [ ] Sink agent deployment manifests created
- [ ] Multi-replica configuration for high availability
- [ ] Data validation and filtering rules implemented
- [ ] Load balancing configuration for incoming data
- [ ] Monitoring and alerting for sink agents
- [ ] Performance testing completed
- [ ] Failure scenarios tested and documented
```

**Issue 2.3: Inter-Agent Communication Security**
```
As a security engineer, I want to secure communication between source and sink agents
So that telemetry data is transmitted securely across clusters

Acceptance Criteria:
- [ ] TLS encryption configured for all agent communication
- [ ] Authentication mechanisms implemented
- [ ] Certificate management automated
- [ ] Network policies configured
- [ ] Security scanning completed
- [ ] Compliance requirements verified
```

#### Epic 3: Application Onboarding Framework

**Issue 3.1: Onboarding Automation Tools**
```
As a DevOps engineer, I want automated tools for application onboarding
So that teams can quickly and consistently integrate with the observability platform

Acceptance Criteria:
- [ ] Configuration generation scripts created
- [ ] Kubernetes manifest templates developed
- [ ] Validation and testing scripts implemented
- [ ] Documentation and runbooks created
- [ ] Self-service portal (optional) designed
- [ ] Integration with CI/CD pipelines documented
```

**Issue 3.2: Application Instrumentation Guidelines**
```
As a developer, I want clear guidelines for instrumenting my application
So that I can properly expose metrics, logs, and traces for monitoring

Acceptance Criteria:
- [ ] Instrumentation best practices documented
- [ ] Code examples for popular frameworks provided
- [ ] Metric naming conventions established
- [ ] Log format and structured logging guidelines created
- [ ] Tracing implementation examples provided
- [ ] Performance impact guidelines documented
```

#### Epic 4: Observability and Alerting

**Issue 4.1: Dashboard Development**
```
As an SRE, I want comprehensive dashboards for monitoring applications and infrastructure
So that I can quickly identify and troubleshoot issues

Acceptance Criteria:
- [ ] Infrastructure monitoring dashboards created
- [ ] Application SLI/SLO dashboards developed
- [ ] LGTM stack health dashboards implemented
- [ ] Cross-service tracing dashboards created
- [ ] Capacity planning dashboards developed
- [ ] Custom dashboard templates created
- [ ] Dashboard as code implemented
```

**Issue 4.2: Alerting Rules Implementation**
```
As an SRE, I want intelligent alerting rules that minimize noise
So that I can focus on actionable incidents while maintaining coverage

Acceptance Criteria:
- [ ] Parameterized alerting rules created
- [ ] Alert severity levels defined
- [ ] Notification routing configured
- [ ] Alert fatigue prevention measures implemented
- [ ] Runbook automation integrated
- [ ] Alert testing procedures established
```

#### Epic 5: Test Application Integration

**Issue 5.1: Test Application Onboarding**
```
As a DevOps engineer, I want to onboard a test application to validate the platform
So that we can verify end-to-end functionality before production rollout

Acceptance Criteria:
- [ ] Test application selected and deployed
- [ ] Source Alloy agent configured and deployed
- [ ] Metrics, logs, and traces flowing to LGTM stack
- [ ] Dashboards displaying application data
- [ ] Alerts configured and tested
- [ ] Performance benchmarks established
- [ ] Documentation updated with lessons learned
```

### 5.3 Prioritized Backlog and Timeline

#### Q2 2025 (June Focus - Test Application Onboarding)

**Week 1-2 (June 2-13)**
- Issue 1.1: AKS Cluster Provisioning (5 engineers)
- Issue 1.2: Storage Infrastructure Setup (2 engineers, parallel)

**Week 3-4 (June 16-27)**
- Issue 1.3: Networking and Security Configuration (3 engineers)
- Issue 1.4: LGTM Stack Deployment (5 engineers)

**Week 4 (June 23-27)**
- Issue 5.1: Test Application Onboarding (2 engineers)
- **Milestone: Test application successfully onboarded by end of June**

#### Q3 2025 (July-September)

**July (Weeks 1-4)**
- Issue 2.1: Source Alloy Agent Template Development (3 engineers)
- Issue 2.2: Sink Alloy Agent Implementation (3 engineers, parallel)
- Issue 2.3: Inter-Agent Communication Security (2 engineers)

**August (Weeks 1-4)**
- Issue 3.1: Onboarding Automation Tools (2 engineers)
- Issue 3.2: Application Instrumentation Guidelines (2 engineers, parallel)
- Issue 4.1: Dashboard Development (4 engineers)

**September (Weeks 1-4)**
- Issue 4.2: Alerting Rules Implementation (4 engineers)
- Production readiness testing (5 engineers)
- Documentation finalization (2 engineers)

#### Q4 2025 (October-December)

**October-December**
- Production application onboarding (rolling)
- Platform optimization and tuning
- Additional feature development based on feedback
- Capacity scaling as needed

### 5.4 Resource Allocation and Dependencies

#### Team Composition (5 Engineers)
- **Lead Platform Engineer (1)**: Architecture decisions, complex configurations
- **DevOps Engineers (2)**: Infrastructure provisioning, deployment automation
- **SRE (1)**: Monitoring, alerting, performance optimization
- **Security Engineer (1)**: Security configurations, compliance validation

#### Critical Dependencies
1. **Azure Subscription and Permissions**: Required before week 1
2. **Network Connectivity**: Between source and sink clusters
3. **Certificate Authority**: For TLS certificate generation
4. **Test Application**: Identified and available for onboarding
5. **Monitoring Integration**: Existing monitoring systems integration points

#### Risk Mitigation Strategies

**High-Risk Items:**
1. **AKS Cluster Sizing**: Risk of under/over-provisioning
   - *Mitigation*: Start with recommended sizing, implement auto-scaling, monitor and adjust
   
2. **Inter-Cluster Networking**: Complex network routing between clusters
   - *Mitigation*: Implement network testing early, have networking expertise available
   
3. **Data Volume Estimation**: Unknown telemetry data volumes
   - *Mitigation*: Implement sampling and filtering, monitor ingestion rates, plan for scaling

4. **Application Team Adoption**: Resistance to instrumentation changes
   - *Mitigation*: Provide clear documentation, offer hands-on support, demonstrate value

**Medium-Risk Items:**
1. **LGTM Stack Configuration Complexity**: Learning curve for new technology
   - *Mitigation*: Allocate time for learning, leverage community resources, start simple
   
2. **Alert Fatigue**: Too many or irrelevant alerts
   - *Mitigation*: Start with conservative alerting, iterate based on feedback

3. **Performance Impact**: Alloy agents affecting application performance
   - *Mitigation*: Implement resource limits, monitor impact, optimize configurations

### 5.5 Success Metrics and KPIs

#### Technical Metrics
- **Platform Availability**: >99.9% uptime for LGTM stack
- **Data Ingestion Success Rate**: >99.5% of telemetry data successfully ingested
- **Query Performance**: <5s for 95th percentile dashboard queries
- **Alert Accuracy**: <5% false positive rate for critical alerts
- **Onboarding Time**: <2 hours for new application integration

#### Business Metrics
- **Mean Time to Detection (MTTD)**: <2 minutes for critical issues
- **Mean Time to Resolution (MTTR)**: 50% reduction from baseline
- **Application Coverage**: 80% of Tier-1 applications onboarded by Q4
- **Team Satisfaction**: >8/10 satisfaction score from development teams
- **Cost Efficiency**: Observability costs <2% of total infrastructure spend

#### Operational Metrics
- **Change Management Overhead**: <10 change requests per month for alerting
- **On-call Burden**: <2 false alarms per week
- **Documentation Coverage**: 100% of procedures documented
- **Training Completion**: 100% of team members trained on platform

### 5.6 Governance and Change Management

#### Change Approval Process
1. **Infrastructure Changes**: Require approval from platform team lead
2. **Alerting Changes**: Automated through parameterized templates where possible
3. **Security Changes**: Require security team review
4. **Application Onboarding**: Self-service with automated validation

#### Documentation Requirements
- **Architecture Decision Records (ADRs)**: For major design decisions
- **Runbooks**: For operational procedures
- **API Documentation**: For integration endpoints
- **Training Materials**: For team onboarding

#### Quality Gates
- **Code Reviews**: Required for all configuration changes
- **Testing**: Automated testing for configuration templates
- **Security Scanning**: Regular vulnerability assessments
- **Performance Testing**: Load testing before major releases

This comprehensive implementation plan provides a structured approach to deploying a production-ready LGTM stack on AKS with scalable application onboarding capabilities. The dual-agent Alloy architecture ensures efficient telemetry collection while the phased approach minimizes risk and enables early value delivery through the test application onboarding by end of June.
