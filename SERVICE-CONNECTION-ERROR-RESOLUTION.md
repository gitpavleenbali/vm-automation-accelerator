# Service Connection Error Resolution
## AADSTS70025: No Configured Federated Identity C**The client secret `[YOUR-CLIENT-SECRET]` is now visible in this document. Consider:**edentials

### 🚨 Error Details
- **Error Code**: AADSTS70025
- **Message**: No configured federated identity credentials
- **App ID**: 65c2c54e-d1b6-4b4c-8307-5317540daa0b (vm-automation-dev-sp)
- **Trace ID**: 2c2db480-e2fb-4af4-8f1b-8b895eb64a00

### 🔍 Root Cause
Azure DevOps is attempting to use **Workload Identity Federation** (modern OIDC-based authentication) instead of traditional client secret authentication. The app registration doesn't have federated identity credentials configured.

---

## ✅ SOLUTION 1: Use Service Principal (Manual) Method

**IMMEDIATE FIX - Use this approach:**

### In Azure DevOps Service Connection:
1. **DO NOT** select "App registration or Managed Service Identity (manual)"
2. **SELECT**: "Service principal (manual)" instead
3. **Use these exact values**:

```
Environment: Azure Cloud
Scope Level: Subscription
Subscription ID: 37ffd444-46e0-41dd-9e4b-f12857262095
Subscription Name: ME-MngEnvMCAP852047-pavleenbali-1
Service Principal Id: 65c2c54e-d1b6-4b4c-8307-5317540daa0b
Service principal key: [YOUR-CLIENT-SECRET]
Tenant ID: f1755a38-88fd-47a4-a2e9-5c2019dc2535
```

4. **Service connection name**: `azure-vm-automation-dev`
5. **Grant access to all pipelines**: ✅ Checked
6. Click **"Verify and save"**

---

## 🔧 SOLUTION 2: Configure Federated Identity (Advanced)

If you prefer the modern federated identity approach:

### Step 1: Configure Federated Credentials in Azure Portal
1. Go to your app registration: `vm-automation-dev-sp`
2. Navigate to **"Certificates & secrets"**
3. Click **"Federated credentials"** tab
4. Click **"+ Add credential"**
5. Select **"Other issuer"**
6. Configure these values:
   ```
   Issuer: https://vstoken.dev.azure.com/[Azure DevOps Organization ID]
   Subject identifier: sc://azdopavleenbali/A-Z of Azure/azure-vm-automation-dev
   Name: azure-devops-vm-automation-dev
   Description: Azure DevOps service connection for VM automation
   ```

### Step 2: Use App Registration Method in Azure DevOps
Then use "App registration or Managed Service Identity (manual)" in Azure DevOps.

---

## 🎯 Recommended Approach

**Use SOLUTION 1** (Service principal manual) because:
- ✅ Simpler to configure
- ✅ Works immediately
- ✅ No additional federated identity setup needed
- ✅ Traditional and well-tested method

**Consider SOLUTION 2** later for:
- Enhanced security (no secrets)
- Modern authentication patterns
- Better compliance posture

---

## 📋 Next Steps

1. **Delete the failing service connection** in Azure DevOps
2. **Create new service connection** using "Service principal (manual)"
3. **Use the exact values** provided in Solution 1
4. **Test the connection** with "Verify and save"
5. **Repeat for UAT and Prod** environments (create new app registrations first)

---

## 🔒 Security Note

The client secret `[YOUR-CLIENT-SECRET]` is now visible in this document. Consider:
- Rotating this secret after setup is complete
- Using Azure Key Vault for secret management in production
- Implementing federated identity for enhanced security