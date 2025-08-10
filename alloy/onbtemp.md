# Application Observability Onboarding Request

**Application/Team Information:**
- **Application Name:** 
- **Team Name:** 
- **Primary Contact:** @username
- **Secondary Contact:** @username
- **Teams Channel:** 
- **GitLab Project URL:** 

---

## 📋 Application Architecture & Infrastructure

### Deployment Environment
- [ ] **Platform Type:**
  - [ ] Kubernetes (AKS/VM)
    - [ ] UK8s
    - [ ] Own cluster
  - [ ] Other: _________

- **Cluster Details:**
  - Cluster Name(s): 
  - Namespace(s):                 

- [ ] **Service Mesh:** 
  - [ ] None
  - [ ] Istio
  - [ ] Other: _________


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
  - [ ] AppDynamics
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

---


### Security & Compliance
- [ ] **Data Sensitivity:**
  - [ ] Contains PII
  - [ ] Financial data  
  - [ ] No sensitive data
  

### Data Volume & Retention
- **Estimated Daily Volume:**
  - Logs: ___GB/day
  - Metrics: ___samples/sec
  - Traces: ___traces/day
  
- **Retention Requirements:**
  - Logs: ___days
  - Metrics: ___days  
  - Traces: ___days

---

## 🚨 Alerting & Operations

### Alert Configuration
- **Primary On-Call:** @username
- **Escalation Chain:** @team
- **Notification Channels:**
  - [ ] Email
  - [ ] BigPanda
  - [ ] Microsoft Teams
  - [ ] Webhook: ___

- **Alert Preferences:**
  - [ ] Real-time alerts
  - [ ] Aggregated alerts (5min windows)
  - [ ] Business hours only
  - [ ] 24/7 monitoring


---

## ✅ Checklist

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


/label ~"observability-onboarding" /assign @observability-team
/due 2025-08-13
