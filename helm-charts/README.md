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
confirm HTTPS is working:
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


## Enabling Cluster Autoscaling
Follow the instructions at the [Cluster Autoscaler repository](https://github.com/kubernetes/autoscaler/tree/master/charts/cluster-autoscaler#aws---using-auto-discovery-of-tagged-instance-groups) to enable cluster autoscaling. This will allow the dynamic addition and removal of nodes in your Kubernetes cluster.

### AWS EKS Steps
For convenience, we have listed basic steps to deploy the Cluster Autoscaler on AWS EKS. These instructions can be found in different areas in the link above.

1. From the AWS IAM policy console, or the AWS CLI, create the following policy:
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "autoscaling:DescribeAutoScalingGroups",
        "autoscaling:DescribeAutoScalingInstances",
        "autoscaling:DescribeLaunchConfigurations",
        "autoscaling:DescribeScalingActivities",
        "ec2:DescribeImages",
        "ec2:DescribeInstanceTypes",
        "ec2:DescribeLaunchTemplateVersions",
        "ec2:GetInstanceTypesFromInstanceRequirements",
        "eks:DescribeNodegroup"
      ],
      "Resource": ["*"]
    },
    {
      "Effect": "Allow",
      "Action": [
        "autoscaling:SetDesiredCapacity",
        "autoscaling:TerminateInstanceInAutoScalingGroup"
      ],
      "Resource": ["*"]
    }
  ]
}
```
2. Create a role with the above policy created
3. Run `helm install cluster-autoscaler autoscaler/cluster-autoscaler --namespace kube-system --set autoDiscovery.clusterName=<YOUR-EKS-CLUSTER-NAME> --set awsRegion=<YOUR-AWS-REGION> --set rbac.serviceAccount.annotations."eks\.amazonaws\.com/role-arn"=arn:aws:iam::<YOUR-AWS-ACCOUNT-ID>:role/<ROLE-NAME-CREATED-ABOVE> --wait`

The Cluster Autoscaler will now be set up, and autoscale up or down within the bounds of your EKS cluster node groups.
---
