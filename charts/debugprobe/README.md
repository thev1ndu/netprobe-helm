# debugprobe

Privileged debug pod (or DaemonSet) for AKS node-level packet capture. Deploys via Helm, auto-starts `tcpdump`, and writes rotating `.pcap` files directly to an Azure File Share over SMB — no cluster shell access required.

## How it works

```
helm install → Pod or DaemonSet in kube-system
                └─ tcpdump auto-starts on container start
                   └─ *.pcap → Azure File Share (fileshare/captures/)
                               └─ download via Azure CLI or portal
```

## Prerequisites

- AKS cluster with `kube-system` namespace access
- Azure Storage Account with a File Share created
- Kubernetes secret with storage account credentials:

```bash
kubectl create secret generic azure-storage-account-credentials-secret \
  --namespace kube-system \
  --from-literal=azurestorageaccountname=<storage-account> \
  --from-literal=azurestorageaccountkey=<storage-key>
```

- A `captures/` directory inside the share:

```bash
az storage directory create \
  --account-name <storage-account> \
  --share-name fileshare \
  --name captures
```

## Installation

**Pod mode — capture on a specific node:**

```bash
helm upgrade --install debug-node-1 debugprobe/debugprobe \
  --namespace kube-system \
  --set image.registry=myacr.azurecr.io \
  --set image.digest=sha256:<digest-from-ci> \
  --set pod.nodeName=aks-aksnpuser-72792323-vmss00001m \
  --set azureFileShare.shareName=fileshare \
  --set tcpdump.filterHost=10.0.0.1
```

**DaemonSet mode — capture across all nodes simultaneously:**

```bash
helm upgrade --install debugprobe debugprobe/debugprobe \
  --namespace kube-system \
  --set image.registry=myacr.azurecr.io \
  --set image.digest=sha256:<digest-from-ci> \
  --set deploymentMode=daemonset \
  --set azureFileShare.shareName=fileshare
```

**Shell/interactive mode — exec in to run tools manually:**

```bash
helm upgrade --install debug-shell debugprobe/debugprobe \
  --namespace kube-system \
  --set image.registry=myacr.azurecr.io \
  --set image.digest=sha256:<digest-from-ci> \
  --set pod.nodeName=<your-node> \
  --set captureMode=shell

kubectl exec -it debug-shell -n kube-system -- /bin/bash
# tshark, nmap, strace, netstat, ss, mtr, dig — all available
```

**Destroy when done:**

```bash
helm uninstall debug-node-1 -n kube-system
# .pcap files on the File Share are NOT deleted
```

## Values

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `deploymentMode` | string | `pod` | `pod` or `daemonset` |
| `pod.name` | string | `""` | Pod name; defaults to Helm release name |
| `pod.nodeName` | string | `""` | Pin to a specific AKS node; empty = scheduler picks |
| `pod.restartPolicy` | string | `Never` | Pod restart policy (DaemonSet always uses Always) |
| `daemonSet.nodeSelector` | object | `{}` | Restrict DaemonSet to specific node pools; empty = all nodes |
| `image.registry` | string | `""` | Container registry (e.g. `myacr.azurecr.io`) |
| `image.repository` | string | `debugprobe` | Image repository name |
| `image.digest` | string | `""` | Image digest (`sha256:...`); takes priority over `image.tag` |
| `image.tag` | string | `latest` | Image tag; ignored when `image.digest` is set |
| `image.pullPolicy` | string | `IfNotPresent` | Image pull policy |
| `azureFileShare.secretName` | string | `azure-storage-account-credentials-secret` | K8s secret with storage account credentials |
| `azureFileShare.shareName` | string | `fileshare` | Azure File Share name |
| `azureFileShare.mountPath` | string | `/mnt/debugprobe` | Mount path inside the container |
| `azureFileShare.readOnly` | bool | `false` | Mount the share read-only |
| `captureMode` | string | `tcpdump` | `tcpdump` (auto-start) or `shell` (idle, exec in manually) |
| `tcpdump.interface` | string | `any` | Network interface to capture on |
| `tcpdump.rotateSeconds` | int | `300` | Rotate `.pcap` file every N seconds |
| `tcpdump.filterHost` | string | `""` | BPF host filter (e.g. `10.0.0.1`); empty = all traffic |
| `tcpdump.outputDir` | string | `/mnt/debugprobe/captures` | Output directory for `.pcap` files |
| `tcpdump.filePrefix` | string | `capture` | Filename prefix for `.pcap` files |
| `tcpdump.verbose` | bool | `false` | Print packets to stdout only; no `.pcap` file written |
| `securityContext.privileged` | bool | `true` | Required for raw socket access and host network capture |
| `hostNetwork` | bool | `true` | Share the node's network namespace |
| `hostPID` | bool | `true` | Share the node's PID namespace |
| `tolerations` | list | `[{key: CriticalAddonsOnly, operator: Equal, value: "true", effect: NoSchedule}]` | Tolerate the CriticalAddonsOnly taint so the pod lands on system nodes |
| `resources` | object | `{}` | CPU/memory requests and limits |

## Download captures

```bash
# Download all .pcap files
az storage file download-batch \
  --account-name <storage-account> \
  --source "fileshare/captures" \
  --destination ./captures \
  --pattern "*.pcap"

# Inspect without downloading
tshark -r capture.pcap -Y "ip.addr == 10.0.0.42"
```

## Security note

This chart deploys a **privileged** container with `hostNetwork` and `hostPID`. It requires `kube-system` namespace or equivalent cluster-admin privileges. It is designed for on-demand debugging and should be removed with `helm uninstall` immediately after the capture is complete.
