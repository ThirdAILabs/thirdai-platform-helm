#!/usr/bin/env bash
set -euo pipefail

#####################################
# FUNCTIONS AND USAGE INFORMATION   #
#####################################
usage() {
  cat <<EOF
Usage: $0 [--deployment-config <file>] [--template <file>] [--namespace <namespace>]

Options:
  --deployment-config FILE  Specify the deployment configuration file (default: ../terraform-scripts/deployment_config.txt).
  --template FILE           Specify the values template file (default: values.template.yaml).
  --namespace NAMESPACE     Specify the namespace to deploy the application (default: thirdai).
  -h, --help                Show this help message.
EOF
}

#####################################
# PARSE COMMAND-LINE ARGUMENTS      #
#####################################
DEPLOYMENT_CONFIG="../terraform-scripts/deployment_config.txt"
TEMPLATE_FILE="values.template.yaml"
NAMESPACE="thirdai-platform"  # Default namespace

while [[ $# -gt 0 ]]; do
  case "$1" in
    --deployment-config)
      DEPLOYMENT_CONFIG="$2"
      shift 2
      ;;
    --template)
      TEMPLATE_FILE="$2"
      shift 2
      ;;
    --namespace)
      NAMESPACE="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      usage
      exit 1
      ;;
  esac
done

#####################################
# ENSURE NAMESPACE EXISTS           #
#####################################
echo "Ensuring namespace '$NAMESPACE' exists..."
kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

#####################################
# VERIFY REQUIRED FILES             #
#####################################
if [[ ! -f "$DEPLOYMENT_CONFIG" ]]; then
  echo "Error: Deployment config file '$DEPLOYMENT_CONFIG' not found!"
  exit 1
fi

if [[ ! -f "$TEMPLATE_FILE" ]]; then
  echo "Error: Template file '$TEMPLATE_FILE' not found!"
  exit 1
fi

#####################################
# SOURCE DEPLOYMENT CONFIG          #
#####################################
source "$DEPLOYMENT_CONFIG"

#####################################
# EXPORT ENVIRONMENT VARIABLES      #
#####################################
export EFS_FILE_SYSTEM_ID="$efs_file_system_id"
export KEYCLOAK_DB_URL="$keycloak_db_uri"
export KEYCLOAK_DB_USERNAME="$rds_username"
export KEYCLOAK_DB_PASSWORD="$rds_password"
export MODELBAZAAR_DB_URI="$modelbazaar_db_uri"
export GRAFANA_DB_URL="$grafana_db_uri"

export INGRESS_HOSTNAME="example.com"

#####################################
# CREATE DOCKER SECRET              #
#####################################
kubectl create secret docker-registry docker-credentials-secret \
  --docker-server=thirdaiplatform.azurecr.io \
  --docker-username=thirdaiplatform-pull-eks-test \
  --docker-password='+0j2ErguQ9dK+eELV7VNBWLFdDe+rF2mAXrKmGfhy9+ACRBHAhHg' \
  -n "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

#####################################
# DEPLOY NGINX INGRESS CONTROLLER   #
#####################################
echo "Adding the NGINX stable Helm repository..."
helm repo add nginx-stable https://helm.nginx.com/stable 2>/dev/null || true

echo "Updating Helm repositories..."
helm repo update

echo "Deploying the NGINX Ingress Controller..."
helm install thirdai ingress-nginx/ingress-nginx -n $NAMESPACE --wait 2>/dev/null || true

echo "Deploying the internal NGINX Ingress Controller..."
helm install thirdai-internal ingress-nginx/ingress-nginx -n $NAMESPACE \
  --set controller.ingressClassResource.name=nginx-internal \
  --set controller.service.type=ClusterIP \
  --set controller.ingressClass=nginx-internal \
  --wait 2>/dev/null || true

#####################################
# TLS CERTIFICATE SETUP             #
#####################################
DETECTED_HOSTNAME=$(kubectl get svc thirdai-ingress-nginx-controller -n $NAMESPACE -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || true)

if [[ -n "${DETECTED_HOSTNAME}" ]]; then
  echo "Detected Ingress hostname: ${DETECTED_HOSTNAME}"
  export INGRESS_HOSTNAME="${DETECTED_HOSTNAME}"
else
  read -p "Enter Ingress DNS (LoadBalancer hostname): " ingress_dns
  export INGRESS_HOSTNAME="${ingress_dns}"
fi

cat > san.conf <<EOF
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
DNS.1   = ${INGRESS_HOSTNAME}
EOF

openssl req -x509 -nodes -days 365 \
  -newkey rsa:2048 \
  -keyout tls.key \
  -out tls.crt \
  -config san.conf \
  -extensions req_ext

kubectl create secret tls thirdai-platform-tls \
  --cert=tls.crt \
  --key=tls.key \
  -n "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

rm -rf san.conf

#####################################
# GENERATE FINAL values.yaml        #
#####################################
FINAL_VALUES="values.yaml"
envsubst < "$TEMPLATE_FILE" > "$FINAL_VALUES"
echo "Generated $FINAL_VALUES using envsubst."

#####################################
# DEPLOY THE HELM CHART             #
#####################################
echo "Removing any previous Helm release in '$NAMESPACE' (if exists)..."
helm uninstall thirdai-platform -n "$NAMESPACE" 2>/dev/null || true

echo "Installing the Helm chart from . using the generated values file..."
helm install thirdai-platform . -n "$NAMESPACE" --values "$FINAL_VALUES"

#####################################
# FINAL STATUS MESSAGE              #
#####################################
echo "Deployment complete!"
echo "Verify your Ingress with:"
echo "  kubectl get ingress -n $NAMESPACE"


#####################################
# ADD KUBERNETES DASHBOARD HELM REPO & INSTALL CHART #
#####################################
echo "Adding the Kubernetes Dashboard Helm repository..."
helm repo add kubernetes-dashboard https://kubernetes.github.io/dashboard/ 2>/dev/null || true

echo "Updating Helm repositories..."
helm repo update

echo "Installing Kubernetes Dashboard Helm chart..."
helm upgrade --install kubernetes-dashboard kubernetes-dashboard/kubernetes-dashboard --create-namespace --namespace kubernetes-dashboard

#####################################
# CHECK FOR KUBERNETES DASHBOARD ADMIN TOKEN #
#####################################
echo "Checking for existing Kubernetes Dashboard admin token..."
DASHBOARD_TOKEN_SECRET=$(kubectl -n kubernetes-dashboard get secret | grep kubernetes-dashboard-token | awk '{print $1}' || true)

if [[ -n "$DASHBOARD_TOKEN_SECRET" ]]; then
  ADMIN_TOKEN=$(kubectl -n kubernetes-dashboard get secret "$DASHBOARD_TOKEN_SECRET" -o jsonpath="{.data.token}" | base64 --decode)
  echo "Using existing Kubernetes Dashboard admin token."
else
  echo "Creating new Kubernetes Dashboard admin token..."
  kubectl create serviceaccount dashboard-admin -n kubernetes-dashboard --dry-run=client -o yaml | kubectl apply -f -
  kubectl create clusterrolebinding dashboard-admin --clusterrole=cluster-admin --serviceaccount=kubernetes-dashboard:dashboard-admin --dry-run=client -o yaml | kubectl apply -f -

  # Fetch the token after creation
  sleep 5  # Allow time for the token to be generated
  ADMIN_TOKEN=$(kubectl -n kubernetes-dashboard create token dashboard-admin)
fi

# Print the token before starting port-forwarding
echo "Access the Kubernetes Dashboard at: https://localhost:8443"
echo "Use the following token to log in:"
echo "$ADMIN_TOKEN"

#####################################
# PORT-FORWARD KUBERNETES DASHBOARD (FOREGROUND) #
#####################################
echo "Starting port-forwarding for Kubernetes Dashboard..."
kubectl -n kubernetes-dashboard port-forward svc/kubernetes-dashboard-kong-proxy 8443:443