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
