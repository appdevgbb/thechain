#!/usr/bin/env bash
# shfmt -i 2 -ci -w

# Requirements:
# - Azure CLI
# - jq
# - terraform
set -o pipefail
set -ux

__usage="
Available Commands:
    [-x  action]        action to be executed.

    Possible verbs are:
        install         creates all of the resources in Azure and in Kubernetes
        demo            deploy the scripts for the demo
        destroy         deletes all of the components in Azure plus any KUBECONFIG and Terraform files
        show            shows information about the demo environment (e.g.: connection strings)
"

usage() {
  echo "usage: ${0##*/} [options]"
  echo "${__usage/[[:space:]]/}"
  exit 1
}

check_dependencies() {
  # check if the dependencies are installed
  local _NEEDED="az jq terraform"
  local _DEP_FLAG="false"

  echo -e "Checking dependencies ...\n"
  for i in seq ${_NEEDED}; do
    if hash "$i" 2>/dev/null; then
      # do nothing
      :
    else
      echo -e "\t $_ not installed".
      _DEP_FLAG=true
    fi
  done

  if [[ "${_DEP_FLAG}" == "true" ]]; then
    echo -e "\nDependencies missing. Please fix that before proceeding"
    exit 1
  fi
}

show() {
  terraform output -json | jq -r 'to_entries[] | [.key, .value.value]'
}

terraform_dance() {
  terraform init
  terraform plan
  terraform apply -auto-approve
}

# utilities
copy_to_jumpbox() {
  scp -oStrictHostKeyChecking=no $1 ${JUMPBOX_SSH}:$2
}

# Execute commands on the remote jump box
run_on_jumpbox() {
  ssh -oStrictHostKeyChecking=no ${JUMPBOX_SSH} -- $1
}

# fetch specific key values from the Terraform output
fetch() {
  echo $TF_OUTPUT | jq -r .$1
}

load_env() {
  export TF_OUTPUT=$(terraform output -json)
  export ACR_NAME=$(fetch container_registry_name.value)
  export ACR_REPO=net-monitor
  export AKS_CLUSTER_NAME=$(fetch kubernetes_cluster_name.value)
  export ARCH=$(uname -s | tr '[:upper:]' '[:lower:]')_$(uname -m)
  export AZURE_CLIENT_ID=$(fetch service_principal.value.service_principal_client_id)
  export AZURE_CLIENT_SECRET=$(fetch service_principal.value.service_principal_password)
  export AZURE_TENANT_ID=$(fetch azure.value.tenant_id)
  export KEY_NAME=$(fetch signing_key_name.value)
  export KV_NAME=$(fetch azure_key_vault_name.value)
  export CERT_ID=$(az keyvault certificate show --name $KEY_NAME --vault-name $KV_NAME --query id -o tsv)
  export KEY_ID=$(az keyvault certificate show --name $KEY_NAME --vault-name $KV_NAME --query kid -o tsv)
  export CERT_PATH=$KEY_NAME-cert.crt
  export IDENTITY_CLIENT_ID=$(fetch aks_managed_id.value.client_id)
  export IDENTITY_OBJECT_ID=$(fetch aks_managed_id.value.object_id)
  export IDENTITY_CLIENT_NAME=$(fetch aks_managed_id.value.name)
  export IMAGE_SOURCE=https://github.com/wabbit-networks/net-monitor.git#main
  export IMAGE_TAG=v1
  export IMAGE=${ACR_REPO}:$IMAGE_TAG
  export JUMPBOX_SSH=$(fetch jumpbox.value.ssh)
  export KV_VERSION=0.6.0
  export NOTATION_PASSWORD=$(fetch notation_password.value)
  export NOTATION_USERNAME=$(fetch notation_username.value)
  export NOTATION_VERSION=1.0.0-rc.4
  export RG_NAME=$(fetch rg_name.value)
  export RATIFY_NAMESPACE="gatekeeper-system"
  export VAULT_URI=$(az keyvault show --name ${KV_NAME} --resource-group ${RG_NAME} --query "properties.vaultUri
" -otsv)
}

show_env() {
  echo "******************"
  echo "ACR_NAME: " $ACR_NAME
  echo "ARCH: " $ARCH
  echo "AZURE_CLIENT_ID: " $AZURE_CLIENT_ID
  echo "AZURE_CLIENT_SECRET: " $AZURE_CLIENT_SECRET
  echo "AZURE_TENANT_ID: " $AZURE_TENANT_ID
  echo "CERT_ID: " $CERT_ID
  echo "CERT_PATH:" $CERT_PATH
  echo "JUMPBOX_SSH: " $JUMPBOX_SSH
  echo "KEY_ID: " $KEY_ID
  echo "KEY_NAME: " $KEY_NAME
  echo "KV_NAME: " $KV_NAME
  echo "KV_VERSION: " $KV_VERSION
  echo "NOTATION_PASSWORD: " $NOTATION_PASSWORD
  echo "NOTATION_USERNAME: " $NOTATION_USERNAME
  echo "NOTATION_VERSION: " $NOTATION_VERSION
  echo "******************"
}

# download notation
get_notation() {
  curl -Lo notation.tar.gz https://github.com/notaryproject/notation/releases/download/v${NOTATION_VERSION}/notation_${NOTATION_VERSION}_${ARCH}.tar.gz

  [ -d ~/bin ] || mkdir ~/bin
  tar xvzf notation.tar.gz -C ~/bin notation
  rm -rf notation.tar.gz

  export PATH="$HOME/bin:$PATH"
  notation version
}
# download the key vault plugin
get_kv_plugin() {
  curl -Lo notation-azure-kv.tar.gz \
    https://github.com/Azure/notation-azure-kv/releases/download/v${KV_VERSION}/notation-azure-kv_${KV_VERSION}_${ARCH}.tar.gz

  # on macOS: ~/Library/Application Support/notation
  [ -d ~/.config/notation/plugins/azure-kv ] || mkdir -p ~/.config/notation/plugins/azure-kv
  tar xvzf notation-azure-kv.tar.gz -C ~/.config/notation/plugins/azure-kv notation-azure-kv >/dev/null 2>&1
  rm -rf notation-azure-kv.tar.gz

  notation plugin list
}

notation_reset() {
  notation cert delete -s example --type ca -y --all 2>/dev/null
  notation key delete $KEY_NAME 2>/dev/null
}

notation_add_cert() {
  rm -rf example/$CERT_PATH
  az keyvault certificate download --file example/$CERT_PATH --id $CERT_ID --encoding PEM
  notation key add $KEY_NAME --id $KEY_ID --plugin azure-kv
  notation cert add example/$CERT_PATH --store example --type ca
  notation key list
  notation cert list
}

build_container_image() {
  az acr build --registry $ACR_NAME -t $IMAGE $IMAGE_SOURCE
}

notation_sign_container_image() {
  notation sign --key $KEY_NAME $ACR_NAME.azurecr.io/$IMAGE
}

setup_kubeconfig() {
  az aks get-credentials -n ${AKS_CLUSTER_NAME} -g ${RG_NAME} -f kubeconfig
  export KUBECONFIG=./kubeconfig
}

create_federated_credential() {
  AKS_OIDC_ISSUER="$(az aks show -g ${RG_NAME} -n ${AKS_CLUSTER_NAME} --query "oidcIssuerProfile.issuerUrl" -o tsv)"
  echo "aks_oidc_issuer is "${AKS_OIDC_ISSUER}

  az identity federated-credential create \
    --name "DEMO" \
    --identity-name ${IDENTITY_CLIENT_NAME} \
    --resource-group ${RG_NAME} \
    --issuer ${AKS_OIDC_ISSUER} \
    --subject system:serviceaccount:${RATIFY_NAMESPACE}:ratify-admin
}

configure_aks() {
  kubectl create namespace gatekeeper-system
  kubectl create -n gatekeeper-system secret docker-registry regcred \
    --docker-server=${ACR_NAME}.azurecr.io \
    --docker-username=${NOTATION_USERNAME} \
    --docker-password=${NOTATION_PASSWORD} \
    --docker-email=someone@example.com
}

gatekeeper_install() {
  helm repo add gatekeeper https://open-policy-agent.github.io/gatekeeper/charts

  helm install gatekeeper/gatekeeper \
    --name-template=gatekeeper \
    --namespace gatekeeper-system --create-namespace \
    --set enableExternalData=true \
    --set validatingWebhookTimeoutSeconds=5 \
    --set mutatingWebhookTimeoutSeconds=2
}

ratify_install() {
  # helm repo add ratify https://deislabs.github.io/ratify
  # # download the notary verification certificate
  # helm install ratify \
  #   ratify/ratify --atomic \
  #   --namespace gatekeeper-system \
  #   --set-file notaryCert=./notary.crt

  # Install Ratify
  helm install ratify \
    ratify/ratify --atomic \
    --namespace ${RATIFY_NAMESPACE} --create-namespace \
    --set akvCertConfig.enabled=true \
    --set akvCertConfig.vaultURI=${VAULT_URI} \
    --set akvCertConfig.cert1Name=${KEY_NAME} \
    --set akvCertConfig.tenantId=${AZURE_TENANT_ID} \
    --set oras.authProviders.azureWorkloadIdentityEnabled=true \
    --set azureWorkloadIdentity.clientId=${IDENTITY_CLIENT_ID}

  kubectl patch sa ratify-admin 
}

ratify_apply() {
  kubectl apply -f https://deislabs.github.io/ratify/library/default/template.yaml
  kubectl apply -f https://deislabs.github.io/ratify/library/default/samples/constraint.yaml
}

deploy_signed_image() {
  kubectl run net-monitor --image=$ACR_NAME.azurecr.io/$IMAGE
  kubectl get pods
}

destroy() {
  # remove all of the infrastructured
  terraform destroy -auto-approve
  rm -rf \
    terraform.tfstate \
    terraform.tfstate.backup \
    tfplan \
    .terraform \
    .terraform.lock.hcl
  do_demo_destroy
}

do_demo_bootstrap() {
  load_env
  show_env
  setup_kubeconfig
  notation_reset
  notation_add_cert
  build_container_image
  notation_sign_container_image
  configure_aks
  create_federated_credential
  gatekeeper_install
  ratify_install
  ratify_apply
  deploy_signed_image
}

do_demo_destroy() {
  helm uninstall -n gatekeeper-system gatekeeper
  helm uninstall -n gatekeeper-system ratify
  kubectl delete ns demo
  kubectl delete ns gatekeeper-system
  kubectl delete secret regcred
  notation_reset
}
run() {
  terraform_dance
  echo "Ready to deploy the demo components now. Run ./run.sh -x demo".
}

exec_case() {
  local _opt=$1

  case ${_opt} in
    install) check_dependencies && run ;;
    destroy) destroy ;;
    demo) do_demo_bootstrap ;;
    demo-destroy) do_demo_destroy ;;
    show) show ;;
    *) usage ;;
  esac
  unset _opt
}

while getopts "x:" opt; do
  case $opt in
    x)
      exec_flag=true
      EXEC_OPT="${OPTARG}"
      ;;
    *) usage ;;
  esac
done
shift $((OPTIND - 1))

if [ $OPTIND = 1 ]; then
  usage
  exit 0
fi

if [[ "${exec_flag}" == "true" ]]; then
  exec_case "${EXEC_OPT}"
fi

exit 0
