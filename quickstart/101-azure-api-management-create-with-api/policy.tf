resource "azurerm_api_management_policy" "policy" {
  api_management_id = azurerm_api_management.apim_service.id
  xml_content       = file("${path.module}/policy.xml")
}