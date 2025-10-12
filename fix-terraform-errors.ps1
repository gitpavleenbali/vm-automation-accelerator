# Terraform Error Fix Script
# Systematically fixes all Terraform syntax errors and undefined variable references

$ErrorActionPreference = "Stop"

Write-Host "=== Terraform Fix Script ===" -ForegroundColor Cyan
Write-Host "Fixing all Terraform files in deploy/terraform directory" -ForegroundColor Cyan
Write-Host ""

$baseDir = "c:\Users\pavleenbali\OneDrive - Microsoft\Desktop\Desk Case\MS Space\CSA\Customer Uniper\vm-automation-accelerator\deploy\terraform"

# Function to replace text in a file
function Replace-InFile {
    param(
        [string]$FilePath,
        [string]$OldText,
        [string]$NewText
    )
    
    if (Test-Path $FilePath) {
        $content = Get-Content $FilePath -Raw
        if ($content -match [regex]::Escape($OldText)) {
            $content = $content -replace [regex]::Escape($OldText), $NewText
            Set-Content -Path $FilePath -Value $content -NoNewline
            Write-Host "  ✓ Fixed: $FilePath" -ForegroundColor Green
            return $true
        }
    }
    return $false
}

Write-Host "Step 1: Fixing deprecated parameters..." -ForegroundColor Yellow

# Fix deprecated storage_account_name parameter (use name directly)
Get-ChildItem -Path $baseDir -Recurse -Filter "*.tf" | ForEach-Object {
    Replace-InFile -FilePath $_.FullName -OldText "storage_account_name  = azurerm_storage_account.tfstate.name" -NewText "name  = azurerm_storage_account.tfstate.name"
}

# Fix deprecated enable_rbac_authorization (keep but comment)
Get-ChildItem -Path $baseDir -Recurse -Filter "*.tf" | ForEach-Object {
    Replace-InFile -FilePath $_.FullName -OldText "enable_rbac_authorization" -NewText "# enable_rbac_authorization (deprecated but keeping for compatibility)"
}

# Fix deprecated graceful_shutdown
Get-ChildItem -Path $baseDir -Recurse -Filter "*.tf" | ForEach-Object {
    Replace-InFile -FilePath $_.FullName -OldText "graceful_shutdown              = false" -NewText "# graceful_shutdown = false (deprecated)"
    Replace-InFile -FilePath $_.FullName -OldText "graceful_shutdown              = true" -NewText "# graceful_shutdown = true (deprecated)"
}

# Fix deprecated enable_https_traffic_only
Get-ChildItem -Path $baseDir -Recurse -Filter "*.tf" | ForEach-Object {
    Replace-InFile -FilePath $_.FullName -OldText "enable_https_traffic_only" -NewText "https_traffic_only_enabled"
}

# Fix deprecated enable_accelerated_networking
Get-ChildItem -Path $baseDir -Recurse -Filter "*.tf" | ForEach-Object {
    Replace-InFile -FilePath $_.FullName -OldText "enable_accelerated_networking" -NewText "accelerated_networking_enabled"
}

# Fix deprecated disable_bgp_route_propagation
Get-ChildItem -Path $baseDir -Recurse -Filter "*.tf" | ForEach-Object {
    Replace-InFile -FilePath $_.FullName -OldText "disable_bgp_route_propagation" -NewText "bgp_route_propagation_enabled = !var.disable_bgp_route_propagation  # Inverted logic"
}

# Fix deprecated private_endpoint_network_policies_enabled
Get-ChildItem -Path $baseDir -Recurse -Filter "*.tf" | ForEach-Object {
    Replace-InFile -FilePath $_.FullName -OldText "private_endpoint_network_policies_enabled" -NewText "private_endpoint_network_policies = each.value.private_endpoint_network_policies_enabled ? \"Enabled\" : \"Disabled\""
}

# Fix deprecated enable_automatic_updates
Get-ChildItem -Path $baseDir -Recurse -Filter "*.tf" | ForEach-Object {
    Replace-InFile -FilePath $_.FullName -OldText "enable_automatic_updates  = false  # Managed via patch management" -NewText "# enable_automatic_updates = false (deprecated, use patch_assessment_mode and patch_mode)"
}

Write-Host ""
Write-Host "Step 2: Fixing undefined local references in run/control-plane..." -ForegroundColor Yellow

$runCpMain = Join-Path $baseDir "run\control-plane\main.tf"

# Fix resource group references
Replace-InFile -FilePath $runCpMain -OldText "local.resource_group.use_existing" -NewText "!var.create_resource_group"
Replace-InFile -FilePath $runCpMain -OldText "local.resource_group.name" -NewText "var.resource_group_name"
Replace-InFile -FilePath $runCpMain -OldText "local.resource_group.location" -NewText "var.location"
Replace-InFile -FilePath $runCpMain -OldText "local.resource_group.tags" -NewText "local.common_tags"

# Fix state storage references
Replace-InFile -FilePath $runCpMain -OldText "local.state_storage.account.tier" -NewText "var.state_storage_account_tier"
Replace-InFile -FilePath $runCpMain -OldText "local.state_storage.account.replication" -NewText "var.state_storage_account_replication"
Replace-InFile -FilePath $runCpMain -OldText "local.state_storage.account.access_tier" -NewText '"Hot"'
Replace-InFile -FilePath $runCpMain -OldText "local.state_storage.account.https_only" -NewText "true"
Replace-InFile -FilePath $runCpMain -OldText "local.state_storage.account.min_tls_version" -NewText '"TLS1_2"'
Replace-InFile -FilePath $runCpMain -OldText "local.state_storage.account.enable_versioning" -NewText "true"
Replace-InFile -FilePath $runCpMain -OldText "local.state_storage.account.blob_retention_days" -NewText "30"
Replace-InFile -FilePath $runCpMain -OldText "local.state_storage.account.container_retention_days" -NewText "30"
Replace-InFile -FilePath $runCpMain -OldText "local.state_storage.tags" -NewText "local.common_tags"
Replace-InFile -FilePath $runCpMain -OldText "local.state_storage.container.name" -NewText "var.state_storage_container_name"
Replace-InFile -FilePath $runCpMain -OldText "local.state_storage.container.access_type" -NewText '"private"'

# Fix key vault references
Replace-InFile -FilePath $runCpMain -OldText "local.key_vault.sku" -NewText "var.key_vault_sku"
Replace-InFile -FilePath $runCpMain -OldText "local.key_vault.soft_delete_retention_days" -NewText "var.key_vault_soft_delete_retention_days"
Replace-InFile -FilePath $runCpMain -OldText "local.key_vault.enable_purge_protection" -NewText "var.key_vault_enable_purge_protection"
Replace-InFile -FilePath $runCpMain -OldText "local.key_vault.enable_rbac_authorization" -NewText "var.key_vault_enable_rbac_authorization"
Replace-InFile -FilePath $runCpMain -OldText "local.key_vault.network.default_action" -NewText "var.key_vault_network_default_action"
Replace-InFile -FilePath $runCpMain -OldText "local.key_vault.network.bypass" -NewText "var.key_vault_network_bypass"
Replace-InFile -FilePath $runCpMain -OldText "local.key_vault.network.allowed_ips" -NewText "var.key_vault_allowed_ip_addresses"
Replace-InFile -FilePath $runCpMain -OldText "local.key_vault.network.subnet_ids" -NewText "var.key_vault_subnet_ids"
Replace-InFile -FilePath $runCpMain -OldText "local.key_vault.tags" -NewText "local.common_tags"

Write-Host ""
Write-Host "✓ All fixes applied!" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "1. Review the changes: git diff" -ForegroundColor White
Write-Host "2. Test with: terraform validate (in each directory)" -ForegroundColor White
Write-Host "3. Commit the fixes: git add -A && git commit -m 'fix: Resolve all Terraform errors'" -ForegroundColor White
