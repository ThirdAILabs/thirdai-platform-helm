# Deployment Guide for EKS with EFS and RDS

## 1. Initialize and Apply Terraform Configuration

Before deploying the infrastructure, ensure that you have filled out the required Terraform variables (terraform.tfvars) correctly.

Run the following commands to create the necessary AWS infrastructure:

```bash
terraform init
terraform apply
```

### This will create:
- An EKS cluster with the specified Kubernetes version (e.g., 1.31).
- The EBS and EFS CSI driver add-ons.
- Required IAM roles and policies for those add-ons.
- A node group with recommended AWS-managed policies.
- An Amazon Elastic File System (EFS) for shared storage, optionally using an existing EFS if specified.
- An Amazon RDS PostgreSQL instance for database storage, optionally using an existing RDS instance if specified.
- A security group that allows secure access to EFS and RDS from within the cluster.
- A local configuration file (`deployment_config.txt`) that contains critical resource information such as the EFS File System ID and RDS connection details.

---

## 2. Retrieve Deployment Configuration

Once Terraform completes, it generates a **deployment_config.txt** file in the working directory. This file contains key details about the provisioned infrastructure, including:

- **EFS File System ID:** Used for mounting shared storage.
- **RDS Endpoint:** Required for database connectivity.
- **Database Connection URIs:** Pre-configured for ModelBazaar, Keycloak, and Grafana services.

To view the file, run:

```bash
cat deployment_config.txt
```

---

## 3. Authenticate with Your EKS Cluster

After setting up the storage, authenticate with your EKS cluster:

```bash
aws eks update-kubeconfig \
  --region <region-code> \
  --name <cluster-name>
```

For example:

```bash
aws eks update-kubeconfig \
  --region us-east-1 \
  --name my-eks-cluster
```

Verify the context:

```bash
kubectl config get-contexts
kubectl config use-context <your-eks-context>
```

---

Your EKS cluster is now fully set up with EFS storage, and your application should be ready to deploy.

