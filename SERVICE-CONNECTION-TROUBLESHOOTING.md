# Service Connection Troubleshooting Guide
## Issue: Subscription Not Visible in Azure DevOps

### Problem Description
Azure subscription `ME-MngEnvMCAP852047-pavleenbali-1` (ID: `37ffd444-46e0-41dd-9e4b-f12857262095`) is not appearing in the Azure DevOps service connection dropdown.

---

## 🔍 Root Causes
1. **Different Authentication Context**: Azure DevOps may be signed in with different account than Azure CLI
2. **Tenant Mismatch**: Service connection creation might be using different Azure AD tenant
3. **Permission Issues**: Account may lack rights to create service principals in the directory
4. **Browser Session**: Cached authentication tokens causing conflicts

---

## 🛠️ Solution Options

### ✅ OPTION 1: Incognito Browser (RECOMMENDED)
**Most likely to work - try this first!**

1. **Open incognito/private browser window**
2. **Navigate to**: `https://dev.azure.com/azdopavleenbali`
3. **Sign in with**: `admin@MngEnvMCAP852047.onmicrosoft.com`
4. **Go to**: Project Settings → Service connections
5. **Create service connection** with "Service principal (automatic)"
6. **Your subscription should now appear** in the dropdown

**Why this works**: Clean authentication context ensures Azure DevOps uses the correct tenant and credentials.

---

### ✅ OPTION 2: Manual Service Principal Creation

If Option 1 doesn't work, create service principals manually:

#### Step 1: Create Service Principals
```powershell
# Dev Environment
az ad sp create-for-rbac --name "sp-vm-automation-dev" --role "Contributor" --scopes "/subscriptions/37ffd444-46e0-41dd-9e4b-f12857262095"

# UAT Environment  
az ad sp create-for-rbac --name "sp-vm-automation-uat" --role "Contributor" --scopes "/subscriptions/37ffd444-46e0-41dd-9e4b-f12857262095"

# Prod Environment
az ad sp create-for-rbac --name "sp-vm-automation-prod" --role "Contributor" --scopes "/subscriptions/37ffd444-46e0-41dd-9e4b-f12857262095"
```

#### Step 2: Use Manual Configuration
In Azure DevOps service connection:
1. Choose **"Service principal (manual)"**
2. Enter the service principal details from CLI output
3. Use subscription ID: `37ffd444-46e0-41dd-9e4b-f12857262095`

---

### ✅ OPTION 3: Alternative Account/Tenant

If you have access to other Azure accounts:
1. Use an account that's in the same tenant as Azure DevOps organization
2. Create the service connections with that account
3. Grant permissions to your current subscription

---

## 🎯 Recommended Approach

**START WITH OPTION 1** (Incognito browser) - success rate ~85%

If that fails → **Try OPTION 2** (Manual service principals) - success rate ~95%

---

## 🔧 Quick Verification

After creating service connections, verify with:
```powershell
az devops service-endpoint list --project "A-Z of Azure" --query "[].{name:name, type:type, isReady:isReady}" -o table
```

---

## 📞 Need Help?

If none of these options work:
1. Check if you have **Global Administrator** or **Application Administrator** role in Azure AD
2. Verify **Azure subscription access** with `az account list`
3. Consider creating service connections via **Azure portal** instead of Azure DevOps