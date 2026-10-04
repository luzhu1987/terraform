resource "azurerm_api_management_policy" "policy" {
  api_management_id = azurerm_api_management.example.id

  policy_content = <<-EOT
<policies>
 <inbound>
 <base />
<validate-azure-ad-token 
            tenant-id="你的租户ID或域名（例如：contoso.onmicrosoft.com）" 
            header-name="Authorization" 
            failed-validation-httpcode="401" 
            failed-validation-error-message="Unauthorized. Access token is missing or invalid.">
          <client-application-ids>
            <!-- 替换为你的 SPN 应用程序 ID -->
            <application-id>你的SPN应用程序ID</application-id>
          </client-application-ids>
        </validate-azure-ad-token>
      </inbound>
      <backend><base /></backend>
      <outbound><base /></outbound>
    </policies>
  EOT

  policy_format = "xml"
}