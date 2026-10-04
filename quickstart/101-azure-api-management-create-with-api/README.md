# Azure API Management

This template deploys an Azure API Management service, containing an API (based on a provided Open API spec). An API Management group and product are then created that are associated with the service and API.

## Terraform resource types

- [random_pet](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/pet)
- [azurerm_resource_group](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/resource_group)
- [random_string](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/string)
- [azurerm_api_management](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/api_management)
- [azurerm_api_management_api](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/api_management_api)
- [azurerm_api_management_api_policy](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/api_management_api_policy)
- [azurerm_api_management_product](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/api_management_product)
- [azurerm_api_management_group](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/api_management_group)
- [azurerm_api_management_product_api](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/api_management_product_api)
- [azurerm_api_management_product_group](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/api_management_product_group)

## Variables

| Name | Description | Default |
|-|-|-|
| `resource_group_name_prefix` | Prefix of the resource group name that's combined with a random ID so name is unique in your Azure subscription. | rg |
| `resource_group_location` | Location of the resource group. | eastus |
| `open_api_spec_content_format` | The format of the content from which the API Definition should be imported. Possible values are: openapi, openapi+json, openapi+json-link, openapi-link, swagger-json, swagger-link-json, wadl-link-json, wadl-xml, wsdl and wsdl-link. | swagger-link-json |
| `open_api_spec_content_value` | The Content from which the API Definition should be imported. When a content_format of *-link-* is specified this must be a URL, otherwise this must be defined inline. | http://conferenceapi.azurewebsites.net/?format=json |

## Example

## 使用 GitHub Actions 手动部署（中文）

仓库的 [Deploy APIM example](../../.github/workflows/deploy-apim.yml) 仅支持手动 `workflow_dispatch`，默认 `plan`，不会因 push 或 PR 自动部署。只操作本示例，不替代现有 PR/E2E 检查。本说明中的 Azure CLI 命令供管理员自行执行；本次提交没有执行 Azure 部署或创建资源。

**费用与时间：** 此示例创建 `Developer_1` APIM，部署后会持续收费，不适用于生产。创建通常需要 30–40 分钟，也可能更久；workflow 超时设为 120 分钟。即使运行失败或超时，也可能已创建部分收费资源，应检查同一 state 后再继续或清理。

### 1. 先确认 state 与执行环境

- 如果已经在本地部署过，**先按下文安全迁移现有 state**，不要让 workflow 使用空远程 state 重建同一批资源。
- 新部署须先准备独立的 Storage Account 和私有 Blob Container；它们不由本示例创建。所有运行使用固定 key `apim-create-with-api.tfstate`，不要让其他部署共用这个 key。
- `backend.tf.example` 是非 `.tf` 模板，Terraform 默认忽略它，保留原有本地和 E2E 的 local state 初始化方式。只有部署 workflow 在 runner 上将它复制为 `backend.tf`，不会提交生成文件。
- workflow 固定 Terraform **1.13.5**（已发布的稳定版本，非浮动 latest），满足示例 `>=1.0`，保留 AzureRM `~>3.0` 和 random `~>3.0`，不升级 provider major。全新初始化会选择约束内的 provider；已核实 AzureRM **3.117.1** 支持 OIDC（从 3.7.0 起支持）。如果迁移时保留了旧 lock 文件，先检查其 AzureRM 版本，低于 3.7.0 时需先评估并升级到兼容的 3.x。
- Terraform 1.13.5 的 AzureRM backend 与 AzureRM 3.117.1 provider 都能读取 Actions 自动提供的 `ACTIONS_ID_TOKEN_REQUEST_URL` / `ACTIONS_ID_TOKEN_REQUEST_TOKEN`；`id-token: write` 和 `ARM_USE_OIDC=true` 启用认证，不需要 Azure login Action 或 client secret，也不需要额外映射。backend 的 `use_azuread_auth=true` 使用 Entra ID 访问 Blob，而非查询存储密钥。不要输出这些 token、开启 `set -x` 或 Terraform 调试日志。
- workflow 设置 `TF_VAR_open_api_spec_content_format=openapi+json-link`，匹配默认地址 `https://petstore3.swagger.io/api/v3/openapi.json` 的 OpenAPI 3 内容；不更改本地示例的默认变量。

### 2. 管理员预先创建 state 存储和部署身份

需要 Azure CLI、目标订阅权限、创建 Entra 应用/服务主体的权限，以及分配角色的权限（例如在对应范围有 Role Based Access Control Administrator）。以下命令只用于准备配置，**不要在尚未确认目标订阅与费用时执行**。尖括号值都是占位符，先替换为自己的非敏感配置；存储账户名必须全局唯一、为 3–24 位小写字母/数字。

```bash
az login
SUBSCRIPTION_ID="<subscription-id>"
STATE_RG="<state-resource-group>"
STATE_ACCOUNT="<globally-unique-storage-account>"
STATE_CONTAINER="tfstate"
LOCATION="eastus"
az account set --subscription "$SUBSCRIPTION_ID"
TENANT_ID=$(az account show --query tenantId -o tsv)

az group create --name "$STATE_RG" --location "$LOCATION"
az storage account create --name "$STATE_ACCOUNT" \
  --resource-group "$STATE_RG" --location "$LOCATION" \
  --sku Standard_LRS --kind StorageV2 \
  --allow-blob-public-access false --allow-shared-key-access false \
  --min-tls-version TLS1_2

CLIENT_ID=$(az ad app create --display-name "github-terraform-apim-demo" \
  --query appId -o tsv)
SP_OBJECT_ID=$(az ad sp create --id "$CLIENT_ID" --query id -o tsv)
APP_OBJECT_ID=$(az ad app show --id "$CLIENT_ID" --query id -o tsv)
```

创建 container 的管理员也需要 Blob **数据平面**权限；仅有 Owner/Contributor 控制平面权限不等于具有 Blob 数据访问权。下面给当前交互登录用户授予存储账户范围的权限以创建 container；如果管理员已有权限可跳过此角色分配。角色传播可能需要数分钟，遇到 403 先等待传播再重试。

```bash
STATE_SCOPE="/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$STATE_RG/providers/Microsoft.Storage/storageAccounts/$STATE_ACCOUNT"
ADMIN_OBJECT_ID=$(az ad signed-in-user show --query id -o tsv)
az role assignment create --assignee-object-id "$ADMIN_OBJECT_ID" \
  --assignee-principal-type User --role "Storage Blob Data Contributor" \
  --scope "$STATE_SCOPE"

az storage container create --name "$STATE_CONTAINER" \
  --account-name "$STATE_ACCOUNT" --auth-mode login --public-access off

CONTAINER_SCOPE="$STATE_SCOPE/blobServices/default/containers/$STATE_CONTAINER"
az role assignment create --assignee-object-id "$SP_OBJECT_ID" \
  --assignee-principal-type ServicePrincipal \
  --role "Storage Blob Data Contributor" --scope "$CONTAINER_SCOPE"

# 仅供测试订阅：此示例会创建资源组，需要订阅范围的资源部署权限。
az role assignment create --assignee-object-id "$SP_OBJECT_ID" \
  --assignee-principal-type ServicePrincipal --role Contributor \
  --scope "/subscriptions/$SUBSCRIPTION_ID"
```

订阅级 Contributor 权限较大，推荐按组织策略授予最小权限：需要创建资源组，以及创建/管理该资源组内 APIM、API、产品、组及关联的权限；不能简单地只给一个尚不存在的资源组授权。生产环境应另行设计权限与资源组结构。部署身份的 Blob 权限只授予 state **容器**范围；state 中可能有敏感数据，避免向其他人员开放容器，建议按组织策略启用版本控制/备份。管理员临时角色不再需要时可按策略撤销。

AzureRM 3.x 默认尝试注册其支持的资源提供程序，需要订阅级 `Microsoft.Resources/subscriptions/providers/register/action` 权限；测试订阅的 Contributor 包含此权限。组织禁止自动注册时，由管理员预注册所需提供程序（本例主要为 `Microsoft.ApiManagement`、`Microsoft.Resources`，准备 state 还需要 `Microsoft.Storage`），然后在 workflow 的 job `env` 中显式增加 `ARM_SKIP_PROVIDER_REGISTRATION: "true"`，避免 provider 自动注册其他命名空间：

```bash
for namespace in Microsoft.ApiManagement Microsoft.Resources Microsoft.Storage; do
  az provider register --namespace "$namespace" --wait
done
```

Storage 防火墙、私有端点或组织网络限制必须允许 runner 访问 Blob endpoint；默认 GitHub 托管 runner 不一定能访问私网。需要时改用组织管理、具有适当网络访问的 runner，不要为了运行 workflow 随意关闭网络保护。

### 3. 配置 Microsoft Entra OIDC 联合凭据

为上面的应用创建联合凭据，不创建 client secret。以下使用同一 shell 中的 `APP_OBJECT_ID`；也可在 Entra 应用的「证书和密码 → 联合凭据」中选择 GitHub Actions / Environment。

```bash
FEDERATED_FILE=$(mktemp)
cat > "$FEDERATED_FILE" <<'JSON'
{
  "name": "github-azure-demo",
  "issuer": "https://token.actions.githubusercontent.com",
  "subject": "repo:luzhu1987/terraform:environment:azure-demo",
  "audiences": ["api://AzureADTokenExchange"]
}
JSON
az ad app federated-credential create --id "$APP_OBJECT_ID" \
  --parameters "$FEDERATED_FILE"
rm "$FEDERATED_FILE"
```

issuer、subject、audience 必须精确匹配，环境名为 `azure-demo`。此 subject 绑定的是环境而不是分支；若复制到其他仓库，必须改为对应的 owner/repo 并重新配置联合凭据。若组织自定义了 GitHub OIDC subject，也需要调整为实际匹配值。

### 4. 配置 GitHub Environment 与保护规则

在仓库 **Settings → Environments** 创建 `azure-demo`，配置：

| 类型 | 名称 | 值 |
| --- | --- | --- |
| Environment Secret | `ARM_CLIENT_ID` | 上面的 `CLIENT_ID`（应用 Client ID，不是对象 ID） |
| Environment Secret | `ARM_TENANT_ID` | 上面的 `TENANT_ID` |
| Environment Secret | `ARM_SUBSCRIPTION_ID` | 目标 `SUBSCRIPTION_ID` |
| Environment Variable | `TF_STATE_STORAGE_ACCOUNT` | 上面的 `STATE_ACCOUNT` |
| Environment Variable | `TF_STATE_CONTAINER` | 上面的 `STATE_CONTAINER` |

无需 `ARM_CLIENT_SECRET`、Storage access key 或 SAS。请不要在 issue、PR、日志中粘贴凭据、plan 或 state。

在套餐和仓库可见性支持时，为环境设置 required reviewers、禁止自我批准，并把 deployment branches/tags 限制为可信的 `master` 分支。Environment、Secrets 和审批保护功能在公开/私有仓库及不同套餐上的可用性不同，请核对 GitHub 官方说明和当前设置，不要假设必有审批拦截。如果不支持审批，须用仓库写权限、可信分支及变更审查控制可执行部署的人。环境审批发生在 job 启动前，因此 plan 和 apply 都可能需要审批；它不是对 job 内生成的具体计划的二次批准。

### 5. 手动 plan / apply

1. 将 workflow 合并到默认分支 `master`（手动 workflow 需存在于默认分支）。
2. 打开 **Actions → Deploy APIM example → Run workflow**，选择可信的 `master` 和 `operation=plan`，审批后查看 Terraform 日志中的资源变更。plan 不应用资源变更，但会访问 Azure/远程 state，AzureRM 自动注册资源提供程序也可能修改订阅注册状态。
3. 确认费用、权限和计划后，再次手动运行，选择 `operation=apply`。

如果已有部署的 API policy 已存在于 Azure、但不在远程 Terraform state 中，apply 失败时会提示该资源需要导入。再次运行 workflow，选择 `operation=apply` 并启用 `import_existing_api_policy`；workflow 会先从已管理的 API 资源读取 ID 并导入该 policy，再生成本次 plan。此选项会修改远程 state，只用于确认已存在该 API policy 的部署；新部署保持关闭。

**apply 会在本次运行重新执行 init、validate、plan，再执行 `terraform apply tfplan`；不是应用上一次 plan 运行的产物。** 两次运行之间代码、provider 解析结果、API URL 内容或 Azure 资源都可能变化，请审查本次日志；需要精确的计划后审批时，应另行设计受保护的审批流程。

workflow 不上传 plan/state 等敏感产物；它们只在该 runner 工作目录中使用，远程 state 留在 Blob。plan 日志本身也可能包含资源信息，请限制 Actions 日志访问。固定 concurrency `deploy-apim-example`（不取消正在运行的任务）加上 Azure Blob state 锁用于避免并行修改；仍不要在外部同时操作同一 state，也不要随意 force-unlock。

### 6. 本地运行、迁移与清理

没有启用模板时，本地和测试继续使用原来的 local backend。若要在本地管理 workflow 的远程 state，安装 Terraform 1.13.5，在本示例目录运行 `az login`，设置同样的订阅/存储变量，并确保登录身份有部署权限和 state 容器的数据权限。Azure CLI 登录不提供 GitHub OIDC token，因此本地须覆盖 backend 的 `use_oidc=false`：

```bash
cd quickstart/101-azure-api-management-create-with-api
az account set --subscription "$SUBSCRIPTION_ID"
export ARM_SUBSCRIPTION_ID="$SUBSCRIPTION_ID"
export ARM_TENANT_ID="$TENANT_ID"
export ARM_USE_OIDC=false ARM_USE_CLI=true
unset ARM_CLIENT_ID ARM_CLIENT_SECRET ARM_OIDC_TOKEN ARM_OIDC_REQUEST_TOKEN ARM_OIDC_REQUEST_URL
export TF_VAR_open_api_spec_content_format="openapi+json-link"
cp backend.tf.example backend.tf
terraform init \
  -backend-config="use_oidc=false" \
  -backend-config="storage_account_name=$STATE_ACCOUNT" \
  -backend-config="container_name=$STATE_CONTAINER" \
  -backend-config="key=apim-create-with-api.tfstate"
terraform validate
terraform plan
```

**已有本地 state 的迁移：** 暂停 workflow 和所有对该部署的操作；确认当前 workspace 为 `default`（workflow 使用 default），在原初始化目录通过 `terraform state list` 确认资源。不同 workspace/已有其他远程 backend 请单独设计迁移，不要覆盖已有非空目标 state。先安全备份 `terraform state pull` 的结果到仓库外受限位置（如 `umask 077; terraform state pull > "$HOME/apim-state-backup.json"`，不要上传/提交），保留原 state 和 lock 文件。然后复制模板，使用上述相同参数执行 **`terraform init -migrate-state`**（用它替代上述 `terraform init`），阅读并确认迁移提示；不要用 `-reconfigure` 或 `-force-copy` 跳过迁移确认。迁移后检查 state 资源列表并运行 plan，确认没有意外重建/删除，再开放 workflow。无现有资源的全新本地目录连接已存在的远程 state 则使用上述普通 init。

所有后续更新和清理必须继续使用**同一 storage account/container/key**；不要删除 state 来「重置」，否则 Terraform 将失去资源记录。清理前停止并发部署，在已连接该远程 backend 的本地目录确认订阅、state 与资源，再手动运行：

```bash
terraform plan -destroy
terraform destroy
```

`terraform destroy` 会要求交互输入 `yes`，这里没有 `-auto-approve`，也没有自动 destroy workflow。销毁可能同样较慢。确认资源已清理且不再需要管理后，才能按组织保留/备份策略处理 state 存储；state Storage Account 不属于本示例，不会被此 destroy 删除。本地生成的 `backend.tf`、plan、备份及任何认证配置不要提交；若要恢复 local backend，应先评估是否需要反向迁移，不要直接删除 backend 配置丢失远程资源关联。

### 官方参考

- [GitHub：Azure OIDC](https://docs.github.com/en/actions/how-tos/secure-your-work/security-harden-deployments/oidc-in-azure)
- [GitHub：部署环境、套餐与保护规则](https://docs.github.com/en/actions/reference/workflows-and-actions/deployments-and-environments)
- [Microsoft：GitHub OIDC 联合凭据](https://learn.microsoft.com/en-us/entra/workload-id/workload-identity-federation-create-trust-github)
- [Microsoft：Blob 数据权限分配](https://learn.microsoft.com/en-us/azure/storage/blobs/assign-azure-role-data-access)
- [HashiCorp：AzureRM backend、OIDC 与 state 锁](https://developer.hashicorp.com/terraform/language/backend/azurerm)
- [HashiCorp：AzureRM 3.117.1 OIDC 认证说明](https://registry.terraform.io/providers/hashicorp/azurerm/3.117.1/docs/guides/service_principal_oidc)
- [Terraform 1.13.5 发布记录](https://github.com/hashicorp/terraform/releases/tag/v1.13.5)及 [backend OIDC 环境变量实现](https://github.com/hashicorp/terraform/blob/v1.13.5/internal/backend/remote-state/azure/backend.go)
- [HashiCorp：backend 初始化与迁移](https://developer.hashicorp.com/terraform/cli/commands/init#backend-initialization)
- [Microsoft：APIM 服务创建与 Developer 层](https://learn.microsoft.com/en-us/azure/api-management/get-started-create-service-instance)
