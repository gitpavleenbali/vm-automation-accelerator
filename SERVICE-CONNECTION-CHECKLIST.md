# Service Connection Creation Checklist ✅

## Quick Steps for Azure DevOps Portal

### For Each Environment (Dev, UAT, Prod):

1. **Click "New service connection"**
2. **Select "Azure Resource Manager"**
3. **Choose "Service principal (automatic)"**
4. **Authentication Method**: Automatic (recommended)
5. **Scope Level**: Subscription
6. **Subscription**: Select `ME-MngEnvMCAP852047-pavleenbali-1`
7. **Resource Group**: Leave blank (subscription scope)
8. **Service connection name**: Use names below
9. **Description**: Optional
10. **Security**: Grant access permission to all pipelines ✅
11. **Click "Save"**
12. **Authorize** when Azure login popup appears

---

## Service Connection Names:

### 🔵 Connection #1 - Development
**Name**: `azure-vm-automation-dev`
**Purpose**: Development environment deployments
**Scope**: Subscription level

### 🟡 Connection #2 - UAT  
**Name**: `azure-vm-automation-uat`
**Purpose**: UAT environment deployments
**Scope**: Subscription level

### 🔴 Connection #3 - Production
**Name**: `azure-vm-automation-prod`
**Purpose**: Production environment deployments
**Scope**: Subscription level

---

## Verification Steps:

After creating each connection:

1. ✅ Check that the connection shows "Ready" status
2. ✅ Verify the subscription name matches
3. ✅ Ensure "Grant access permission to all pipelines" is checked

---

## Common Issues & Solutions:

**❌ "Access denied" error**
- Solution: Ensure you have Owner or Contributor role on the subscription

**❌ Connection shows "Failed" status**
- Solution: Try recreating with "Service principal (manual)" and provide explicit permissions

**❌ Authorization popup blocked**
- Solution: Allow popups for dev.azure.com in your browser

---

## After All Connections Created:

Come back to the terminal and we'll verify with:
```powershell
az devops service-endpoint list --project "A-Z of Azure" --query "[].{name:name, type:type, isReady:isReady}" -o table
```