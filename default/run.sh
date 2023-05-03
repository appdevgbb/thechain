#!/usr/bin/env bash
# shfmt -i 2 -ci -w

# Requirements:
# - Azure CLI
# - jq
# - terraform

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

terraform_dance
load_env
show_env
notation_reset
notation_add_cert
notation_sign_container_image
