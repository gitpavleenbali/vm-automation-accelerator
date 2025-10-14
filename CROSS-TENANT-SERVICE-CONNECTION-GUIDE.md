# Cross-Tenant Azure DevOps Service Connection Solution
## Your Scenario: Microsoft Corporate vs Personal Azure Account

### 🎯 Problem Summary
- **Azure DevOps Account**: Bobi@microsoft.com (Microsoft Corporate Tenant)
- **Azure Subscription**: Personal Microsoft account (Different Tenant: f1755a38-88fd-47a4-a2e9-5c2019dc2535)
- **Challenge**: Connect Azure DevOps service connections to resources in a different tenant

---

## ✅ SOLUTION: Multi-Tenant App Registration Method

### 🔧 Step 1: Create Multi-Tenant App Registration
Your existing app registration (`vm-automation-dev-sp`) needs to be configured for multi-tenant access.

#### In Azure Portal (Your Personal Tenant):
1. Go to your app registration: `vm-automation-dev-sp`
2. Navigate to **"Authentication"**
3. Under **"Supported account types"**, change to:
   ```
   ✅ Accounts in any organizational directory (Any Microsoft Entra directory - Multitenant) 
       and personal Microsoft accounts (e.g. Skype, Xbox)
   ```
4. **Save** the changes

### 🔧 Step 2: Create Service Principal in Microsoft Tenant

Since your Azure DevOps is on Microsoft's tenant, you need to create a service principal there for your app.

#### Option A: Using Azure CLI (Recommended)
```powershell
# Login to Microsoft tenant (where your Azure DevOps is)
az login --tenant <microsoft-tenant-id>

# Create service principal for your app registration
az ad sp create --id 65c2c54e-d1b6-4b4c-8307-5317540daa0b
```

#### Option B: Ask Microsoft IT Admin
If you don't have permissions to create service principals in Microsoft tenant:
1. Contact your Microsoft IT administrator
2. Provide them with your **Application ID**: `65c2c54e-d1b6-4b4c-8307-5317540daa0b`
3. Ask them to run: `az ad sp create --id 65c2c54e-d1b6-4b4c-8307-5317540daa0b`

### 🔧 Step 3: Configure Service Connection with Workload Identity Federation

#### In Azure DevOps (Microsoft Tenant):
1. Go to **Project Settings** → **Service connections**
2. Click **"New service connection"**
3. Select **"Azure Resource Manager"**
4. Choose **"App registration or Managed identity (manual)"**
5. Select **"Workload identity federation"** credential
6. Fill in the details:

```
Environment: Azure Cloud
Scope Level: Subscription
Subscription ID: 37ffd444-46e0-41dd-9e4b-f12857262095
Subscription Name: ME-MngEnvMCAP852047-pavleenbali-1
Application (client) ID: 65c2c54e-d1b6-4b4c-8307-5317540daa0b
Directory (tenant) ID: f1755a38-88fd-47a4-a2e9-5c2019dc2535
Service connection name: azure-vm-automation-dev
```

7. **Copy the generated "Issuer" and "Subject identifier"** values
8. Click **"Keep as draft"**

### 🔧 Step 4: Add Federated Credentials to Your App Registration

#### In Azure Portal (Your Personal Tenant):
1. Go to your app registration: `vm-automation-dev-sp`
2. Navigate to **"Certificates & secrets"**
3. Click **"Federated credentials"** tab
4. Click **"+ Add credential"**
5. Select **"Other issuer"**
6. Fill in the values you copied from Azure DevOps:
   ```
   Issuer: [The issuer URL from Azure DevOps]
   Subject identifier: [The subject identifier from Azure DevOps]
   Name: azure-devops-vm-automation-dev
   Description: Azure DevOps service connection for VM automation
   ```
7. Click **"Add"**

### 🔧 Step 5: Complete Service Connection Setup

#### In Azure DevOps:
1. Return to your draft service connection
2. Click **"Finish setup"**
3. Click **"Verify and save"**

---

## 🚨 Alternative: Client Secret Method (Fallback)

If the federated identity approach doesn't work, use the client secret method:

### In Azure DevOps:
1. Create **"Service principal (manual)"** connection type
2. Use these values:
   ```
   Service Principal Id: 65c2c54e-d1b6-4b4c-8307-5317540daa0b
   Service principal key: [YOUR-CLIENT-SECRET]
   Tenant ID: f1755a38-88fd-47a4-a2e9-5c2019dc2535
   Subscription ID: 37ffd444-46e0-41dd-9e4b-f12857262095
   ```

---

## 🔍 Why This Works

1. **Multi-tenant app registration** allows your app to be used across different tenants
2. **Service principal in Microsoft tenant** provides the identity for Azure DevOps to use
3. **Federated credentials** eliminate the need for secrets while maintaining security
4. **Cross-tenant permissions** are handled through the app registration's role assignments

---

## 📋 Verification Steps

1. **Test the service connection** in Azure DevOps (should show green checkmark)
2. **Run a simple pipeline** that lists Azure resources
3. **Verify permissions** by checking if the connection can access your subscription resources

---

## 🔒 Security Benefits

- ✅ **No long-lived secrets** (with federated identity)
- ✅ **Proper cross-tenant authentication**
- ✅ **Auditable through both tenants**
- ✅ **Follows Microsoft security best practices**

---

## 🎯 Next Steps

1. **Complete this cross-tenant service connection**
2. **Repeat for UAT and Prod environments** (create new app registrations)
3. **Proceed with pipeline environment setup**

This solution properly handles your cross-tenant scenario where Azure DevOps and Azure subscription are in different tenants!