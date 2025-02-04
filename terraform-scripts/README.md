# Deployment Guide for EKS with EFS

## 1. Initialize and Apply Terraform Configuration

Run the following commands to create the necessary AWS infrastructure:

```bash
terraform init
terraform apply
```

### This will create:
- A new VPC with subnets, route tables, and a NAT gateway.
- An EKS cluster with the specified Kubernetes version (e.g., 1.25).
- The EBS and EFS CSI driver add-ons.
- Required IAM roles and policies for those add-ons.
- A node group with recommended AWS-managed policies.

---

## 2. Manually Create an Amazon EFS File System

After Terraform has finished setting up the VPC and subnets, you need to create an Amazon Elastic File System (EFS) using the AWS Management Console.

### Steps to Create EFS:
1. **Go to the AWS Management Console** and open the [Amazon EFS service](https://console.aws.amazon.com/efs/).
2. Click **Create file system**.
3. In the **VPC** dropdown, select the VPC created by Terraform (`${var.cluster_name}-vpc`).
4. Under **Subnets**, select the private subnets (`10.0.1.0/24` and `10.0.2.0/24`).
5. **Attach the security group**:
   - Select the security group named `efs-sg` created by Terraform.
6. Click **Create File System**.
7. Once created, note down the **File System ID** (`fs-xxxxxxxxx`).



### Steps to Create RDS:
1. **Go to the AWS Management Console** and open the [Amazon RDS service](https://console.aws.amazon.com/rds/).
2. Click **Create database**.
3. Choose **Standard Create** and select the database engine (e.g., **PostgreSQL**, **MySQL**, or **Aurora**).
4. Under **Templates**, choose the appropriate option (e.g., **Free Tier**, **Production**, or **Dev/Test**).
5. Configure **Settings**:
   - Set **DB instance identifier** to `${var.cluster_name}-rds`.
   - Define a master username and password or use AWS Secrets Manager for credentials.
6. Under **Connectivity**:
   - Select the **VPC** created by Terraform (`${var.cluster_name}-vpc`).
   - In **Subnet group**, select the private subnets (`10.0.1.0/24` and `10.0.2.0/24`).
   - Choose the **security group** created by Terraform (`efs-sg`).
   - Ensure **Public access** is set to **No**.
7. Under **Additional configuration**, enable **Storage Auto Scaling** if needed.
8. Click **Create database**.
9. Once the RDS instance is available, note down the **Endpoint** (`<db-identifier>.<region>.rds.amazonaws.com`) for application use.

---

## 3. Update `storageclass.yml` with EFS File System ID

Before deploying your application, update the `values.yml` file with the newly created EFS **File System ID**: fileSystemId as efs.fileSystemId

---

## 4. Authenticate with Your EKS Cluster

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

## 5. Deploy Your Helm Chart

Once the cluster and storage are configured, deploy your Helm chart:

1. **Create a Docker registry secret**:

   ```bash
   kubectl create secret docker-registry docker-credentials-secret \
     --docker-server=thirdaiplatform.azurecr.io \
     --docker-username=thirdaiplatform-pull-release-test-main \
     --docker-password='5Di/+qW2Q/++3mp0Ah/rkCq33n2N7f0E8G4+cSHnub+ACRClJvCj' \
     -n kube-system
   ```

2. **Install the Helm chart**:

   ```bash
   helm install thirdaiplatform /path/to/chart -n kube-system
   ```

Your EKS cluster is now fully set up with EFS storage, and your application should be ready to deploy.

