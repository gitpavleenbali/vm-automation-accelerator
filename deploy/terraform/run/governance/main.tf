# Governance and Compliance Module
# Deploys Azure Policies and compliance monitoring for VM automation
# Integrated from Day 1 governance/ folder into unified solution

terraform {
  required_version = ">= 1.5.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
}

# Policy: Require Encryption at Host
resource "azurerm_policy_definition" "require_encryption_at_host" {
  name         = "require-encryption-at-host"
  policy_type  = "Custom"
  mode         = "Indexed"
  display_name = "Enterprise - Require encryption at host for VMs"
  description  = "This policy requires that virtual machines have encryption at host enabled for enhanced security."

  metadata = jsonencode({
    version  = "1.0.0"
    category = "Security"
    source   = "VM Automation Accelerator - Unified Solution"
  })

  policy_rule = jsonencode({
    if = {
      allOf = [
        {
          field  = "type"
          equals = "Microsoft.Compute/virtualMachines"
        },
        {
          field  = "Microsoft.Compute/virtualMachines/securityProfile.encryptionAtHost"
          notEquals = true
        }
      ]
    }
    then = {
      effect = "[parameters('effect')]"
    }
  })

  parameters = jsonencode({
    effect = {
      type = "String"
      metadata = {
        displayName = "Effect"
        description = "Enable or disable the execution of the policy"
      }
      allowedValues = ["Audit", "Deny", "Disabled"]
      defaultValue  = "Audit"
    }
  })
}

# Policy: Require Mandatory Tags
resource "azurerm_policy_definition" "require_mandatory_tags" {
  name         = "require-mandatory-tags"
  policy_type  = "Custom"
  mode         = "Indexed"
  display_name = "Enterprise - Require mandatory tags on VMs"
  description  = "This policy requires specific tags (Environment, CostCenter, Owner, Application) on all virtual machines."

  metadata = jsonencode({
    version  = "1.0.0"
    category = "Tags"
    source   = "VM Automation Accelerator - Unified Solution"
  })

  policy_rule = jsonencode({
    if = {
      allOf = [
        {
          field  = "type"
          equals = "Microsoft.Compute/virtualMachines"
        },
        {
          anyOf = [
            {
              field  = "tags['Environment']"
              exists = false
            },
            {
              field  = "tags['CostCenter']"
              exists = false
            },
            {
              field  = "tags['Owner']"
              exists = false
            },
            {
              field  = "tags['Application']"
              exists = false
            }
          ]
        }
      ]
    }
    then = {
      effect = "[parameters('effect')]"
    }
  })

  parameters = jsonencode({
    effect = {
      type = "String"
      metadata = {
        displayName = "Effect"
        description = "Enable or disable the execution of the policy"
      }
      allowedValues = ["Audit", "Deny", "Disabled"]
      defaultValue  = "Audit"
    }
  })
}

# Policy: Enforce Naming Convention
resource "azurerm_policy_definition" "enforce_naming_convention" {
  name         = "enforce-naming-convention"
  policy_type  = "Custom"
  mode         = "Indexed"
  display_name = "Enterprise - Enforce VM naming convention"
  description  = "This policy enforces a naming convention for virtual machines: [env]-vm-[app]-[region]-[###]"

  metadata = jsonencode({
    version  = "1.0.0"
    category = "Naming"
    source   = "VM Automation Accelerator - Unified Solution"
  })

  policy_rule = jsonencode({
    if = {
      allOf = [
        {
          field  = "type"
          equals = "Microsoft.Compute/virtualMachines"
        },
        {
          not = {
            field = "name"
            match = "[parameters('namingPattern')]"
          }
        }
      ]
    }
    then = {
      effect = "[parameters('effect')]"
    }
  })

  parameters = jsonencode({
    effect = {
      type = "String"
      metadata = {
        displayName = "Effect"
        description = "Enable or disable the execution of the policy"
      }
      allowedValues = ["Audit", "Deny", "Disabled"]
      defaultValue  = "Audit"
    }
    namingPattern = {
      type = "String"
      metadata = {
        displayName = "Naming Pattern"
        description = "Regular expression pattern for VM names"
      }
      defaultValue = "^(dev|uat|prod)-vm-[a-z0-9]+-[a-z]+-[0-9]{3}$"
    }
  })
}

# Policy: Require Azure Backup
resource "azurerm_policy_definition" "require_azure_backup" {
  name         = "require-azure-backup"
  policy_type  = "Custom"
  mode         = "Indexed"
  display_name = "Enterprise - Require Azure Backup for VMs"
  description  = "This policy requires that virtual machines have Azure Backup configured."

  metadata = jsonencode({
    version  = "1.0.0"
    category = "Backup"
    source   = "VM Automation Accelerator - Unified Solution"
  })

  policy_rule = jsonencode({
    if = {
      allOf = [
        {
          field  = "type"
          equals = "Microsoft.Compute/virtualMachines"
        },
        {
          field  = "tags['BackupEnabled']"
          notEquals = "true"
        }
      ]
    }
    then = {
      effect = "[parameters('effect')]"
    }
  })

  parameters = jsonencode({
    effect = {
      type = "String"
      metadata = {
        displayName = "Effect"
        description = "Enable or disable the execution of the policy"
      }
      allowedValues = ["Audit", "Deny", "Disabled"]
      defaultValue  = "Audit"
    }
  })
}

# Policy: Restrict VM SKU Sizes
resource "azurerm_policy_definition" "restrict_vm_sku_sizes" {
  name         = "restrict-vm-sku-sizes"
  policy_type  = "Custom"
  mode         = "Indexed"
  display_name = "Enterprise - Restrict VM SKU sizes"
  description  = "This policy restricts the VM SKU sizes that can be deployed."

  metadata = jsonencode({
    version  = "1.0.0"
    category = "Compute"
    source   = "VM Automation Accelerator - Unified Solution"
  })

  policy_rule = jsonencode({
    if = {
      allOf = [
        {
          field  = "type"
          equals = "Microsoft.Compute/virtualMachines"
        },
        {
          not = {
            field = "Microsoft.Compute/virtualMachines/sku.name"
            in    = "[parameters('allowedSKUs')]"
          }
        }
      ]
    }
    then = {
      effect = "[parameters('effect')]"
    }
  })

  parameters = jsonencode({
    effect = {
      type = "String"
      metadata = {
        displayName = "Effect"
        description = "Enable or disable the execution of the policy"
      }
      allowedValues = ["Audit", "Deny", "Disabled"]
      defaultValue  = "Audit"
    }
    allowedSKUs = {
      type = "Array"
      metadata = {
        displayName = "Allowed VM SKUs"
        description = "List of allowed VM SKU sizes"
      }
      defaultValue = [
        "Standard_B2s",
        "Standard_B2ms",
        "Standard_D2s_v3",
        "Standard_D4s_v3",
        "Standard_D8s_v3",
        "Standard_E2s_v3",
        "Standard_E4s_v3",
        "Standard_F2s_v2",
        "Standard_F4s_v2"
      ]
    }
  })
}

# Policy Initiative (combines all policies)
resource "azurerm_policy_set_definition" "vm_governance_initiative" {
  name         = "vm-governance-initiative"
  policy_type  = "Custom"
  display_name = "Enterprise - VM Governance Initiative"
  description  = "Initiative that combines all VM governance policies for comprehensive compliance."

  metadata = jsonencode({
    version  = "1.0.0"
    category = "Governance"
    source   = "VM Automation Accelerator - Unified Solution"
  })

  policy_definition_reference {
    policy_definition_id = azurerm_policy_definition.require_encryption_at_host.id
    parameter_values = jsonencode({
      effect = { value = "[parameters('encryptionEffect')]" }
    })
  }

  policy_definition_reference {
    policy_definition_id = azurerm_policy_definition.require_mandatory_tags.id
    parameter_values = jsonencode({
      effect = { value = "[parameters('tagsEffect')]" }
    })
  }

  policy_definition_reference {
    policy_definition_id = azurerm_policy_definition.enforce_naming_convention.id
    parameter_values = jsonencode({
      effect        = { value = "[parameters('namingEffect')]" }
      namingPattern = { value = "[parameters('namingPattern')]" }
    })
  }

  policy_definition_reference {
    policy_definition_id = azurerm_policy_definition.require_azure_backup.id
    parameter_values = jsonencode({
      effect = { value = "[parameters('backupEffect')]" }
    })
  }

  policy_definition_reference {
    policy_definition_id = azurerm_policy_definition.restrict_vm_sku_sizes.id
    parameter_values = jsonencode({
      effect      = { value = "[parameters('skuEffect')]" }
      allowedSKUs = { value = "[parameters('allowedSKUs')]" }
    })
  }

  parameters = jsonencode({
    encryptionEffect = {
      type         = "String"
      defaultValue = "Audit"
      allowedValues = ["Audit", "Deny", "Disabled"]
    }
    tagsEffect = {
      type         = "String"
      defaultValue = "Audit"
      allowedValues = ["Audit", "Deny", "Disabled"]
    }
    namingEffect = {
      type         = "String"
      defaultValue = "Audit"
      allowedValues = ["Audit", "Deny", "Disabled"]
    }
    namingPattern = {
      type         = "String"
      defaultValue = "^(dev|uat|prod)-vm-[a-z0-9]+-[a-z]+-[0-9]{3}$"
    }
    backupEffect = {
      type         = "String"
      defaultValue = "Audit"
      allowedValues = ["Audit", "Deny", "Disabled"]
    }
    skuEffect = {
      type         = "String"
      defaultValue = "Audit"
      allowedValues = ["Audit", "Deny", "Disabled"]
    }
    allowedSKUs = {
      type = "Array"
      defaultValue = [
        "Standard_B2s",
        "Standard_B2ms",
        "Standard_D2s_v3",
        "Standard_D4s_v3",
        "Standard_D8s_v3",
        "Standard_E2s_v3",
        "Standard_E4s_v3",
        "Standard_F2s_v2",
        "Standard_F4s_v2"
      ]
    }
  })
}

# Assign policy initiative to subscription
resource "azurerm_subscription_policy_assignment" "vm_governance" {
  count = var.assign_to_subscription ? 1 : 0

  name                 = "vm-governance-assignment"
  policy_definition_id = azurerm_policy_set_definition.vm_governance_initiative.id
  subscription_id      = data.azurerm_subscription.current.id
  display_name         = "VM Governance Initiative Assignment"
  description          = "Assigns VM governance policies to subscription"

  parameters = jsonencode({
    encryptionEffect = { value = var.encryption_effect }
    tagsEffect       = { value = var.tags_effect }
    namingEffect     = { value = var.naming_effect }
    namingPattern    = { value = var.naming_pattern }
    backupEffect     = { value = var.backup_effect }
    skuEffect        = { value = var.sku_effect }
    allowedSKUs      = { value = var.allowed_skus }
  })

  location = var.location

  identity {
    type = "SystemAssigned"
  }
}

# Data source for current subscription
data "azurerm_subscription" "current" {}
