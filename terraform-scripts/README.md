1. **Initialize** and **apply**:

   ```bash
   terraform init
   terraform apply
   ```

   This will create:

   - A new VPC (subnets, route tables, NAT gateway, etc.).  
   - An EKS cluster with your chosen version (e.g. 1.25).  
   - The EBS and EFS CSI driver add-ons.  
   - Required IRSA roles and policies for those add-ons.  
   - A node group with recommended AWS-managed policies.

2. **Authenticate with your EKS cluster** using the AWS CLI:

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

3. **Check that your context is set**:

   ```bash
   kubectl config get-contexts
   kubectl config use-context <your-eks-context>
   ```

---

## Next Steps for Deploying Your Helm Chart

After your EKS cluster and node group are up and running:

1. **Create the Docker registry secret** (example you provided):

   ```bash
   kubectl create secret docker-registry docker-credentials-secret \
     --docker-server=thirdaiplatform.azurecr.io \
     --docker-username=thirdaiplatform-pull-release-test-main \
     --docker-password='5Di/+qW2Q/++3mp0Ah/rkCq33n2N7f0E8G4+cSHnub+ACRClJvCj'
   ```

2. **Install your Helm chart** (assuming your `Chart.yaml`, `values.yaml`, and templates are in the same directory):

   ```bash
   helm install thirdaiplatform /path/to/chart
   ```
