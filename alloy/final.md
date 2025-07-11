# Edge Alloy Agent Deployment Guide & Templates

## Overview
This guide provides standardized templates and configurations for deploying Grafana Alloy agents on application clusters to forward telemetry data to the central observability stack.

## Architecture
```
App Cluster 1-N
├── Edge Alloy Agent (DaemonSet)
│   ├── Logs Collection
│   ├── Metrics Collection  
│   └── Traces Collection
└── Applications
    ├── App A
    ├── App B
    └── App C
         ↓
Central Observability Cluster
├── Central Alloy Agent
├── Loki (Logs)
├── Mimir (Metrics)
└── Tempo (Traces)
```

## 1. Helm Chart Structure

```
alloy-edge-agent/
├── Chart.yaml
├── values.yaml
├── templates/
│   ├── configmap.yaml
│   ├── daemonset.yaml
│   ├── servicemonitor.yaml
│   ├── rbac.yaml
│   └── service.yaml
└── config/
    └── config.alloy.tpl
```

## 2. Helm Chart Templates

### Chart.yaml
```yaml
apiVersion: v2
name: alloy-edge-agent
description: Grafana Alloy Edge Agent for Application Telemetry
version: 1.0.0
appVersion: "v1.0.0"
```

### values.yaml
```yaml
# Cluster/Team identification
cluster:
  name: ""                    # Required: Cluster identifier
  environment: ""             # Required: dev/staging/prod
  team: ""                    # Required: Default team name

# Application identification (optional - can be extracted from annotations)
app:
  name: ""                    # Optional: Override app name (uses annotation if empty)
  team: ""                    # Optional: Override team name (uses cluster.team if empty)
  version: ""                 # Optional: Override app version (uses annotation if empty)
  component: ""               # Optional: Override component name (uses annotation if empty)

# Configuration mode
useExplicitConfig: false      # If true, uses app.* values; if false, extracts from annotations

# Central observability endpoint
central:
  endpoint: "https://central-alloy.observability.svc.cluster.local:12345"
  
# Alloy agent configuration
alloy:
  image:
    repository: grafana/alloy
    tag: "v1.0.0"
    pullPolicy: IfNotPresent
  
  resources:
    requests:
      cpu: 100m
      memory: 128Mi
    limits:
      cpu: 500m
      memory: 512Mi
  
  # Collection configuration
  collection:
    logs:
      enabled: true
      namespaces: []            # If empty, collects from all namespaces
      excludeNamespaces: 
        - kube-system
        - kube-public
    
    metrics:
      enabled: true
      scrapeInterval: 30s
      
    traces:
      enabled: true
      
# Custom labels to add to all telemetry
customLabels: {}

# Node selector for DaemonSet
nodeSelector: {}

# Tolerations for DaemonSet
tolerations: []

# Service configuration
service:
  type: ClusterIP
  port: 12345
```

### templates/configmap.yaml
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ include "alloy-edge-agent.fullname" . }}-config
  namespace: {{ .Release.Namespace }}
  labels:
    {{- include "alloy-edge-agent.labels" . | nindent 4 }}
data:
  config.alloy: |
    {{- include "alloy-edge-agent.config" . | nindent 4 }}
```

### templates/daemonset.yaml
```yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: {{ include "alloy-edge-agent.fullname" . }}
  namespace: {{ .Release.Namespace }}
  labels:
    {{- include "alloy-edge-agent.labels" . | nindent 4 }}
spec:
  selector:
    matchLabels:
      {{- include "alloy-edge-agent.selectorLabels" . | nindent 6 }}
  template:
    metadata:
      labels:
        {{- include "alloy-edge-agent.selectorLabels" . | nindent 8 }}
    spec:
      serviceAccountName: {{ include "alloy-edge-agent.fullname" . }}
      containers:
      - name: alloy
        image: "{{ .Values.alloy.image.repository }}:{{ .Values.alloy.image.tag }}"
        imagePullPolicy: {{ .Values.alloy.image.pullPolicy }}
        args:
          - run
          - /etc/alloy/config.alloy
          - --server.http.listen-addr=0.0.0.0:12345
        ports:
        - containerPort: 12345
          name: http
        resources:
          {{- toYaml .Values.alloy.resources | nindent 10 }}
        volumeMounts:
        - name: config
          mountPath: /etc/alloy
        - name: varlog
          mountPath: /var/log
          readOnly: true
        - name: varlibdockercontainers
          mountPath: /var/lib/docker/containers
          readOnly: true
        - name: etcmachineid
          mountPath: /etc/machine-id
          readOnly: true
      volumes:
      - name: config
        configMap:
          name: {{ include "alloy-edge-agent.fullname" . }}-config
      - name: varlog
        hostPath:
          path: /var/log
      - name: varlibdockercontainers
        hostPath:
          path: /var/lib/docker/containers
      - name: etcmachineid
        hostPath:
          path: /etc/machine-id
      {{- with .Values.nodeSelector }}
      nodeSelector:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with .Values.tolerations }}
      tolerations:
        {{- toYaml . | nindent 8 }}
      {{- end }}
```

### templates/rbac.yaml
```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: {{ include "alloy-edge-agent.fullname" . }}
  namespace: {{ .Release.Namespace }}
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: {{ include "alloy-edge-agent.fullname" . }}
rules:
- apiGroups: [""]
  resources: ["pods", "services", "endpoints", "nodes", "nodes/proxy"]
  verbs: ["get", "list", "watch"]
- apiGroups: [""]
  resources: ["configmaps"]
  verbs: ["get"]
- apiGroups: ["networking.k8s.io"]
  resources: ["ingresses"]
  verbs: ["get", "list", "watch"]
- apiGroups: ["extensions"]
  resources: ["ingresses"]
  verbs: ["get", "list", "watch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: {{ include "alloy-edge-agent.fullname" . }}
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: {{ include "alloy-edge-agent.fullname" . }}
subjects:
- kind: ServiceAccount
  name: {{ include "alloy-edge-agent.fullname" . }}
  namespace: {{ .Release.Namespace }}
```

## 3. Templated config.alloy

### config/config.alloy.tpl
```alloy
{{- define "alloy-edge-agent.config" }}
// Standard labels for all telemetry
local.file "labels" {
  content = <<-EOT
    app_name="{{ .Values.app.name }}"
    team="{{ .Values.app.team }}"
    environment="{{ .Values.app.environment }}"
    cluster="{{ .Values.app.cluster }}"
    {{- if .Values.app.version }}
    app_version="{{ .Values.app.version }}"
    {{- end }}
    {{- if .Values.app.component }}
    component="{{ .Values.app.component }}"
    {{- end }}
    {{- range $key, $value := .Values.customLabels }}
    {{ $key }}="{{ $value }}"
    {{- end }}
  EOT
}

{{- if .Values.collection.logs.enabled }}
// Logs collection
discovery.kubernetes "pods" {
  role = "pod"
  {{- if .Values.collection.logs.namespaces }}
  namespaces {
    names = [{{ range .Values.collection.logs.namespaces }}"{{ . }}",{{ end }}]
  }
  {{- end }}
}

discovery.relabel "pods" {
  targets = discovery.kubernetes.pods.targets
  
  // Drop unwanted namespaces
  rule {
    source_labels = ["__meta_kubernetes_namespace"]
    regex = "{{ join "|" .Values.collection.logs.excludeNamespaces }}"
    action = "drop"
  }
  
  // Add standard labels
  rule {
    target_label = "cluster"
    replacement = "{{ .Values.cluster.name }}"
  }
  
  rule {
    target_label = "environment"
    replacement = "{{ .Values.cluster.environment }}"
  }
  
  {{- if .Values.useExplicitConfig }}
  rule {
    target_label = "app_name"
    replacement = "{{ .Values.app.name }}"
  }
  
  rule {
    target_label = "team"
    replacement = "{{ or .Values.app.team .Values.cluster.team }}"
  }
  {{- else }}
  // Extract app info from annotations (preferred approach)
  rule {
    source_labels = ["__meta_kubernetes_pod_annotation_app_kubernetes_io_name"]
    target_label = "app_name"
    regex = "(.+)"
  }
  
  rule {
    source_labels = ["__meta_kubernetes_pod_annotation_app_kubernetes_io_managed_by"]
    target_label = "team"
    regex = "(.+)"
  }
  
  // Fallback to cluster team if no annotation
  rule {
    source_labels = ["team"]
    target_label = "team"
    regex = "^$"
    replacement = "{{ .Values.cluster.team }}"
  }
  {{- end }}
  
  // Extract pod info
  rule {
    source_labels = ["__meta_kubernetes_pod_name"]
    target_label = "pod"
  }
  
  rule {
    source_labels = ["__meta_kubernetes_namespace"]
    target_label = "namespace"
  }
  
  rule {
    source_labels = ["__meta_kubernetes_pod_container_name"]
    target_label = "container"
  }
  
  rule {
    source_labels = ["__meta_kubernetes_pod_annotation_app_kubernetes_io_name"]
    target_label = "app"
  }
  
  rule {
    source_labels = ["__meta_kubernetes_pod_annotation_app_kubernetes_io_version"]
    target_label = "version"
  }
  
  rule {
    source_labels = ["__meta_kubernetes_pod_uid", "__meta_kubernetes_pod_container_name"]
    target_label = "__path__"
    separator = "/"
    replacement = "/var/log/pods/*$1/*.log"
  }
}

loki.source.kubernetes "pods" {
  targets    = discovery.relabel.pods.output
  forward_to = [loki.process.pods.receiver]
}

loki.process "pods" {
  forward_to = [loki.write.central.receiver]
  
  stage.cri {}
  
  stage.labels {
    values = {
      app_name = "{{ .Values.app.name }}",
      team = "{{ .Values.app.team }}",
      environment = "{{ .Values.app.environment }}",
      cluster = "{{ .Values.app.cluster }}",
      {{- if .Values.app.version }}
      app_version = "{{ .Values.app.version }}",
      {{- end }}
      {{- if .Values.app.component }}
      component = "{{ .Values.app.component }}",
      {{- end }}
    }
  }
}

loki.write "central" {
  endpoint {
    url = "{{ .Values.central.endpoint }}/loki/api/v1/push"
  }
}
{{- end }}

{{- if .Values.collection.metrics.enabled }}
// Metrics collection
discovery.kubernetes "services" {
  role = "endpoints"
}

discovery.relabel "services" {
  targets = discovery.kubernetes.services.targets
  
  // Only scrape services with prometheus annotations
  rule {
    source_labels = ["__meta_kubernetes_service_annotation_prometheus_io_scrape"]
    regex = "true"
    action = "keep"
  }
  
  rule {
    source_labels = ["__meta_kubernetes_service_annotation_prometheus_io_path"]
    target_label = "__metrics_path__"
    regex = "(.+)"
  }
  
  rule {
    source_labels = ["__address__", "__meta_kubernetes_service_annotation_prometheus_io_port"]
    target_label = "__address__"
    regex = "([^:]+)(?::\\d+)?;(\\d+)"
    replacement = "$1:$2"
  }
  
  // Add standard labels
  rule {
    target_label = "app_name"
    replacement = "{{ .Values.app.name }}"
  }
  
  rule {
    target_label = "team"
    replacement = "{{ .Values.app.team }}"
  }
  
  rule {
    target_label = "environment"
    replacement = "{{ .Values.app.environment }}"
  }
  
  rule {
    target_label = "cluster"
    replacement = "{{ .Values.app.cluster }}"
  }
}

prometheus.scrape "services" {
  targets         = discovery.relabel.services.output
  forward_to      = [prometheus.relabel.services.receiver]
  scrape_interval = "{{ .Values.collection.metrics.scrapeInterval }}"
}

prometheus.relabel "services" {
  forward_to = [prometheus.remote_write.central.receiver]
  
  // Add standard labels to all metrics
  rule {
    target_label = "app_name"
    replacement = "{{ .Values.app.name }}"
  }
  
  rule {
    target_label = "team"
    replacement = "{{ .Values.app.team }}"
  }
  
  rule {
    target_label = "environment"
    replacement = "{{ .Values.app.environment }}"
  }
  
  rule {
    target_label = "cluster"
    replacement = "{{ .Values.app.cluster }}"
  }
}

prometheus.remote_write "central" {
  endpoint {
    url = "{{ .Values.central.endpoint }}/api/v1/push"
  }
}
{{- end }}

{{- if .Values.collection.traces.enabled }}
// Traces collection
otelcol.receiver.otlp "traces" {
  grpc {
    endpoint = "0.0.0.0:4317"
  }
  
  http {
    endpoint = "0.0.0.0:4318"
  }
  
  output {
    traces = [otelcol.processor.batch.traces.input]
  }
}

otelcol.processor.batch "traces" {
  output {
    traces = [otelcol.processor.resource.traces.input]
  }
}

otelcol.processor.resource "traces" {
  attributes {
    app_name = "{{ .Values.app.name }}"
    team = "{{ .Values.app.team }}"
    environment = "{{ .Values.app.environment }}"
    cluster = "{{ .Values.app.cluster }}"
    {{- if .Values.app.version }}
    app_version = "{{ .Values.app.version }}"
    {{- end }}
    {{- if .Values.app.component }}
    component = "{{ .Values.app.component }}"
    {{- end }}
  }
  
  output {
    traces = [otelcol.exporter.otlp.traces.input]
  }
}

otelcol.exporter.otlp "traces" {
  client {
    endpoint = "{{ .Values.central.endpoint }}"
  }
}
{{- end }}
{{- end }}
```

## 4. Required Information from App Teams

You're absolutely right! There are two approaches - let me clarify both:

### Approach 1: Minimal Configuration (Recommended)
App teams only provide cluster/team-level information, and we extract app-specific details from Kubernetes annotations:

```yaml
# app-values.yaml (Minimal approach)
cluster:
  name: "prod-us-east-1"           # Required: Cluster identifier
  environment: "production"       # Required: Environment (dev/staging/prod)
  team: "platform-team"           # Required: Default team (can be overridden by annotations)

# Override defaults if needed
collection:
  logs:
    namespaces: ["my-app-namespace"]  # Specific namespaces to monitor
  metrics:
    scrapeInterval: 15s               # Custom scrape interval

# Custom labels for your telemetry
customLabels:
  cost_center: "engineering"
  service_tier: "tier1"
```

### Approach 2: Explicit Configuration (Alternative)
App teams provide all information explicitly (useful when annotations are inconsistent):

```yaml
# app-values.yaml (Explicit approach)
app:
  name: "my-awesome-app"           # Required: Unique application name
  team: "platform-team"           # Required: Team/squad responsible
  environment: "production"       # Required: Environment (dev/staging/prod)
  version: "v1.2.3"              # Optional: Application version
  component: "api"               # Optional: Component name (api/worker/frontend)
  cluster: "prod-us-east-1"      # Required: Cluster identifier

# This approach ignores annotations and uses explicit config
useExplicitConfig: true
```

## Why Two Approaches?

**Annotation-Based (Recommended)**: 
- ✅ **Single source of truth**: App metadata lives with the app
- ✅ **Automatic discovery**: New apps automatically get monitored
- ✅ **Follows Kubernetes standards**: Uses standard `app.kubernetes.io` labels
- ✅ **Minimal configuration**: Teams only configure cluster-level settings
- ✅ **Per-app granularity**: Each service can have different metadata

**Explicit Configuration (Alternative)**:
- ✅ **Simple for teams**: Everything in one values file
- ✅ **Works with legacy apps**: No need to modify existing deployments
- ✅ **Centralized control**: All config in one place
- ❌ **Requires coordination**: Teams must update both app and monitoring config
- ❌ **Less flexible**: Same config applied to all apps in cluster

## 5. Deployment Instructions for App Teams
```bash
helm repo add observability https://charts.yourcompany.com/observability
helm repo update
```

### Step 2: Create Values File
Create `app-values.yaml` with your application-specific configuration.

### Step 3: Deploy
```bash
helm install alloy-agent observability/alloy-edge-agent \
  --namespace observability \
  --create-namespace \
  --values app-values.yaml
```

## 6. Application Requirements & Guidelines

### Prerequisites
1. **Kubernetes cluster** with RBAC enabled
2. **Network connectivity** to central observability cluster
3. **Namespace** for alloy agent deployment (recommend: `observability`)

### Application Annotation Requirements (Recommended Approach)

#### For All Applications
Applications should annotate their workloads with standard labels:
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  annotations:
    app.kubernetes.io/name: "my-app"           # Application name
    app.kubernetes.io/version: "v1.2.3"       # Application version
    app.kubernetes.io/component: "api"        # Component (api/worker/frontend)
    app.kubernetes.io/managed-by: "platform-team"  # Team responsible
    app.kubernetes.io/part-of: "ecommerce-platform"  # Optional: Service group
```

#### For Metrics Collection
Services must have prometheus scraping annotations:
```yaml
apiVersion: v1
kind: Service
metadata:
  annotations:
    prometheus.io/scrape: "true"
    prometheus.io/port: "8080"
    prometheus.io/path: "/metrics"
    # Standard app labels (inherited from deployment)
    app.kubernetes.io/name: "my-app"
    app.kubernetes.io/version: "v1.2.3"
```

#### Alternative: Explicit Configuration
If your applications don't use standard annotations, you can provide explicit configuration:
```yaml
# app-values.yaml
useExplicitConfig: true
app:
  name: "my-awesome-app"
  team: "platform-team"
  version: "v1.2.3"
  component: "api"
```

### Trace Configuration
Applications should send traces to the alloy agent:
```yaml
# Environment variables in your app
- name: OTEL_EXPORTER_OTLP_ENDPOINT
  value: "http://alloy-edge-agent.observability.svc.cluster.local:4318"
- name: OTEL_SERVICE_NAME
  value: "my-app"
- name: OTEL_RESOURCE_ATTRIBUTES
  value: "app.name=my-app,team=platform-team,environment=production"
```

## 7. Multi-App Support Strategy

### Namespace-Based Isolation
- Each application team deploys alloy agent in their own namespace
- Configure `collection.logs.namespaces` to monitor specific namespaces
- Use different service names to avoid conflicts

### Label-Based Filtering
- Use kubernetes labels to filter what gets collected
- Configure relabeling rules to add team/app identification
- Central configuration can route based on labels

### Resource Management
- Set appropriate resource limits for each alloy agent
- Monitor resource usage and adjust based on workload
- Use node selectors to control placement

## 8. Monitoring & Troubleshooting

### Health Checks
```yaml
# Add to your app-values.yaml
healthCheck:
  enabled: true
  endpoint: /health
  interval: 30s
```

### Common Issues
1. **Permission errors**: Ensure RBAC is correctly configured
2. **Network connectivity**: Test connection to central endpoint
3. **Resource limits**: Monitor memory/CPU usage
4. **Configuration errors**: Check alloy agent logs

### Debugging Commands
```bash
# Check alloy agent status
kubectl get pods -n observability

# View logs
kubectl logs -n observability -l app.kubernetes.io/name=alloy-edge-agent

# Check configuration
kubectl get configmap -n observability alloy-edge-agent-config -o yaml
```

## 9. Governance & Best Practices

### Mandatory Fields
- `app.name`: Unique identifier for the application
- `app.team`: Team responsible for the application
- `app.environment`: Environment designation
- `app.cluster`: Cluster identifier

### Naming Conventions
- Application names: lowercase, hyphenated (e.g., `user-service`)
- Team names: lowercase, hyphenated (e.g., `platform-team`)
- Environment names: standardized (dev/staging/prod)

### Label Cardinality
- Limit custom labels to prevent high cardinality
- Use consistent label names across applications
- Avoid using user IDs or request IDs as labels

### Security Considerations
- Use least privilege RBAC permissions
- Encrypt communication to central cluster
- Regularly update alloy agent images
- Monitor for sensitive data in logs

## 10. Onboarding Checklist

### For App Teams
- [ ] Review application annotation requirements
- [ ] Create `app-values.yaml` with required fields
- [ ] Test deployment in non-production environment
- [ ] Verify telemetry data appears in central dashboards
- [ ] Set up monitoring dashboards for your application
- [ ] Document any custom configurations in your repo

### For Platform Team
- [ ] Review application configuration for compliance
- [ ] Verify network connectivity from app cluster
- [ ] Check resource usage patterns
- [ ] Validate data appears in central LGTM stack
- [ ] Create initial dashboards for the application
- [ ] Provide access to observability tooling
