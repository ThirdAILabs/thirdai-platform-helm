# ThirdAI Platform Helm Deployment Guide

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

