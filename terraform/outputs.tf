output "resource_group_name" {
  description = "Resource group that contains all MDM resources"
  value       = azurerm_resource_group.rg.name
}

output "storage_account_name" {
  description = "ADLS Gen2 storage account name (HNS enabled)"
  value       = azurerm_storage_account.datalake.name
}

output "datalake_filesystem" {
  description = "ADLS Gen2 filesystem (container) name"
  value       = azurerm_storage_data_lake_gen2_filesystem.datalake_fs.name
}

output "databricks_workspace_id" {
  description = "Databricks workspace resource id"
  value       = azurerm_databricks_workspace.dbw.id
}

output "databricks_workspace_url" {
  description = "Databricks workspace URL (user-facing). The returned URL can be constructed; provider may also expose it."
  value       = azurerm_databricks_workspace.dbw.workspace_url
}

output "key_vault_id" {
  description = "Key Vault id for storing secrets"
  value       = azurerm_key_vault.kv.id
}

output "data_factory_id" {
  description = "Azure Data Factory resource id"
  value       = azurerm_data_factory.adf.id
}

output "synapse_workspace_id" {
  description = "Azure Synapse workspace id"
  value       = azurerm_synapse_workspace.syn.id
}
