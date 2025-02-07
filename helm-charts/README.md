# ThirdAI Platform Helm Deployment Guide

## Overview
This guide explains how to deploy the **ThirdAI Platform** using Helm. The deployment process is mostly automated through a **Bash script (`init.sh`)**, which handles:
- Installing and configuring the **NGINX Ingress Controller**
- Setting up **TLS certificates** 
- Creating necessary **Kubernetes secrets**
- Deploying the **Helm chart**

## Running the Deployment Script
To simplify the installation, you can use the provided `init.sh` script, which will handle all setup tasks automatically.

### **Prerequisites**
Ensure you have the following installed:
- `kubectl` (configured to interact with your Kubernetes cluster)
- `Helm` (package manager for Kubernetes)
- `OpenSSL` (for generating self-signed TLS certificates, if needed)

### **Installation Steps**
   ```sh
     ./init.sh
  ```


### **What `init.sh` Does**
- **Creates necessary Kubernetes secrets** (including Docker credentials)
- **Auto-detects the NGINX Ingress hostname** (if applicable)
- **Generates self-signed TLS certificates** 
- **Deploys the NGINX Ingress Controller**
- **Generates `values.yaml` dynamically using environment variables**
- **Deploys the Helm chart using `helm install`**

## Verifying Deployment
Once the script completes, verify that the services are running:
```sh
kubectl get pods -n kube-system
kubectl get ingress -n kube-system
```
If TLS is enabled, confirm HTTPS is working:
```sh
curl -k https://<LoadBalancer-IP-or-Hostname>/api/health
```

## Customizing Deployment
If needed, you can modify the deployment configuration in:
- `values.template.yaml` (used as a base for `values.yaml`)
- `init.sh` (adjust script logic for custom workflows)

## Uninstalling the Deployment
To remove the deployed platform, run:
```sh
helm uninstall thirdai-platform -n kube-system
```
This will remove all resources associated with the platform.

---
