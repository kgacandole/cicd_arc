
region="$1"
subscriptionId="$2"

resourceGroup="arc_tfstate_rg"
storageAccount="arcstorageacct"
storageContainer="arc-tfstate-container"

echo "Creating Resource Group.."
az group create --name "$resourceGroup" --location "$region"

echo "Create Storage Account.."
az storage account create --name "$storageAccount" --resource-group "$resourceGroup" --location "$region" --sku Standard_LRS --kind StorageV2 --min-tls-version TLS1_3 

echo "Create container on the Storage Account.."
az storage container create --name "$storageContainer" --account-name "$storageAccount" --auth-mode login

echo "Create App Registration.."
app_registration_id=$(az ad app create --display-name "gh-app" --sign-in-audience AzureADMyOrg --query appId -o tsv)

echo "Create Federated Credentials for Github.."
az ad app federated-credential create --id "$app_registration_id" --parameters "{ \"name\": \"github-wildcard\", \"issuer\": \"https://token.actions.githubusercontent.com\", \"subject\": \"repo:kgacdevops/*:*\", \"audiences\": [\"api://AzureADTokenExchange\"] }"

echo "Assign roles to the App Registration.."
servicePrincipalId=$(az ad sp show --id "$app_registration_id" --query id -o tsv)
principalRoles="Contributor,Role Based Access Control Administrator,Azure Kubernetes Service Cluster Admin Role,Storage Blob Data Contributor"
IFS=',' read -ra ROLES <<< "$principalRoles"
for r in "${ROLES[@]}"; do
    az role assignment create --assignee-object-id "$servicePrincipalId" --assignee-principal-type ServicePrincipal --role "$r" --scope /subscriptions/"$subscriptionId"
done