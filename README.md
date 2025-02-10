# Terraform and Helm Deployment Guide

This repository provides Terraform scripts for provisioning an AWS infrastructure, including an Amazon Elastic Kubernetes Service (EKS) cluster, Amazon Elastic File System (EFS), and Amazon Relational Database Service (RDS). Additionally, it includes Helm charts to deploy the ThirdAI Platform on the EKS cluster with proper ingress and security configurations.

---

## **Prerequisites**

Before running the Terraform scripts, ensure that you have AWS CLI configured with appropriate permissions. Run the following command to verify:

```bash
aws configure
```

You should have the necessary AWS credentials (Access Key ID, Secret Access Key, and default region) configured in `~/.aws/config` or `~/.aws/credentials`.

Additionally, the initial VPC passed to the Terraform scripts must have **NAT enabled** to ensure proper network connectivity for private subnets and external resources.

---

