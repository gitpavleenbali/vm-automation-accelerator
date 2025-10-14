# Manual Service Connection Setup Guide
## Using App Registration Method for Different Account Scenarios

### 🎯 Scenario
- **Azure DevOps Account**: Different email address
- **Azure Subscription Account**: admin@MngEnvMCAP852047.onmicrosoft.com
- **Solution**: Manual App Registration method

---

## 📋 Step-by-Step Process

### STEP 1: Create App Registrations in Azure Portal

**URL**: https://portal.azure.com/#view/Microsoft_AAD_RegisteredApps/ApplicationsListBlade

For **EACH environment** (Dev, UAT, Prod), create an app registration:

#### 1.1 Create App Registration
1. Click **"+ New registration"**
2. **Name**: `vm-automation-dev-sp` (change for UAT/Prod)
3. **Supported account types**: Accounts in this organizational directory only
4. **Redirect URI**: Leave blank
5. Click **"Register"**

#### 1.2 Create Client Secret
1. Go to **"Certificates & secrets"**
2. Click **"+ New client secret"**
3. **Description**: `Azure DevOps Service Connection`
4. **Expires**: 24 months (or your preference)
5. Click **"Add"**
6. **⚠️ COPY THE SECRET VALUE IMMEDIATELY** (you won't see it again!)

[SECRET-VALUE-COPIED]

#### 1.3 Get Application Details
Copy these values from the **"Overview"** page:
- **Application (client) ID**  65c2c54e-d1b6-4b4c-8307-5317540daa0b
- **Directory (tenant) ID**: `f1755a38-88fd-47a4-a2e9-5c2019dc2535`

#### 1.4 Assign Permissions
1. Go to Azure Subscriptions: https://portal.azure.com/#view/Microsoft_Azure_Billing/SubscriptionsBlade
2. Click on subscription: `ME-MngEnvMCAP852047-pavleenbali-1`
3. Click **"Access control (IAM)"**
4. Click **"+ Add"** → **"Add role assignment"**
5. **Role**: `Contributor`
6. **Assign access to**: `User, group, or service principal`
7. **Members**: Search for your app name (e.g., `vm-automation-dev-sp`)
8. Click **"Review + assign"**

---

### STEP 2: Create Service Connections in Azure DevOps

**URL**: https://dev.azure.com/azdopavleenbali/A-Z%20of%20Azure/_settings/adminservices

For **EACH app registration** created above:

1. Click **"New service connection"**
2. Select **"Azure Resource Manager"**
3. Choose **"Service principal (manual)"** ⚠️ NOT "App registration or MS"
4. Fill in the details:

#### Connection Details
- **Environment**: Azure Cloud
- **Scope Level**: Subscription
- **Subscription ID**: `37ffd444-46e0-41dd-9e4b-f12857262095`
- **Subscription Name**: `ME-MngEnvMCAP852047-pavleenbali-1`
- **Service Principal Id**: `65c2c54e-d1b6-4b4c-8307-5317540daa0b` (for dev - change for UAT/Prod)
- **Service principal key**: `[YOUR-CLIENT-SECRET]` (for dev - change for UAT/Prod)
- **Tenant ID**: `f1755a38-88fd-47a4-a2e9-5c2019dc2535`

#### Service Connection Settings
- **Service connection name**: 
  - `azure-vm-automation-dev`
  - `azure-vm-automation-uat`
  - `azure-vm-automation-prod`
- **Description**: Optional
- **Grant access permission to all pipelines**: ✅ Check this

5. Click **"Verify and save"**

---

## 📊 App Registrations to Create

| Environment | App Registration Name | Service Connection Name |
|-------------|----------------------|------------------------|
| Development | `vm-automation-dev-sp` | `azure-vm-automation-dev` |
| UAT | `vm-automation-uat-sp` | `azure-vm-automation-uat` |
| Production | `vm-automation-prod-sp` | `azure-vm-automation-prod` |

---

## 🔧 Required Information Summary

**For Azure Portal (App Registration):**
- ✅ Subscription ID: `37ffd444-46e0-41dd-9e4b-f12857262095`
- ✅ Tenant ID: `f1755a38-88fd-47a4-a2e9-5c2019dc2535`

**For Azure DevOps (Service Connection):**
- ✅ Application ID (from app registration)
- ✅ Client Secret (from app registration)
- ✅ Tenant ID: `f1755a38-88fd-47a4-a2e9-5c2019dc2535`
- ✅ Subscription ID: `37ffd444-46e0-41dd-9e4b-f12857262095`

---

## ✅ Verification Commands

After creating all service connections:

```powershell
az devops service-endpoint list --project "A-Z of Azure" --query "[].{name:name, type:type, isReady:isReady}" -o table
```

---

## 💡 Why This Method Works

1. **No subscription visibility required** in Azure DevOps
2. **Works across different tenants/accounts**
3. **Full control over permissions**
4. **Explicit credential management**
5. **Works for enterprise scenarios** with separate identity systems