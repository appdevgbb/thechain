#!/usr/bin/env bash
# shfmt -i 2 -ci -w

# Requirements:
# - Azure CLI
# - jq
# - terraform

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
  local _NEEDED="az helm curl jq kubectl terraform"
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

# fetch specific key values from the Terraform output
fetch() {
  echo $TF_OUTPUT | jq -r .$1
}

load_env() {
  export NOTATION_VERSION=1.0.0-rc.4
  export KV_VERSION=0.6.0
  export ARCH=$(uname -s | tr '[:upper:]' '[:lower:]')_$(uname -m)
  export ACR_REPO=net-monitor
  export IMAGE_SOURCE=https://github.com/wabbit-networks/net-monitor.git#main
  export IMAGE_TAG=v1
  export IMAGE=${ACR_REPO}:$IMAGE_TAG

  export TF_OUTPUT=$(terraform output -json)
  export KEYNAME=$(fetch signing_key_name.value)
  export ACR_NAME=$(fetch container_registry_name.value)
  export KV_NAME=$(fetch azure_key_vault_name.value)
  export CERT_ID=$(az keyvault certificate show --name $KEYNAME --vault-name $KV_NAME --query id -o tsv)
  export KEY_ID=$(az keyvault certificate show --name $KEYNAME --vault-name $KV_NAME --query kid -o tsv)
  export CERT_PATH=$KEYNAME-cert.crt
  export NOTATION_USERNAME=$(fetch notation_username.value)
  export NOTATION_PASSWORD=$(fetch notation_password.value)
  export AZURE_CLIENT_SECRET=$(fetch service_principal.value.service_principal_password)
  export AZURE_CLIENT_ID=$(fetch service_principal.value.service_principal_client_id)
  export AZURE_TENANT_ID=$(fetch azure.value.tenant_id)
}

show_env() {
  echo "******************"
  echo "NOTATION_VERSION: " $NOTATION_VERSION
  echo "KV_VERSION: " $KV_VERSION
  echo "ARCH: " $ARCH
  echo "KEYNAME: " $KEYNAME
  echo "ACR_NAME: " $ACR_NAME
  echo "KV_NAME: " $KV_NAME
  echo "CERT_ID: " $CERT_ID
  echo "KEY_ID: " $KEY_ID
  echo "$CERT_PATH:" $CERT_PATH
  echo "NOTATION_USERNAME: " $NOTATION_USERNAME
  echo "NOTATION_PASSWORD: " $NOTATION_PASSWORD
  echo "AZURE_CLIENT_SECRET: " $AZURE_CLIENT_SECRET
  echo "AZURE_CLIENT_ID: " $AZURE_CLIENT_ID
  echo "AZURE_TENANT_ID: " $AZURE_TENANT_ID
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
  notation cert delete -s example --type ca --all 2>/dev/null
  notation key delete $KEYNAME 2>/dev/null
}

notation_add_cert() {
  rm -rf example/$CERT_PATH
  az keyvault certificate download --file example/$CERT_PATH --id $CERT_ID
  notation key add $KEYNAME --id $KEY_ID --plugin azure-kv
  notation cert add example/$CERT_PATH --store example --type ca
  notation key list
  notation cert list
}

build_container_image() {
  az acr build --registry $ACR_NAME -t $IMAGE $IMAGE_SOURCE
}

notation_sign_container_image() {
  notation sign --key $KEYNAME $ACR_NAME.azurecr.io/$IMAGE
}

configure_aks() {
  kubectl create namespace gatekeeper-system
  kubectl create namespace demo
  kubectl create secret docker-registry regcred \
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
    --set validatingWebhookTimeoutSeconds=7
}

ratify_install() {
  export PUBLIC_KEY=$(
    az keyvault certificate show \
      --name $KEYNAME \
      --vault-name $KV_NAME \
      -o json | jq -r '.cer' | base64 -d | openssl x509 -inform DER
  )

  kubectl config set-context --current --namespace=default

  helm repo add ratify https://deislabs.github.io/ratify
  helm install ratify \
    ratify/ratify \
    --set ratifyTestCert="$PUBLIC_KEY"
}

ratify_apply() {
  curl -L https://deislabs.github.io/ratify/library/default/template.yaml -o template.yaml
  curl -L https://deislabs.github.io/ratify/library/default/samples/constraint.yaml -o constraint.yaml
  kubectl apply -f template.yaml
  kubectl apply -f constraint.yaml
  rm template.yaml constraint.yaml
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
}

do_demo_bootstrap() {
  load_env
  show_env
  notation_reset
  notation_add_cert
  build_container_image
  notation_sign_container_image
  configure_aks
  gatekeeper_install
  ratify_install
  ratify_apply
  deploy_signed_image
}

run() {
  terraform_dance
  do_demo_bootstrap
}

exec_case() {
  local _opt=$1

  case ${_opt} in
    install) checkDependencies && run ;;
    destroy) destroy ;;
    demo) do_demo_bootstrap ;;
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
