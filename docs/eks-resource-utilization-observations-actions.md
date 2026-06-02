# EKS Resource Utilization Review – Observations and Recommended Actions

## 1. Background

During recent CRQ activities, the Infrastructure team had to add new worker nodes to unblock deployments and operations.

This indicates that the EKS cluster did not have enough **schedulable capacity** at deployment time. In Kubernetes, pods are scheduled based on configured **resource requests**, not actual runtime usage. Therefore, even if actual CPU usage is low, new pods may still remain pending if the requested CPU/memory cannot fit on existing nodes.

The current review is based on the CPU and memory utilization reports shared for Java Spring Boot microservices running on EKS.

---

## 2. High-Level Observation

The reports show the following pattern:

| Area | Observation |
|---|---|
| CPU | Very low utilization compared to configured CPU requests and limits |
| Memory | Mixed utilization; some services are reasonable, some are over-provisioned, and a few are under-requested |
| HPA | HPA can scale replicas but cannot change CPU/memory requests or limits |
| Deployment impact | Rolling deployments during CRQ may temporarily increase pod count and create scheduling pressure |
| Cost impact | Over-provisioned requests cause inefficient node utilization and increased AWS infrastructure cost |

---

## 3. Cluster-Level Observation

The average CPU/memory utilization summary shows:

| Date | CPU Request Usage | CPU Limit Usage | Memory Request Usage | Memory Limit Usage |
|---|---:|---:|---:|---:|
| 27 May | 1.82% | 1.18% | 51.33% | 37.59% |
| 28 May | 3.51% | 2.21% | 52.12% | 38.74% |
| 29 May | 2.31% | 1.51% | 46.83% | 33.48% |
| 30 May | 4.29% | 2.78% | 50.92% | 36.14% |
| 31 May | 8.24% | 5.23% | 45.01% | 33.39% |
| 1 June | 2.50% | 1.25% | 57.01% | 39.03% |

### Interpretation

CPU utilization is consistently very low compared to configured requests and limits. This strongly indicates that CPU is over-provisioned across multiple workloads.

Memory utilization is moderate. Memory request usage is around 45% to 57%, and memory limit usage is around 33% to 39%. This means memory optimization is possible for some services, but it must be done carefully, especially because the workloads are Java Spring Boot applications.

---

## 4. Service-Wise CPU Observations

The service-wise CPU report shows that many pods have CPU requests such as:

- 0.200 Core
- 0.250 Core
- 0.500 Core
- 1 Core
- 2 Core

However, actual CPU utilization is mostly very low, commonly between:

- 0.3% to 5% of CPU request
- In some cases below 1% of CPU request

### Examples

| Service | CPU Request | CPU Limit | Mean CPU vs Request | Observation |
|---|---:|---:|---:|---|
| account-statement-service | 0.200 Core | 0.500 Core | ~0.91% | Very low CPU usage |
| adv-tokenization-service | 0.200 Core | 0.500 Core | ~2.96% to 3.00% | Low CPU usage |
| api-catalog-service | 1 Core | 1 Core | ~0.34% | Highly over-provisioned |
| api-economy-tracker-service | 0.500 Core | 0.700 Core | ~0.56% to 0.68% | Very low CPU usage |
| beneficiary-validation-consumer | 0.500 Core | 0.700 Core | ~0.44% to 0.45% | Very low CPU usage |
| bgl-management-service | 2 Core | 2.5 Core | ~0.245% | Highly over-provisioned |
| carinfo-verification-service | 0.500 Core | 0.700 Core | ~0.18% to 0.19% | Very low CPU usage |

### CPU Conclusion

CPU requests appear to be significantly higher than actual production usage for many services.

This can cause the Kubernetes scheduler to treat the cluster as full, even when real CPU usage is low. During CRQ deployments, rolling updates create additional pods, and these extra pods require schedulable CPU based on requests. If existing nodes cannot fit those requested resources, deployments may be blocked and Infra may need to add worker nodes.

---

## 5. Service-Wise Memory Observations

Memory utilization is not uniformly low. It varies service by service.

### Examples

| Service | Memory Request | Memory Limit | Mean Memory vs Request | Observation |
|---|---:|---:|---:|---|
| account-statement-service | 500 MiB | 700 MiB | ~59% to 60% | Reasonable |
| adv-tokenization-service | 500 MiB | 600 MiB | ~71% to 73% | Request is somewhat tight |
| api-catalog-service | 1.5 GiB | 1.5 GiB | ~29% | Can be reviewed |
| api-economy-tracker-service | 1 GiB | 1.5 GiB | ~50% | Reasonable |
| api-inventory-service | 250 MiB | 500 MiB | ~135% | Request is too low |
| beneficiary-validation-service | 650 MiB | 750 MiB | ~64% to 65% | Reasonable, but limit is close |
| bgl-management-service | 2 GiB | 2 GiB | ~28% | Can be reviewed |
| brnet-integration-service | 1.5 GiB | 2 GiB | ~50% | Reasonable |
| cronjob services | 500 MiB | 1.5 GiB | ~48% to 50% | Looks acceptable |

### Important Memory Finding

`api-inventory-service` is using around 135% of its memory request.

Current visible configuration:

```yaml
memory request: 250Mi
memory limit: 500Mi
```

This means the memory request is too low. It is not immediately breaching the limit, but from a scheduling and stability perspective, this service should not have its memory reduced. Its memory request should be increased after validating p95/p99 memory usage.

Possible revised direction:

```yaml
memory request: 350Mi or 400Mi
memory limit: 600Mi or 700Mi
```

Final values should be based on actual p95/p99 usage and OOM history.

---

## 6. Why HPA Does Not Fully Solve This

HPA only changes the number of pod replicas. It does not change CPU or memory requests/limits.

Example:

```yaml
resources:
  requests:
    cpu: "1000m"
    memory: "2Gi"

hpa:
  minReplicas: 4
  maxReplicas: 20
  targetCPUUtilizationPercentage: 70
```

If load is low, HPA can reduce replicas only down to `minReplicas`.

It cannot reduce:

```yaml
requests:
  cpu: "1000m"
```

So even if actual CPU usage is only 50m, Kubernetes still reserves 1000m per pod.

### Key Point

HPA solves replica scaling. It does not solve over-sized resource requests.

---

## 7. Why This Can Happen Even After Load Testing

The current production resource sizing appears to be aligned with peak-load testing, such as Diwali sale or major campaign traffic.

That is a valid approach for understanding maximum capacity, but peak-load sizing should not become static baseline production sizing for all days.

Correct production sizing should separate:

| Capacity Type | Purpose |
|---|---|
| Baseline capacity | Normal production traffic and minimum HA |
| Autoscaling capacity | Scale up/down based on traffic |
| Peak-event capacity | Temporary pre-scaling during known events |
| PT/load test capacity | Determines safe upper boundary and max replicas |

Load test results should influence:

- HPA maxReplicas
- CPU/memory limits
- Cluster autoscaler/Karpenter max capacity
- Peak-event runbook
- Scheduled scaling strategy

Load test results should not blindly become:

- High CPU request all the time
- High minReplicas all the time
- Peak capacity running permanently

---

## 8. Main Root Cause Hypothesis

The most likely root cause is:

> CPU requests are over-provisioned across many Java Spring Boot microservices. During CRQ deployments, rolling updates temporarily increased the number of pods, and Kubernetes could not schedule additional pods because requested CPU capacity was already reserved on existing nodes. Infra added worker nodes to create schedulable capacity.

This is likely a scheduling-capacity issue, not an actual CPU-consumption issue.

---

## 9. Recommended Actions

### 9.1 CPU Right-Sizing

CPU request should be reviewed service-wise using p95/p99 CPU usage, not only average usage.

Suggested review bands:

| Current CPU Request | Observed Usage Pattern | Suggested Review Range |
|---:|---|---:|
| 200m | Mean CPU below 5% | 50m to 100m |
| 250m | Mean CPU below 5% | 75m to 150m |
| 500m | Mean CPU below 2% | 100m to 200m |
| 1 Core | Mean CPU below 1% | 150m to 300m |
| 2 Core | Mean CPU below 1% | 250m to 500m |

These values should not be applied blindly. They should be validated with p95/p99 metrics, criticality, service type, and PT results.

---

### 9.2 CPU Limits

CPU limits should not be reduced too aggressively because Java services may need burst CPU during:

- Application startup
- Garbage collection
- Traffic spikes
- JSON serialization/deserialization
- TLS processing
- Kafka lag recovery
- Batch processing

Recommended pattern for normal APIs:

```yaml
resources:
  requests:
    cpu: "100m"
  limits:
    cpu: "500m"
```

For heavier APIs:

```yaml
resources:
  requests:
    cpu: "250m"
  limits:
    cpu: "1000m"
```

For critical/high-throughput services:

```yaml
resources:
  requests:
    cpu: "500m"
  limits:
    cpu: "1500m"
```

---

### 9.3 Memory Right-Sizing

Memory should be reviewed carefully. Do not reduce memory globally.

Recommended memory approach:

```text
memory request = p95 memory usage + 20% to 30% buffer
memory limit = max observed memory + JVM/native overhead buffer
```

For Java Spring Boot services, validate:

- JVM heap size
- `-Xms`
- `-Xmx`
- `-XX:MaxRAMPercentage`
- `-XX:InitialRAMPercentage`
- Metaspace usage
- Direct memory
- Thread stack usage
- Connection pool size
- Cache usage
- OOMKilled history

---

### 9.4 HPA Review

Review HPA for each service:

```bash
kubectl get hpa -A
```

Check:

- minReplicas
- maxReplicas
- current replicas
- CPU target
- memory target, if used
- whether HPA is already at minimum replicas
- whether CPU request is too high, making utilization percentage look artificially low

Example:

```text
TARGETS     MINPODS   MAXPODS   REPLICAS
5%/70%      5         20        5
```

This means the service is already at minimum replicas. HPA cannot reduce further.

---

### 9.5 Deployment Strategy Review

During CRQ, rolling updates can temporarily increase pod count.

Check deployment strategy:

```bash
kubectl get deployment <deployment-name> -n <namespace> -o yaml
```

Review:

```yaml
strategy:
  rollingUpdate:
    maxSurge: 25%
    maxUnavailable: 0
```

For heavy services, consider:

```yaml
maxSurge: 1
maxUnavailable: 1
```

or deploy services in controlled batches.

---

### 9.6 Peak-Event Scaling Strategy

For known high-traffic periods such as festival sales or campaigns:

1. Keep normal-day baseline resources optimized.
2. Keep HPA maxReplicas aligned with PT results.
3. Temporarily increase minReplicas before the event.
4. Pre-scale worker nodes using Cluster Autoscaler/Karpenter.
5. Warm up Java pods before traffic starts.
6. Monitor latency, CPU, memory, GC, Kafka lag, DB pool, and error rate.
7. Reduce minReplicas and node capacity after the event.

---

## 10. Suggested Immediate Plan

### Phase 1: Data Collection

Collect service-wise:

- Current CPU request
- Current CPU limit
- Current memory request
- Current memory limit
- Replicas
- HPA min/max/current replicas
- CPU p95 and p99
- Memory p95 and p99
- CPU throttling
- OOMKilled count
- Restart count
- Latency p95/p99
- Kafka lag, if consumer service
- DB connection pool usage

---

### Phase 2: Identify Top Candidates

Prioritize services where:

- CPU request is high
- CPU usage is consistently below 5%
- Max CPU usage is also low
- Replica count is high
- Service is not a known heavy batch or peak-critical workload

High-priority candidates from visible report:

- bgl-management-service
- api-catalog-service
- api-economy-tracker-service
- beneficiary-validation-consumer-service
- carinfo-verification-service
- account-statement-service
- adv-tokenization-service

---

### Phase 3: Apply Changes Gradually

Do not change all services at once.

Recommended approach:

1. Pick 5 to 10 low-risk services.
2. Reduce CPU requests first.
3. Keep CPU limits with burst headroom.
4. Avoid reducing memory in first round unless clearly over-provisioned.
5. Deploy to lower environment.
6. Validate with sanity/load test.
7. Apply to production in controlled CRQ.
8. Monitor for at least 1 week.
9. Continue next batch.

---

## 11. Service-Specific Recommendations Based on Visible Data

### 11.1 api-catalog-service

Visible data:

```text
CPU request: 1 Core
CPU limit: 1 Core
Mean CPU usage: ~0.34% of request
Memory request: 1.5 GiB
Memory limit: 1.5 GiB
Mean memory usage: ~29%
```

Observation:

- CPU is highly over-provisioned.
- Memory also appears over-provisioned.
- Validate if this service has any scheduled heavy jobs or high peak traffic.

Possible review direction:

```yaml
resources:
  requests:
    cpu: "150m"
    memory: "768Mi"
  limits:
    cpu: "750m"
    memory: "1Gi"
```

---

### 11.2 bgl-management-service

Visible data:

```text
CPU request: 2 Core
CPU limit: 2.5 Core
Mean CPU usage: ~0.245% of request
Memory request: 2 GiB
Memory limit: 2 GiB
Mean memory usage: ~28%
```

Observation:

- Strong candidate for CPU right-sizing.
- Memory also appears reviewable.
- Check whether it handles batch/month-end/heavy financial processing before reducing.

Possible review direction:

```yaml
resources:
  requests:
    cpu: "250m"
    memory: "1Gi"
  limits:
    cpu: "1000m"
    memory: "1536Mi"
```

---

### 11.3 api-inventory-service

Visible data:

```text
CPU request: 250m
CPU usage: low
Memory request: 250Mi
Memory limit: 500Mi
Memory usage: ~135% of request
Memory usage vs limit: ~67%
```

Observation:

- CPU can be reviewed downward.
- Memory request is too low and should be increased.
- Do not reduce memory for this service.

Possible review direction:

```yaml
resources:
  requests:
    cpu: "100m"
    memory: "400Mi"
  limits:
    cpu: "500m"
    memory: "600Mi"
```

---

### 11.4 adv-tokenization-service

Visible data:

```text
CPU request: 200m
CPU limit: 500m
Mean CPU usage: ~3%
Memory request: 500Mi
Memory limit: 600Mi
Mean memory usage: ~72% of request
```

Observation:

- CPU can be reviewed.
- Memory is moderately high against request, so avoid aggressive memory reduction.

Possible review direction:

```yaml
resources:
  requests:
    cpu: "75m or 100m"
    memory: "500Mi"
  limits:
    cpu: "500m"
    memory: "600Mi"
```

---

## 12. Risks and Controls

| Risk | Cause | Control |
|---|---|---|
| OOMKilled | Memory limit reduced too much | Validate p95/p99 memory and OOM history |
| CPU throttling | CPU limit too low | Monitor throttling metrics |
| High latency | CPU request/limit too low or GC pressure | Monitor p95/p99 latency |
| Slow startup | CPU too low for Java bootstrap | Keep startup CPU headroom |
| HPA instability | CPU request too low/high | Tune HPA target after right-sizing |
| Kafka lag | Consumer CPU too low during backlog | Monitor lag and consumer throughput |
| Deployment failure | maxSurge too high | Review rollout strategy |

---

## 13. Metrics to Monitor After Changes

### Kubernetes

```bash
kubectl top pods -A
kubectl top nodes
kubectl get hpa -A
kubectl get pods -A | grep -E 'Pending|OOMKilled|CrashLoopBackOff'
```

### Prometheus / Grafana

Monitor:

- CPU usage p95/p99
- CPU throttling
- Memory working set
- JVM heap usage
- GC pause time
- Pod restarts
- OOMKilled events
- API latency p95/p99
- HTTP 5xx rate
- Kafka lag
- DB connection pool usage
- HPA replica movement
- Node allocatable vs requested resources

---

## 14. Suggested Response to Infra/Application Stakeholders

```text
Based on the CPU and memory utilization reports, CPU usage is significantly lower than configured CPU requests and limits for most workloads. Several services are using less than 1% to 5% of requested CPU, while still reserving 200m, 500m, 1 Core, or 2 Core per pod. This can lead to inefficient node utilization and scheduling pressure during CRQ deployments because Kubernetes schedules pods based on requests, not actual usage.

Memory utilization is mixed. Some services have scope for optimization, while some services such as api-inventory-service are already using more than their memory request and should not be reduced. Therefore, CPU right-sizing can be taken up as the first priority, while memory should be reviewed carefully service-wise using p95/p99 memory usage, JVM configuration, and OOM history.

We propose a phased right-sizing approach: first identify top CPU over-provisioned services, reduce CPU requests gradually while keeping safe CPU limits, validate through lower environment and production monitoring, then review memory service-wise. For known peak events, we should use HPA maxReplicas and scheduled pre-scaling instead of running peak-sized CPU requests and replicas permanently.
```

---

## 15. Final Recommendation

The immediate focus should be:

1. Reduce over-provisioned CPU requests service-wise.
2. Do not reduce memory globally.
3. Increase memory request where usage is already above request, such as api-inventory-service.
4. Review HPA minReplicas and maxReplicas.
5. Review rolling deployment maxSurge settings.
6. Use PT results for maxReplicas and peak-event planning, not permanent baseline requests.
7. Apply changes gradually and monitor stability.

The strongest cost-saving opportunity is CPU request right-sizing.
