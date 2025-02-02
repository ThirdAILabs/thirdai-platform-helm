Steps to create an EKS cluster:
1. Create custom configuration EKS cluster (not auto). This is done with the assumption that a non-auto cluster is more similar to other cloud provider Kubernetes services
2. Add the EBS and EFS CSI driver add-ons, in addition to the preselected add-ons
3. Create IAM roles for the following service accounts:
    1. Amazon VPC CNI
        1. AmazonEKS_CNI_Policy
    2. EBS CSI Driver
        1. AmazonEBSCSIDriverPolicy
    3. EFS CSI Driver
        1. AmazonEFSCSIDriverPolicy
4. Create node group with recommended IAM policy
5. Run `aws eks update-kubeconfig --region <region-code> --name <my-cluster>` locally to populate your kubeconfig file with your eks cluster metadata
6. Run `kubectl config use-context <context-name>` with your Kubernetes cluster context. You can run `kubectl config view` to see your contexts
7. Run `kubectl create secret docker-registry docker-credentials-secret --docker-server=thirdaiplatform.azurecr.io --docker-username=thirdaiplatform-pull-release-test-main --docker-password='5Di/+qW2Q/++3mp0Ah/rkCq33n2N7f0E8G4+cSHnub+ACRClJvCj'` to add the docker credential secret to your runtime (this docker credential doesn't need to be a secret, but for now this is how we can add secrets in the CLI)
8. Run `helm install thirdaiplatform .` in this repo's head directory to launch modelbazaar


/Users/pratikqpranav/ThirdAI/thirdai-platform-helm/helm-charts [adds-ingress]% helm repo add nginx-stable https://helm.nginx.com/stable
"nginx-stable" has been added to your repositories
/Users/pratikqpranav/ThirdAI/thirdai-platform-helm/helm-charts [adds-ingress]% helm repo update
Hang tight while we grab the latest from your chart repositories...
...Successfully got an update from the "nginx-stable" chart repository
...Successfully got an update from the "aws-efs-csi-driver" chart repository
...Successfully got an update from the "hashicorp" chart repository
...Successfully got an update from the "ingress-nginx" chart repository
Update Complete. ⎈Happy Helming!⎈

/Users/pratikqpranav/ThirdAI/thirdai-platform-helm/helm-charts [adds-ingress]% helm install thirdai-nginx nginx-stable/nginx-ingress -n kube-system
NAME: thirdai-nginx
LAST DEPLOYED: Sun Feb  2 15:54:28 2025
NAMESPACE: kube-system
STATUS: deployed
REVISION: 1
TEST SUITE: None
NOTES:
NGINX Ingress Controller 4.0.0 has been installed.

For release notes for this version please see: https://docs.nginx.com/nginx-ingress-controller/releases/

Installation and upgrade instructions: https://docs.nginx.com/nginx-ingress-controller/installation/installing-nic/installation-with-helm/