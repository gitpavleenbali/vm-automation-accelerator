# Contributing to VM Automation Accelerator

First off, thank you for considering contributing to the VM Automation Accelerator! It's people like you that make this solution better for the Azure community.

## 📋 Table of Contents

- [How Can I Contribute?](#how-can-i-contribute)
- [Development Setup](#development-setup)
- [Pull Request Process](#pull-request-process)
- [Style Guidelines](#style-guidelines)
- [Community](#community)

## 🤝 How Can I Contribute?

### Reporting Bugs

Before creating bug reports, please check existing issues to avoid duplicates. When you create a bug report, include as many details as possible:

- **Use a clear and descriptive title**
- **Describe the exact steps to reproduce the problem**
- **Provide specific examples** (code snippets, configuration files)
- **Describe the behavior you observed** and what you expected
- **Include logs, error messages, or screenshots**
- **Specify your environment**: Azure region, subscription type, OS version, etc.

#### Bug Report Template

```markdown
**Description**
A clear description of the bug.

**To Reproduce**
Steps to reproduce:
1. Go to '...'
2. Run command '...'
3. See error

**Expected Behavior**
What you expected to happen.

**Actual Behavior**
What actually happened.

**Environment**
- Azure Region: [e.g., westeurope]
- Subscription Type: [e.g., Enterprise Agreement]
- OS: [e.g., Windows Server 2022]
- Terraform Version: [e.g., 1.5.0]

**Additional Context**
Any other relevant information.
```

### Suggesting Enhancements

Enhancement suggestions are tracked as GitHub issues. When creating an enhancement suggestion:

- **Use a clear and descriptive title**
- **Provide a detailed description** of the suggested enhancement
- **Explain why this enhancement would be useful** to most users
- **List any similar features** in other solutions
- **Provide examples** of how the enhancement would work

### Contributing Code

1. **Fork the repository** and create your branch from `main`
2. **Make your changes** following our style guidelines
3. **Test your changes** thoroughly
4. **Update documentation** if needed
5. **Submit a pull request**

## 🛠️ Development Setup

### Prerequisites

- **Azure Subscription** with Contributor access
- **Azure CLI** or **Azure PowerShell** installed
- **Terraform** (for infrastructure development)
- **PowerShell 7+** (for script development)
- **Python 3.8+** (for Python scripts)
- **Git** for version control

### Local Setup

```bash
# Clone your fork
git clone https://github.com/YOUR-USERNAME/vm-automation-accelerator.git
cd vm-automation-accelerator

# Add upstream remote
git remote add upstream https://github.com/yourorg/vm-automation-accelerator.git

# Create a branch for your feature
git checkout -b feature/your-feature-name
```

### Testing Your Changes

#### Terraform Validation

```bash
# Format Terraform files
terraform fmt -recursive

# Validate Terraform configuration
terraform validate

# Run Terraform plan (dry-run)
terraform plan -var-file="environments/dev.tfvars"
```

#### PowerShell Script Testing

```powershell
# Run PSScriptAnalyzer
Install-Module -Name PSScriptAnalyzer -Force
Invoke-ScriptAnalyzer -Path deploy/scripts/utilities/vm-operations/security/Your-Script.ps1

# Run Pester tests (if available)
Invoke-Pester
```

#### Python Script Testing

```bash
# Install dependencies
pip install -r requirements-dev.txt

# Run linting
pylint deploy/scripts/utilities/servicenow/your_script.py

# Run tests
pytest tests/
```

## 🔄 Pull Request Process

### Before Submitting

- [ ] Code follows the style guidelines
- [ ] Self-review of code completed
- [ ] Comments added for complex logic
- [ ] Documentation updated
- [ ] Tests added/updated
- [ ] All tests pass
- [ ] Terraform linting passes
- [ ] No breaking changes (or clearly documented)

### Pull Request Template

```markdown
## Description
Brief description of changes.

## Type of Change
- [ ] Bug fix (non-breaking change fixing an issue)
- [ ] New feature (non-breaking change adding functionality)
- [ ] Breaking change (fix or feature causing existing functionality to not work as expected)
- [ ] Documentation update

## Testing
Describe testing performed.

## Checklist
- [ ] Code follows style guidelines
- [ ] Self-review completed
- [ ] Documentation updated
- [ ] Tests added/updated
- [ ] All tests pass
- [ ] No breaking changes

## Related Issues
Closes #(issue number)
```

### Review Process

1. **Automated checks** will run (linting, validation)
2. **Maintainers will review** your code
3. **Address feedback** if requested
4. **Approval** required from at least one maintainer
5. **Merge** will be performed by maintainers

## 📝 Style Guidelines

### Terraform (HCL)

- Follow **Terraform Best Practices**
- Use **descriptive variable names**
- Include **descriptions** for all variables and outputs
- Use **consistent naming** conventions
- Add **comments** for complex logic

```hcl
# Good example
variable "vm_name" {
  description = "The name of the virtual machine"
  type        = string
}

variable "vm_size" {
  description = "The size of the virtual machine"
  type        = string
  default     = "Standard_D2s_v3"
}

resource "azurerm_virtual_machine" "vm" {
  name                = var.vm_name
  location            = var.location
  
  vm_size = var.vm_size
}
```

### PowerShell

- Follow **PowerShell Best Practices**
- Use **approved verbs** (Get, Set, New, Remove, etc.)
- Include **comment-based help**
- Use **CmdletBinding** for advanced functions
- **PascalCase** for function names, **camelCase** for variables

```powershell
<#
.SYNOPSIS
    Brief description.

.DESCRIPTION
    Detailed description.

.PARAMETER Name
    Parameter description.

.EXAMPLE
    Example-Command -Name "value"
#>
function Example-Command {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name
    )
    
    # Implementation
}
```

### Python

- Follow **PEP 8** style guide
- Use **type hints** for function signatures
- Include **docstrings** for all functions/classes
- Use **snake_case** for variables and functions

```python
def example_function(param: str) -> dict:
    """
    Brief description.
    
    Args:
        param: Parameter description.
        
    Returns:
        Description of return value.
        
    Raises:
        Exception: When something goes wrong.
    """
    return {"result": param}
```

### YAML (Pipelines)

- Use **2-space indentation**
- Include **comments** for stages and jobs
- Use **descriptive names** for steps
- Group **related variables**

```yaml
# Stage: Deployment
stages:
  - stage: Deploy
    displayName: 'Deploy Infrastructure'
    jobs:
      - job: DeployTerraform
        displayName: 'Deploy Terraform Templates'
        steps:
          - task: AzureCLI@2
            displayName: 'Deploy to Azure'
            inputs:
              azureSubscription: $(azureSubscription)
```

### Markdown (Documentation)

- Use **clear headings** and structure
- Include **code examples** where appropriate
- Add **links** to related documentation
- Use **tables** for structured data
- Include **emojis** for visual clarity (sparingly)

## 🏷️ Commit Message Guidelines

Follow the [Conventional Commits](https://www.conventionalcommits.org/) specification:

```
<type>(<scope>): <subject>

<body>

<footer>
```

### Types

- **feat**: A new feature
- **fix**: A bug fix
- **docs**: Documentation changes
- **style**: Code style changes (formatting, no logic change)
- **refactor**: Code refactoring
- **test**: Adding or updating tests
- **chore**: Maintenance tasks

### Examples

```
feat(terraform): add support for availability zones

Add availability zone configuration to VM deployment module.
Includes parameters for zone selection and load balancer setup.

Closes #123
```

```
fix(pipeline): correct approval gate timeout

The approval gate was timing out too quickly in production.
Increased timeout from 1 hour to 24 hours.

Fixes #456
```

## 🌍 Community

### Getting Help

- **GitHub Discussions**: For questions and discussions
- **GitHub Issues**: For bug reports and feature requests
- **Stack Overflow**: Tag with `azure-vm-automation-accelerator`

### Recognition

Contributors will be recognized in:
- README.md Contributors section
- Release notes for significant contributions
- GitHub contributors page

## 📚 Additional Resources

- [Terraform Documentation](https://www.terraform.io/docs)
- [Terraform Azure Provider](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs)
- [Azure DevOps Pipelines](https://docs.microsoft.com/azure/devops/pipelines/)

## 📄 License

By contributing, you agree that your contributions will be licensed under the [MIT License](LICENSE).

---

**Thank you for contributing to the VM Automation Accelerator!** 🎉

Your contributions help make Azure automation more accessible to everyone.
