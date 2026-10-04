resource "azurerm_api_management_api_policy" "policy" {
  api_name            = azurerm_api_management_api.api.name
  api_management_name = azurerm_api_management.apim_service.name
  resource_group_name = azurerm_resource_group.rg.name
  xml_content         = file("${path.module}/policy.xml")
}