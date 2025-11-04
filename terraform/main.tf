locals {
  prefix                     = var.prefix
  rg_name                    = length(trim(var.resource_group_name)) > 0 ? var.resource_group_name : "${local.prefix}-rg"
  storage_account_name       = lower(substr("${local.prefix}st${random_id.storage_suffix.hex}", 0, 24))
  datalake_filesystem        = "datalake"
  databricks_workspace_name  = "${local.prefix}-dbw"
  key_vault_name             = "${local.prefix}-kv"
  log_analytics_name         = "${local.prefix}-law"
  adf_name                   = "${local.prefix}-adf"
  synapse_workspace_name     = "${local.prefix}-syn"
  managed_mrg_name           = "${local.prefix}-mrg" # used as Databricks managed RG
}

resource "random_id" "storage_suffix" {
  byte_length = 4
}

resource "azurerm_resource_group" "rg" {
  name     = local.rg_name
  location = var.location
  tags     = var.tags
}

resource "azurerm_storage_account" "datalake" {
  name                     = local.storage_account_name
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  enable_https_traffic_only = true

  # ADLS Gen2
  is_hns_enabled = true

  identity {
    type = "SystemAssigned"
  }

  tags = var.tags
}

resource "azurerm_storage_data_lake_gen2_filesystem" "datalake_fs" {
  name               = local.datalake_filesystem
  storage_account_id = azurerm_storage_account.datalake.id
}

resource "azurerm_log_analytics_workspace" "law" {
  name                = local.log_analytics_name
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
  tags                = var.tags
}

resource "azurerm_user_assigned_identity" "databricks_identity" {
  name                = "${local.prefix}-dbi"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  tags                = var.tags
}

resource "azurerm_user_assigned_identity" "adf_identity" {
  name                = "${local.prefix}-adfi"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  tags                = var.tags
}

resource "azurerm_user_assigned_identity" "synapse_identity" {
  name                = "${local.prefix}-synid"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  tags                = var.tags
}

# Key Vault for secrets
resource "azurerm_key_vault" "kv" {
  name                        = local.key_vault_name
  location                    = azurerm_resource_group.rg.location
  resource_group_name         = azurerm_resource_group.rg.name
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  sku_name                    = "standard"
  purge_protection_enabled    = var.enable_purge_protection
  soft_delete_enabled         = true

  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = data.azurerm_client_config.current.object_id

    secret_permissions = [
      "get",
      "list",
      "set",
      "delete"
    ]
  }

  tags = var.tags
}

# Databricks workspace
resource "azurerm_databricks_workspace" "dbw" {
  name                = local.databricks_workspace_name
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  sku                 = var.databricks_sku
  managed_resource_group_id = azurerm_resource_group.rg.id # optional: adjust if you want a dedicated mrg

  # Enable workspace customer-managed encryption or other settings as needed
  tags = var.tags
}

# Data Factory with system assigned identity disabled and user assigned identity
resource "azurerm_data_factory" "adf" {
  name                = local.adf_name
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  identity {
    type = "UserAssigned"
    identity_ids = [
      azurerm_user_assigned_identity.adf_identity.id
    ]
  }

  tags = var.tags
}

# Synapse workspace (SQL admin password stored in Key Vault)
resource "random_password" "synapse_admin_pwd" {
  length  = 20
  special = true
}

resource "azurerm_synapse_workspace" "syn" {
  name                                 = local.synapse_workspace_name
  resource_group_name                  = azurerm_resource_group.rg.name
  location                             = azurerm_resource_group.rg.location
  storage_data_lake_gen2_filesystem_id = azurerm_storage_data_lake_gen2_filesystem.datalake_fs.id
  sql_administrator_login              = var.synapse_sql_admin
  sql_administrator_login_password     = random_password.synapse_admin_pwd.result
  managed_virtual_network_enabled      = false

  identity {
    type = "UserAssigned"
    identity_ids = [
      azurerm_user_assigned_identity.synapse_identity.id
    ]
  }

  tags = var.tags
}

# Granting Storage Blob Data Contributor to the identities so they can read/write ADLS Gen2
data "azurerm_role_definition" "storage_blob_data_contributor" {
  name = "Storage Blob Data Contributor"
  scope = azurerm_storage_account.datalake.id
}

resource "azurerm_role_assignment" "dbw_storage_role" {
  scope                = azurerm_storage_account.datalake.id
  role_definition_id   = data.azurerm_role_definition.storage_blob_data_contributor.id
  principal_id         = azurerm_databricks_workspace.dbw.identity[0].principal_id
  principal_type       = "ServicePrincipal"
  depends_on           = [azurerm_databricks_workspace.dbw]
}

resource "azurerm_role_assignment" "db_userassigned_storage_role" {
  count               = length([for id in [azurerm_user_assigned_identity.databricks_identity] : id]) > 0 ? 1 : 0
  scope               = azurerm_storage_account.datalake.id
  role_definition_id  = data.azurerm_role_definition.storage_blob_data_contributor.id
  principal_id        = azurerm_user_assigned_identity.databricks_identity.principal_id
  principal_type      = "ServicePrincipal"
}

resource "azurerm_role_assignment" "adf_storage_role" {
  scope               = azurerm_storage_account.datalake.id
  role_definition_id  = data.azurerm_role_definition.storage_blob_data_contributor.id
  principal_id        = azurerm_user_assigned_identity.adf_identity.principal_id
  principal_type      = "ServicePrincipal"
}

resource "azurerm_role_assignment" "synapse_storage_role" {
  scope               = azurerm_storage_account.datalake.id
  role_definition_id  = data.azurerm_role_definition.storage_blob_data_contributor.id
  principal_id        = azurerm_user_assigned_identity.synapse_identity.principal_id
  principal_type      = "ServicePrincipal"
}

# Save Synapse admin password to Key Vault secret
resource "azurerm_key_vault_secret" "synapse_admin_secret" {
  name         = "${local.prefix}-synapse-admin"
  value        = random_password.synapse_admin_pwd.result
  key_vault_id = azurerm_key_vault.kv.id
}

# Example: store Storage account name in Key Vault
resource "azurerm_key_vault_secret" "storage_account_name" {
  name         = "${local.prefix}-storage-name"
  value        = azurerm_storage_account.datalake.name
  key_vault_id = azurerm_key_vault.kv.id
}

# Optional: Data Factory linked service + sample pipeline can be created via ARM templates or REST once ADF exists.
# Leave it to operational process or automation pipeline to register notebooks/labs into Databricks workspace and ADF pipeline import.
