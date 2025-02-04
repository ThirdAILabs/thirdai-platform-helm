# ThirdAI Platform Helm Deployment Guide

## Steps to create an EKS cluster skip this if using Terraform Scripts:
1. Create a custom configuration EKS cluster (not auto). This is done with the assumption that a non-auto cluster is more similar to other cloud provider Kubernetes services.
2. Add the EBS and EFS CSI driver add-ons, in addition to the preselected add-ons.
3. Create IAM roles for the following service accounts:
    1. Amazon VPC CNI
        - AmazonEKS_CNI_Policy
    2. EBS CSI Driver
        - AmazonEBSCSIDriverPolicy
    3. EFS CSI Driver
        - AmazonEFSCSIDriverPolicy
4. Create a node group with the recommended IAM policy.
5. Run `aws eks update-kubeconfig --region <region-code> --name <my-cluster>` locally to populate your kubeconfig file with your EKS cluster metadata.
6. Run `kubectl config use-context <context-name>` with your Kubernetes cluster context. You can run `kubectl config view` to see your contexts.
7. Run `kubectl create secret docker-registry docker-credentials-secret --docker-server=thirdaiplatform.azurecr.io --docker-username=thirdaiplatform-pull-release-test-main --docker-password='5Di/+qW2Q/++3mp0Ah/rkCq33n2N7f0E8G4+cSHnub+ACRClJvCj'` to add the Docker credential secret to your runtime (this Docker credential doesn't need to be a secret, but for now, this is how we can add secrets in the CLI).
8. Run `helm install thirdaiplatform .` in this repo's head directory to launch ModelBazaar.

## Steps to install and configure Ingress:
1. Add the NGINX stable Helm repository:
   ```sh
   helm repo add nginx-stable https://helm.nginx.com/stable
   ```
2. Update the Helm repositories:
   ```sh
   helm repo update
   ```
3. Install the NGINX Ingress Controller:
   ```sh
   helm install thirdai-nginx nginx-stable/nginx-ingress -n kube-system
   ```
4. For further configuration, refer to the [NGINX Ingress Controller documentation](https://docs.nginx.com/nginx-ingress-controller/installation/installing-nic/installation-with-helm/).


## Steps to Enable TLS for Secure Ingress

### 1. Get the Load Balancer IP
After deploying the NGINX Ingress Controller, get the Load Balancer’s external IP or hostname:
```sh
kubectl get svc -n kube-system | grep thirdai-nginx
```
Copy the external IP or hostname and update your `values.yaml` file:
```yaml
ingress:
  hostname: <LoadBalancer-IP-or-Hostname>
```

### 2. Create a SAN Configuration File
Create a file named `san.conf` with the following content:
```ini
[ req ]
default_bits       = 2048
prompt             = no
default_md         = sha256
req_extensions     = req_ext
distinguished_name = dn

[ dn ]
CN                 = myservice

[ req_ext ]
subjectAltName     = @alt_names

[ alt_names ]
DNS.1   = <LoadBalancer-IP-or-Hostname>
IP.1    = <LoadBalancer-IP>
```
Replace `<LoadBalancer-IP-or-Hostname>` with your actual Load Balancer’s external IP or DNS name.

### 3. Generate TLS Certificates
Run the following command to generate a self-signed TLS certificate and private key:
```sh
openssl req -x509 -nodes -days 365 \
  -newkey rsa:2048 \
  -keyout tls.key \
  -out tls.crt \
  -config san.conf \
  -extensions req_ext
```

### 4. Create a Kubernetes TLS Secret
Store the generated certificate and key in Kubernetes as a secret:
```sh
kubectl create secret tls thirdai-platform-tls \
  --cert=tls.crt \
  --key=tls.key \
  -n kube-system
```

### 5. Deploy the Updated Helm Chart
If the platform is already installed, uninstall the previous release:
```sh
helm uninstall thirdai-platform -n kube-system
```
Then, reinstall it with the updated TLS configuration:
```sh
helm install thirdai-platform . -n kube-system
```

### 6. Verify Ingress and TLS Setup
Check that the Ingress is correctly configured:
```sh
kubectl get ingress -n kube-system
```
To ensure TLS is working, try:
```sh
curl -k https://<LoadBalancer-IP-or-Hostname>/api/health
```
If everything is set up correctly, your application should now be accessible over HTTPS!

