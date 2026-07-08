# debugprobe-helm

Helm chart repository for [DebugProbe](https://github.com/thev1ndu/aks-node-tcpdump) — a privileged debug pod/DaemonSet for AKS node-level packet capture via `tcpdump`.

## Add the Helm repository

```bash
helm repo add debugprobe https://thev1ndu.github.io/debugprobe-helm
helm repo update
```

## Install

**Pod mode — capture on a specific node:**

```bash
helm install debug-node-1 debugprobe/debugprobe \
  --namespace kube-system \
  --set image.registry=myacr.azurecr.io \
  --set image.digest=sha256:<digest-from-ci> \
  --set pod.nodeName=<your-aks-node> \
  --set azureFileShare.shareName=fileshare
```

**DaemonSet mode — capture across all nodes:**

```bash
helm install debugprobe debugprobe/debugprobe \
  --namespace kube-system \
  --set image.registry=myacr.azurecr.io \
  --set image.digest=sha256:<digest-from-ci> \
  --set deploymentMode=daemonset \
  --set azureFileShare.shareName=fileshare
```

**Shell mode — exec in to run tools manually:**

```bash
helm install debug-shell debugprobe/debugprobe \
  --namespace kube-system \
  --set image.registry=myacr.azurecr.io \
  --set image.digest=sha256:<digest-from-ci> \
  --set pod.nodeName=<your-aks-node> \
  --set captureMode=shell

kubectl exec -it debug-shell -n kube-system -- /bin/bash
```

**Remove when done:**

```bash
helm uninstall debug-node-1 -n kube-system
```

## Charts

| Chart | Description |
|-------|-------------|
| [debugprobe](charts/debugprobe/README.md) | Privileged debug pod/DaemonSet for AKS node-level packet capture |

## Prerequisites

- AKS cluster
- Azure Storage Account with a File Share and a `dumps/` directory
- Kubernetes secret in `kube-system` with storage account credentials:

```bash
kubectl create secret generic azure-storage-account-credentials-secret \
  --namespace kube-system \
  --from-literal=azurestorageaccountname=<storage-account> \
  --from-literal=azurestorageaccountkey=<storage-key>
```

See [DebugProbe](https://github.com/thev1ndu/aks-node-tcpdump) for the full setup guide.

## License

Apache 2.0 — see [LICENSE](LICENSE).
