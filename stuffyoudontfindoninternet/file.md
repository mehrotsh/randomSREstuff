Perf
| where ObjectName == "K8SContainer"
| where CounterName == "cpuUsageNanoCores"
| summarize AvgCPUUsage = avg(CounterValue) by ContainerID
| join kind=inner (
    KubePodInventory
    | summarize by ContainerID, ContainerName, PodName, Namespace, ContainerCreationTimeStamp, ContainerStatus, Reason, ContainerCpuRequests
) on ContainerID
| project ContainerName, PodName, Namespace, AvgCPUUsage, ContainerCpuRequests
