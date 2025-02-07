#!/usr/bin/env bash
set -euo pipefail

#####################################
# FUNCTIONS AND USAGE INFORMATION   #
#####################################
usage() {
  cat <<EOF
Usage: $0 [--deployment-config <file>] [--template <file>]

Options:
  --deployment-config FILE  Specify the deployment configuration file (default: ../terraform-scripts/deployment_config.txt).
  --template FILE           Specify the values template file (default: values.template.yaml).
  -h, --help                Show this help message.
EOF
}

#####################################
# PARSE COMMAND-LINE ARGUMENTS      #
#####################################
DEPLOYMENT_CONFIG="../terraform-scripts/deployment_config.txt"
TEMPLATE_FILE="values.template.yaml"

kubectl create secret docker-registry docker-credentials-secret \
  --docker-server=thirdaiplatform.azurecr.io \
  --docker-username=thirdaiplatform-pull-release-test-main \
  --docker-password='5Di/+qW2Q/++3mp0Ah/rkCq33n2N7f0E8G4+cSHnub+ACRClJvCj' \
  -n kube-system --dry-run=client -o yaml | kubectl apply -f -

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

export INGRESS_HOSTNAME="example.com"


#####################################
# DEPLOY NGINX INGRESS CONTROLLER   #
#####################################
echo "Adding the NGINX stable Helm repository..."
helm repo add nginx-stable https://helm.nginx.com/stable 2>/dev/null || true

echo "Updating Helm repositories..."
helm repo update

echo "Deploying the NGINX Ingress Controller..."
helm install thirdai-nginx nginx-stable/nginx-ingress -n kube-system --wait 2>/dev/null || true


#####################################
# TLS CERTIFICATE SETUP (always)
#####################################
DETECTED_HOSTNAME=$(kubectl get svc thirdai-nginx-nginx-ingress-controller -n kube-system -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || true)
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
  -n kube-system --dry-run=client -o yaml | kubectl apply -f -

rm -rf san.conf

#####################################
# GENERATE FINAL values.yaml         #
#####################################
FINAL_VALUES="values.yaml"
envsubst < "$TEMPLATE_FILE" > "$FINAL_VALUES"
echo "Generated $FINAL_VALUES using envsubst."


#####################################
# DEPLOY THE HELM CHART             #
#####################################
echo "Removing any previous Helm release (if exists)..."
helm uninstall thirdai-platform -n kube-system 2>/dev/null || true

echo "Installing the Helm chart from . using the generated values file..."
helm install thirdai-platform . -n kube-system --values "$FINAL_VALUES"

#####################################
# FINAL STATUS MESSAGE              #
#####################################
echo "Deployment complete!"
echo "Verify your Ingress with:"
echo "  kubectl get ingress -n kube-system"
