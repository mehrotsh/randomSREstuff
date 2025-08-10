# Application Observability Onboarding Request

**Application/Team Information:**
- **Application Name:** 
- **Team Name:** 
- **Primary Contact:** @username
- **Secondary Contact:** @username
- **Slack Channel/Teams:** 
- **GitLab Project URL:** 

---

## 📋 Application Architecture & Infrastructure

### Deployment Environment
- [ ] **Platform Type:**
  - [ ] Kubernetes (AKS/EKS/GKE)
  - [ ] Docker Swarm  
  - [ ] Bare Metal
  - [ ] Other: _________

- **Cluster Details:**
  - Cluster Name(s): 
  - Namespace(s): 
  - Node Count/Type: 
  - Resource Limits: CPU/Memory

- [ ] **Service Mesh:** 
  - [ ] None
  - [ ] Istio
  - [ ] Linkerd  
  - [ ] Consul Connect
  - [ ] Other: _________

- **Ingress/Load Balancer:** 
- **External Dependencies:** (databases, APIs, queues)

### Application Stack
- **Programming Languages:** 
- **Frameworks:** 
- **Architecture Pattern:**
  - [ ] Microservices
  - [ ] Monolithic
  - [ ] Serverless
  - [ ] Hybrid

---

## 🔍 Current Observability State

### Existing Monitoring
- [ ] **Current Tools:**
  - [ ] Prometheus
  - [ ] Grafana  
  - [ ] ELK Stack
  - [ ] Datadog
  - [ ] New Relic
  - [ ] None
  - [ ] Other: _________

- [ ] **Instrumentation:**
  - [ ] OpenTelemetry instrumented
  - [ ] Prometheus metrics exposed
  - [ ] Structured logging implemented
  - [ ] Distributed tracing enabled
  - [ ] Custom metrics in use

- **Existing Dashboards/Alerts:** (links if available)

---

## 🎯 Business Context & SLOs

### Critical Services & User Journeys
- **Most Critical Services:** (rank 1-5)
- **Key User Flows/Transactions:** 
- **Business Impact of Downtime:** 

### Performance Requirements
- **Current SLAs/SLOs:**
  - Availability: ___%
  - Latency P95: ___ms
  - Error Rate: ___%
  - Throughput: ___req/s

- **Traffic Patterns:**
  - [ ] Steady state
  - [ ] Seasonal spikes
  - [ ] Batch processing windows
  - [ ] Other: _________

---

## ⚙️ Technical Configuration

### Resource Constraints
- **Agent Resource Limits:**
  - CPU: ___m cores
  - Memory: ___Mi
  - Storage: ___Gi
- **Network Bandwidth:** ___Mbps available

### Security & Compliance
- [ ] **Data Sensitivity:**
  - [ ] Contains PII
  - [ ] Financial data
  - [ ] Healthcare data  
  - [ ] No sensitive data
  
- [ ] **Compliance Requirements:**
  - [ ] SOC2
  - [ ] HIPAA
  - [ ] GDPR
  - [ ] PCI-DSS
  - [ ] None
  - [ ] Other: _________

- **Network Restrictions:** (firewall rules, VPN requirements)
- **Authentication Method:** (service accounts, certificates)

### Data Volume & Retention
- **Estimated Daily Volume:**
  - Logs: ___GB/day
  - Metrics: ___samples/sec
  - Traces: ___traces/day
  
- **Retention Requirements:**
  - Logs: ___days
  - Metrics: ___days  
  - Traces: ___days

- [ ] **High Cardinality Concerns:**
  - [ ] User IDs in metrics
  - [ ] Dynamic labels
  - [ ] No concerns identified

---

## 🚨 Alerting & Operations

### Alert Configuration
- **Primary On-Call:** @username
- **Escalation Chain:** @team
- **Notification Channels:**
  - [ ] Email
  - [ ] Slack: #channel-name
  - [ ] PagerDuty
  - [ ] Microsoft Teams
  - [ ] Webhook: ___

- **Alert Preferences:**
  - [ ] Real-time alerts
  - [ ] Aggregated alerts (5min windows)
  - [ ] Business hours only
  - [ ] 24/7 monitoring

### Dashboard Requirements
- **Stakeholder Access:**
  - Developers: @team-dev
  - Operations: @team-ops  
  - Management: @team-leads
  
- [ ] **Integration Needs:**
  - [ ] Existing Grafana instance
  - [ ] Slack notifications
  - [ ] ITSM integration
  - [ ] Custom webhooks

---

## 🔧 Special Considerations

### Application-Specific Requirements
- **Custom Metrics/Events:** 
- **Batch Jobs/Cron:** 
- **Multi-tenancy:** 
- **Known High-Volume Endpoints:** 

### Deployment Pipeline
- [ ] **Deployment Strategy:**
  - [ ] Rolling updates
  - [ ] Blue/Green
  - [ ] Canary
  - [ ] GitOps (ArgoCD/Flux)

- **Environment Stages:** (dev, staging, prod)

---

## ✅ Checklist

### Pre-Onboarding
- [ ] Application architecture documented
- [ ] Resource allocation approved
- [ ] Security review completed
- [ ] Network connectivity verified

### Post-Onboarding  
- [ ] Alloy agent deployed and healthy
- [ ] Metrics flowing to Mimir
- [ ] Logs flowing to Loki
- [ ] Traces flowing to Tempo
- [ ] Dashboards created and shared
- [ ] Alerts configured and tested
- [ ] Team trained on platform usage

---

## 📋 Additional Information
<!-- Any additional context, special requirements, or questions -->

---

**Estimated Timeline:** ___weeks
**Priority Level:** 
- [ ] Critical (production down)
- [ ] High (new production app)  
- [ ] Medium (enhancement)
- [ ] Low (dev/test environment)

/label ~"observability-onboarding" ~"needs-review"
/assign @observability-team
/due 2025-08-23
