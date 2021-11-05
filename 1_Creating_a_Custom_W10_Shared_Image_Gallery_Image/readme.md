# Using PowerShell to Create a Windows 10 Custom Image using Azure VM Image Builder

## PreReqs
You must have the latest Azure PowerShell CmdLets installed, see [here](https://docs.microsoft.com/en-us/powershell/azure/overview?view=azps-2.6.0) for install details.

```PowerShell
# Log In
Connect-AzAccount

# View current subscription
Get-AzContext

# Set subscription 
Get-AzSubscription
Set-AzContext -SubscriptionId "XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX"

# Register for Azure Image Builder Feature
Register-AzProviderFeature -FeatureName VirtualMachineTemplatePreview -ProviderNamespace Microsoft.VirtualMachineImages

Get-AzProviderFeature -FeatureName VirtualMachineTemplatePreview -ProviderNamespace Microsoft.VirtualMachineImages
# wait until RegistrationState is set to 'Registered'

# check you are registered for the providers, ensure RegistrationState is set to 'Registered'.
Get-AzResourceProvider -ProviderNamespace Microsoft.VirtualMachineImages
Get-AzResourceProvider -ProviderNamespace Microsoft.Storage 
Get-AzResourceProvider -ProviderNamespace Microsoft.Compute
Get-AzResourceProvider -ProviderNamespace Microsoft.KeyVault

# Register resource providers if not already registered
Get-AzResourceProvider -ProviderNamespace Microsoft.Compute, Microsoft.KeyVault, Microsoft.Storage, Microsoft.VirtualMachineImages |
  Where-Object RegistrationState -ne Registered |
    Register-AzResourceProvider
    
```

## Step 1: Set up environment and variables

```powerShell
# Step 1: Import module
Import-Module Az.Accounts

# Step 2: get existing context
$currentAzContext = Get-AzContext

# destination image resource group
$imageResourceGroup="RG-MI-Prod-001-PEL"

# Azure region
# Supported Regions East US, East US 2, West Central US, West US, West US 2, North Europe, West Europe
$location="westeurope"

# your subscription, this will get your current subscription
$subscriptionID=$currentAzContext.Subscription.Id

# create resource group
New-AzResourceGroup -Name $imageResourceGroup -Location $location

```

## Step 2 : Permissions, create user idenity and role for AIB

### Create user identity
```powerShell
# setup role def names, these need to be unique
$timeInt=$(get-date -UFormat "%s")
$imageRoleDefName="Azure Image Builder Image Def"+$timeInt
$idenityName="aibIdentity"+$timeInt

## Add AZ PS module to support AzUserAssignedIdentity
Install-Module -Name Az.ManagedServiceIdentity

# create identity
New-AzUserAssignedIdentity -ResourceGroupName $imageResourceGroup -Name $idenityName

$idenityNameResourceId=$(Get-AzUserAssignedIdentity -ResourceGroupName $imageResourceGroup -Name $idenityName).Id
$idenityNamePrincipalId=$(Get-AzUserAssignedIdentity -ResourceGroupName $imageResourceGroup -Name $idenityName).PrincipalId

```

### Assign permissions for identity to distribute images
This command will download and update the template with the parameters specified earlier.
```powerShell
# Assign permissions for identity to distribute images
# downloads a .json file with settings, update with subscription settings

$aibRoleImageCreationUrl="https://raw.githubusercontent.com/RaymondZaagsma/PinkAVDAIB/main/1_Creating_a_Custom_W10_Shared_Image_Gallery_Image/aibRoleImageCreation.json"
$aibRoleImageCreationPath = "aibRoleImageCreation.json"

# Download the file
Invoke-WebRequest -Uri $aibRoleImageCreationUrl -OutFile $aibRoleImageCreationPath -UseBasicParsing

# Update the file
((Get-Content -path $aibRoleImageCreationPath -Raw) -replace '<subscriptionID>',$subscriptionID) | Set-Content -Path $aibRoleImageCreationPath
((Get-Content -path $aibRoleImageCreationPath -Raw) -replace '<rgName>', $imageResourceGroup) | Set-Content -Path $aibRoleImageCreationPath
((Get-Content -path $aibRoleImageCreationPath -Raw) -replace 'Azure Image Builder Service Image Creation Role', $imageRoleDefName) | Set-Content -Path $aibRoleImageCreationPath

# create role definition
New-AzRoleDefinition -InputFile  .\aibRoleImageCreation.json

# grant role definition to image builder service principal
New-AzRoleAssignment -ObjectId $idenityNamePrincipalId -RoleDefinitionName $imageRoleDefName -Scope "/subscriptions/$subscriptionID/resourceGroups/$imageResourceGroup"

# Verify Role Assignment
Get-AzRoleAssignment -ObjectId $idenityNamePrincipalId | Select-Object DisplayName,RoleDefinitionId

### NOTE: If you see this error: 'New-AzRoleDefinition: Role definition limit exceeded. No more role definitions can be created.' See this article to resolve:
https://docs.microsoft.com/en-us/azure/role-based-access-control/troubleshooting

```

## Step 3 : Create the Shared Image Gallery

```powerShell
$sigGalleryName= "SIG_AVD_Prod_001_PEL"
$imageDefName ="AVD_W10_Prod_002_PEL"
$imageDefNameversion = "AVD_W10_Prod_002_rev02_PEL"

# create gallery
New-AzGallery -GalleryName $sigGalleryName -ResourceGroupName $imageResourceGroup  -Location $location

# create gallery definition

$ParamNewAzGalleryImageDefinition = @{
  GalleryName       = $sigGalleryName
  ResourceGroupName = $imageResourceGroup
  Location          = $location
  Name              = $imageDefName
  OsState           = 'generalized'
  OsType            = 'Windows'
  Publisher         = 'PEL-AVD-Rev01'
  Offer             = 'PEL-W10-Rev01'
  Sku               = 'PEL-20h1-evd-Rev01'
}


New-AzGalleryImageDefinition @ParamNewAzGalleryImageDefinition


```

# Configure the Image Template
This command will download and update the template with the parameters specified earlier.
```powerShell

# name of the image to be created
$imageName="AVDPinkImgWin10"

# image template name
$imageTemplateName="AVDPinkImageTemplateWin10"

# distribution properties object name (runOutput), i.e. this gives you the properties of the managed image on completion
$runOutputName="winclientR01"
```
Windows 10 Enterprise Multisession Gen 2
```powerShell
$publisher = 'MicrosoftWindowsDesktop'
$offer = 'Windows-10'
$sku = '21h1-evd-g2'
$baseosimg = 'Windows10Multi'

```

Windows 10 Enterprise Multisession + Microsoft 365 Apps Gen 2
```powerShell
$publisher = 'MicrosoftWindowsDesktop'
$offer = 'office-365'
$sku = '21h1-evd-o365pp-g2'
$baseosimg = 'W10MultiO365'

```
Windows 11 Enterprise Multisession Gen 2
```powerShell
$publisher = 'MicrosoftWindowsDesktop'
$offer = 'Windows-11'
$sku = 'win11-21h2-avd'
$baseosimg = 'Windows11Multi'

```
Windows 11 Enterprise Multisession + Microsoft 365 Apps Gen 2
```powerShell
$publisher = 'MicrosoftWindowsDesktop'
$offer = 'office-365'
$sku = 'win11-21h2-avd-m365'
$baseosimg = 'W11MultiO365'

```
## Upload Customization zip to Azure Storage Container

Create Storage account in ImageResourceGroup  
Create Container in Storage Account  
Upload Software Zip file to Container   
Generate SAS token and copy Blob SAS URL and past url in variable $archiveSas

## Add the file archive Shared Access Signature
```powerShell
$archiveSas = "Sas Token Here"
$installScript = 'https://raw.githubusercontent.com/RaymondZaagsma/PinkAVDAIB/main/1_Creating_a_Custom_W10_Shared_Image_Gallery_Image/Install-Applications.ps1'


$templateUrl="https://raw.githubusercontent.com/RaymondZaagsma/PinkAVDAIB/main/1_Creating_a_Custom_W10_Shared_Image_Gallery_Image/armTemplateWinSIG.json"
$templateFilePath = "armTemplateWinSIG.json"

Invoke-WebRequest -Uri $templateUrl -OutFile $templateFilePath -UseBasicParsing

((Get-Content -path $templateFilePath -Raw) -replace '<subscriptionID>',$subscriptionID) | Set-Content -Path $templateFilePath
((Get-Content -path $templateFilePath -Raw) -replace '<rgName>',$imageResourceGroup) | Set-Content -Path $templateFilePath
((Get-Content -path $templateFilePath -Raw) -replace '<region>',$location) | Set-Content -Path $templateFilePath
((Get-Content -path $templateFilePath -Raw) -replace '<runOutputName>',$runOutputName) | Set-Content -Path $templateFilePath

((Get-Content -path $templateFilePath -Raw) -replace '<imageDefName>',$imageDefName) | Set-Content -Path $templateFilePath
((Get-Content -path $templateFilePath -Raw) -replace '<sharedImageGalName>',$sigGalleryName) | Set-Content -Path $templateFilePath
((Get-Content -path $templateFilePath -Raw) -replace '<region1>',$location) | Set-Content -Path $templateFilePath
((Get-Content -path $templateFilePath -Raw) -replace '<region2>',$replRegion2) | Set-Content -Path $templateFilePath

((Get-Content -path $templateFilePath -Raw) -replace '<imgBuilderId>',$idenityNameResourceId) | Set-Content -Path $templateFilePath

((Get-Content -path $templateFilePath -Raw) -replace '<Shared Access Signature to archive file>',$archiveSas) | Set-Content -Path $templateFilePath
((Get-Content -path $templateFilePath -Raw) -replace '<URI to PowerShell Script>',$installScript ) | Set-Content -Path $templateFilePath

((Get-Content -path $templateFilePath -Raw) -replace '<Publisher>',$publisher ) | Set-Content -Path $templateFilePath
((Get-Content -path $templateFilePath -Raw) -replace '<offer>',$offer ) | Set-Content -Path $templateFilePath
((Get-Content -path $templateFilePath -Raw) -replace '<sku>',$sku ) | Set-Content -Path $templateFilePath
((Get-Content -path $templateFilePath -Raw) -replace '<baseosimg>',$baseosimg ) | Set-Content -Path $templateFilePath
((Get-Content -path $templateFilePath -Raw) -replace '<version>',$imageDefNameversion ) | Set-Content -Path $templateFilePath

```


# Submit the template
Your template must be submitted to the service, this will download any dependent artifacts (scripts etc), validate, check permissions, and store them in the staging Resource Group, prefixed, *IT_*.
```powerShell
New-AzResourceGroupDeployment -ResourceGroupName $imageResourceGroup -TemplateFile $templateFilePath -api-version "2019-05-01-preview" -imageTemplateName $imageTemplateName -svclocation $location
```
 
# Build the image
To build the image you need to invoke 'Run'.

```powerShell
Invoke-AzResourceAction -ResourceName $imageTemplateName -ResourceGroupName $imageResourceGroup -ResourceType Microsoft.VirtualMachineImages/imageTemplates -ApiVersion "2019-05-01-preview" -Action Run -Force
```
>> Note, the command will not wait for the image builder service to complete the image build, you can query the status below.
