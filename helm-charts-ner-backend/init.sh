#!/usr/bin/env bash
set -euo pipefail

#####################################
# USAGE & ARG PARSING               #
#####################################
usage() {
  cat <<EOF
Usage: $0 [--deployment-config <file>] [--template <file>] [--namespace <namespace>]

Options:
  --deployment-config FILE  Deployment config (default: ../terraform-scripts/deployment_config.txt)
  --template FILE           Helm values template (default: values.template.yaml)
  --namespace NAMESPACE     Kubernetes namespace (default: ner-backend)
  -h, --help                Show this help.
EOF
}

DEPLOYMENT_CONFIG="../terraform-scripts/deployment_config.txt"
TEMPLATE_FILE="values.template.yaml"
NAMESPACE="ner-backend"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --deployment-config) DEPLOYMENT_CONFIG="$2"; shift 2 ;;
    --template)          TEMPLATE_FILE="$2";      shift 2 ;;
    --namespace)         NAMESPACE="$2";          shift 2 ;;
    -h|--help)           usage; exit 0 ;;
    *) echo "Unknown option: $1"; usage; exit 1 ;;
  esac
done

#####################################
# ENSURE NAMESPACE                  #
#####################################
echo "▶ Ensuring namespace '$NAMESPACE' exists…"
kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml \
  | kubectl apply -f -

#####################################
# REQUIRE FILES                     #
#####################################
for f in "$DEPLOYMENT_CONFIG" "$TEMPLATE_FILE"; do
  if [[ ! -f "$f" ]]; then
    echo "✖ File not found: $f"; exit 1
  fi
done

#####################################
# SOURCE DEPLOYMENT CONFIG          #
#####################################
source "$DEPLOYMENT_CONFIG"
# now you have:
#   rds_endpoint
#   rds_username
#   rds_password
#   s3_bucket_name
#   aws_region
#   database_uri
#   cluster_autoscaler_role_name

#####################################
# EXPORT FOR HELM VALUES            #
#####################################
export DATABASE_URL="$database_uri"
export S3_BUCKET="$s3_bucket_name"
export S3_REGION="$aws_region"

echo "S3 Bucket: $S3_BUCKET, S3 Region: $S3_REGION"

# S3 bucket & region
# export S3_BUCKET="${S3_BUCKET:-}"
# export S3_REGION="${S3_REGION:-}"
# if [[ -z "$S3_BUCKET" ]]; then
#   read -p "Enter your S3 bucket name: " S3_BUCKET
# fi
# if [[ -z "$S3_REGION" ]]; then
#   read -p "Enter your S3 region: " S3_REGION
# fi

#####################################
# CREATE DOCKER REGISTRY SECRET     #
#####################################
kubectl create secret docker-registry docker-credentials-secret \
  --docker-server=pocketshield.azurecr.io \
  --docker-username=pocketshield-pull-main \
  --docker-password='LiX2XTsZ6hMVzHDMI0UOJuCcrsXkMnzLqp3cP73cM1+ACRAWkkgi' \
  -n "$NAMESPACE" --dry-run=client -o yaml \
  | kubectl apply -f -

#####################################
# HELM REPOS & CONTROLLERS          #
#####################################
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx >/dev/null || true
helm repo add autoscaler     https://kubernetes.github.io/autoscaler >/dev/null || true
helm repo update

echo "▶ Installing NGINX ingress controller…"
helm upgrade --install thirdai ingress-nginx/ingress-nginx -n "$NAMESPACE" --wait

echo "▶ Installing Cluster Autoscaler…"
CLUSTER_NAME=$(kubectl config view --minify -o jsonpath='{.clusters[0].name}' | cut -d/ -f2)
AWS_REGION=$(aws configure get region)
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

helm upgrade --install cluster-autoscaler autoscaler/cluster-autoscaler \
  --namespace kube-system \
  --set autoDiscovery.clusterName="$CLUSTER_NAME" \
  --set awsRegion="$AWS_REGION" \
  --set rbac.serviceAccount.annotations."eks\.amazonaws\.com/role-arn"="arn:aws:iam::${AWS_ACCOUNT_ID}:role/${cluster_autoscaler_role_name}" \
  --wait

#####################################
# TLS CERT FOR INGRESS              #
#####################################
DETECTED_HOST=$(kubectl -n "$NAMESPACE" get svc thirdai-ingress-nginx-controller \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || true)
if [[ -n "$DETECTED_HOST" ]]; then
  echo "Detected Ingress hostname: ${DETECTED_HOST}"
  INGRESS_HOSTNAME="$DETECTED_HOST"
  export INGRESS_HOSTNAME
fi

cat > san.conf <<EOF
[ req ]
default_bits       = 2048
prompt             = no
default_md         = sha256
req_extensions     = req_ext
distinguished_name = dn

[ dn ]
CN                 = ner-backend-ingress

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

kubectl create secret tls ner-backend-tls \
  --cert=tls.crt \
  --key=tls.key \
  -n "$NAMESPACE" --dry-run=client -o yaml \
  | kubectl apply -f -

rm san.conf tls.key tls.crt

#####################################
# RENDER & DEPLOY HELM CHART        #
#####################################
echo "▶ Generating values.yaml from template…"
FINAL_VALUES="values.yaml"
envsubst < "$TEMPLATE_FILE" > "$FINAL_VALUES"

echo "▶ Replacing existing release (if any)…"
helm uninstall ner-backend -n "$NAMESPACE" 2>/dev/null || true

echo "▶ Installing chart…"
helm install ner-backend . -n "$NAMESPACE" --values "$FINAL_VALUES"

echo "✅ Deployment complete."
echo "  • kubectl get ingress -n $NAMESPACE"
