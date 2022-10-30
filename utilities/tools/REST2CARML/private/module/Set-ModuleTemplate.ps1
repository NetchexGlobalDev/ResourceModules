﻿<#
.SYNOPSIS
Update the module's primary template (deploy.bicep) as per the provided module data.

.DESCRIPTION
Update the module's primary template (deploy.bicep) as per the provided module data.

.PARAMETER FullResourceType
Mandatory. The complete ResourceType identifier to update the template for (e.g. 'Microsoft.Storage/storageAccounts').

.PARAMETER ModuleData
Mandatory. The module data (e.g. parameters) to add to the template.

.PARAMETER FullModuleData
Mandatory. The full stack of module data of all modules included in the original invocation. May be used for parent-child references.

.PARAMETER JSONFilePath
Mandatory. The service specification file to process.

.PARAMETER UrlPath
Mandatory. The API Path in the JSON specification file to process

.EXAMPLE
Set-ModuleTemplate -FullResourceType 'Microsoft.KeyVault/vaults' -ModuleData @{ parameters = @(...); resource = @(...); (...) } -JSONFilePath '(...)/resource-manager/Microsoft.KeyVault/stable/2022-07-01/keyvault.json' -UrlPath '/subscriptions/{subscriptionId}/resourceGroups/{resourceGroupName}/providers/Microsoft.KeyVault/vaults/{vaultName}' -FullModuleData @(@{ parameters = @(...); resource = @(...); (...) }, @{...})

Update the module [Microsoft.KeyVault/vaults] with the provided module data.
#>
function Set-ModuleTemplate {

    [CmdletBinding(SupportsShouldProcess)]
    param (
        [Parameter(Mandatory = $true)]
        [string] $FullResourceType,

        [Parameter(Mandatory = $true)]
        [array] $ModuleData,

        [Parameter(Mandatory = $true)]
        [array] $FullModuleData,

        [Parameter(Mandatory = $true)]
        [string] $JSONFilePath,

        [Parameter(Mandatory = $true)]
        [string] $UrlPath
    )

    begin {
        Write-Debug ('{0} entered' -f $MyInvocation.MyCommand)

        $templateFilePath = Join-Path $script:repoRoot 'modules' $FullResourceType 'deploy.bicep'
        $providerNamespace = ($FullResourceType -split '/')[0]
        $resourceType = $FullResourceType -replace "$providerNamespace/", ''
    }

    process {

        #####################
        ##   Collect Data   #
        #####################

        # Existing template (if any)
        $existingTemplateContent = Resolve-ExistingTemplateContent -TemplateFilePath $templateFilePath

        # Collect child-resource information
        $linkedChildren = $fullmoduleData | Where-Object {
            # Is nested
            $_.identifier -like "$FullResourceType/*" -and
            # Is direct child
            (($_.identifier -split '/').Count -eq (($FullResourceType -split '/').Count + 1)
            )
        }
        ##  Add indirect child (via proxy resource) (i.e. it's a nested-nested resources who's parent has no individual specification/JSONFilePath). TODO: Is that always true? What if the data is specified in one file?x`
        $indirectChildren = $FullModuleData | Where-Object {
            # Is nested
            $_.identifier -like "$FullResourceType/*" -and
            # Is indirect child
            (($_.identifier -split '/').Count -eq (($FullResourceType -split '/').Count + 2))
        } | Where-Object {
            # If the child's parent's parentUrlPath is empty, this parent has no PUT rest command which indicates it cannot be created independently
            [String]::IsNullOrEmpty($_.metadata.parentUrlPath)
        }
        $linkedChildren += $indirectChildren

        # Collect parent resources to use for parent type references
        $typeElem = $FullResourceType -split '/'
        if ($typeElem.Count -gt 2) {
            $parentResourceTypes = $typeElem[1..($typeElem.Count - 2)]
        } else {
            $parentResourceTypes = @()
        }

        # Collect all parent references for 'exiting' resource references
        $fullParentResourceStack = Get-ParentResourceTypeList -ResourceType $FullResourceType

        # Get the singular version of the current resource type for proper naming
        $resourceTypeSingular = ((Get-ResourceTypeSingularName -ResourceType $resourceType) -split '/')[-1]

        # Handle parent proxy, if any
        $hasAProxyParent = $FullModuleData.identifier -notContains ((Split-Path $FullResourceType -Parent) -replace '\\', '/')
        $parentProxyName = $hasAProxyParent ? ($UrlPath -split '\/')[-3] : ''
        $proxyParentType = Split-Path (Split-Path $FullResourceType -Parent) -Leaf

        ##################
        ##  PARAMETERS  ##
        ##################

        $targetScope = Get-TargetScope -UrlPath $UrlPath

        $templateContent = ($targetScope -ne 'resourceGroup') ? @(
            "targetScope = '{0}'" -f $targetScope,
            ''
        ) : @()

        $templateContent += @(
            '// ============== //'
            '//   Parameters   //'
            '// ============== //'
            ''
        )

        # Collect parameters to create
        # ----------------------------
        $parametersToAdd = @()

        # Add parent parameters
        foreach ($parentResourceType in ($parentResourceTypes | Sort-Object)) {
            $thisParentIsProxy = $hasAProxyParent -and $parentResourceType -eq $proxyParentType

            $parentParamData = @{
                level       = 0
                name        = '{0}Name' -f (Get-ResourceTypeSingularName -ResourceType $parentResourceType)
                type        = 'string'
                description = '{0}. The name of the parent {1}. Required if the template is used in a standalone deployment.' -f ($thisParentIsProxy ? 'Optional' : 'Conditional'), $parentResourceType
                required    = $false
            }

            if ($thisParentIsProxy) {
                # Handle proxy parents (i.e., empty containers with only a default value name)
                $parentParamData['default'] = $parentProxyName
            }

            $parametersToAdd += $parentParamData
        }

        # Add primary (service) parameters (i.e. top-level and those in the properties)
        $parametersToAdd += @() + ($ModuleData.parameters | Where-Object { $_.Level -in @(0, 1) -and $_.name -ne 'properties' -and ([String]::IsNullOrEmpty($_.Parent) -or $_.Parent -eq 'properties') })


        # Add additional (extension) parameters
        $parametersToAdd += $ModuleData.additionalParameters

        # Add child module references
        foreach ($dataBlock in ($linkedChildren | Sort-Object -Property 'identifier')) {
            $childResourceType = ($dataBlock.identifier -split '/')[-1]
            $parametersToAdd += @{
                level       = 0
                name        = $childResourceType
                type        = 'array'
                default     = @()
                description = "The $childResourceType to create as part of the $resourceTypeSingular."
                required    = $false
            }
        }

        # Add telemetry parameter
        $parametersToAdd += @{
            level       = 0
            name        = 'enableDefaultTelemetry'
            type        = 'boolean'
            default     = $true
            description = 'Enable telemetry via the Customer Usage Attribution ID (GUID).'
            required    = $false
        }

        # Create collected parameters
        # ---------------------------
        # TODO: Only update parameters that are not already defines
        # First the required
        foreach ($parameter in ($parametersToAdd | Where-Object { $_.required } | Sort-Object -Property 'Name')) {
            $templateContent += Get-FormattedModuleParameter -ParameterData $parameter
        }
        # Then the conditional
        foreach ($parameter in ($parametersToAdd | Where-Object { -not $_.required -and $_.description -like 'Conditional. *' } | Sort-Object -Property 'Name')) {
            $templateContent += Get-FormattedModuleParameter -ParameterData $parameter
        }
        # Then the rest
        foreach ($parameter in ($parametersToAdd | Where-Object { -not $_.required -and $_.description -notlike 'Conditional. *' } | Sort-Object -Property 'Name')) {
            $templateContent += Get-FormattedModuleParameter -ParameterData $parameter
        }

        #################
        ##  VARIABLES  ##
        #################

        foreach ($variable in $ModuleData.variables) {
            $templateContent += $variable
        }
        # Add telemetry variable
        if ($linkedChildren.Count -gt 0) {
            $templateContent += @(
                'var enableReferencedModulesTelemetry = false'
                ''
            )
        }

        ###################
        ##  DEPLOYMENTS  ##
        ###################

        $locationParameterExists = ($templateContent | Where-Object { $_ -like 'param location *' }).Count -gt 0

        $templateContent += @(
            ''
            '// =============== //'
            '//   Deployments   //'
            '// =============== //'
            ''
        )

        # Add telemetry resource
        # ----------------------
        $telemetryTemplate = Get-Content -Path (Join-Path $Script:src 'telemetry.bicep')
        if (-not $locationParameterExists) {
            # Remove the location from the deployment name if the template has no such parameter
            $telemetryTemplate = $telemetryTemplate -replace ', location', ''
        }
        $templateContent += $telemetryTemplate
        $templateContent += ''

        # Add 'existing' parents (if any)
        # -------------------------------
        $existingResourceIndent = 0
        $orderedParentResourceTypes = $fullParentResourceStack | Where-Object { $_ -notlike $FullResourceType } | Sort-Object
        foreach ($parentResourceType in $orderedParentResourceTypes) {
            $singularParent = ((Get-ResourceTypeSingularName -ResourceType $parentResourceType) -split '/')[-1]
            $levedParentResourceType = ($parentResourceType -ne (@() + $orderedParentResourceTypes)[0]) ? (Split-Path $parentResourceType -Leaf) : $parentResourceType
            $parentJSONPath = ($FullModuleData | Where-Object { $_.identifier -eq $parentResourceType }).Metadata.JSONFilePath

            if ([String]::IsNullOrEmpty($parentJSONPath)) {
                # Case: A child who's parent resource does not exist (i.e., is a proxy). In this case we use the current API paths as a fallback
                # Example: 'Microsoft.AVS/privateClouds/workloadNetworks' is not actually existing as a parent for 'Microsoft.AVS/privateClouds/workloadNetworks/dhcpConfigurations'
                $parentJSONPath = $JSONFilePath
            }

            $parentResourceAPI = Split-Path (Split-Path $parentJSONPath -Parent) -Leaf
            $templateContent += @(
                "$(' ' * $existingResourceIndent)resource $($singularParent) '$($levedParentResourceType)@$($parentResourceAPI)' existing = {",
                "$(' ' * $existingResourceIndent)    name: $($singularParent)Name"
            )
            if ($parentResourceType -ne $orderedParentResourceTypes[-1]) {
                # Only add an empty line if there is more content to add
                $templateContent += ''
            }
            $existingResourceIndent += 4
        }
        # Add closing brakets
        foreach ($parentResourceType in ($fullParentResourceStack | Where-Object { $_ -notlike $FullResourceType } | Sort-Object)) {
            $existingResourceIndent -= 4
            $templateContent += "$(' ' * $existingResourceIndent)}"
        }
        $templateContent += ''

        # Add primary resource
        # --------------------
        # Deployment resource declaration line
        $serviceAPIVersion = Split-Path (Split-Path $JSONFilePath -Parent) -Leaf
        $templateContent += "resource $resourceTypeSingular '$FullResourceType@$serviceAPIVersion' = {"

        if (($FullResourceType -split '/').Count -ne 2) {
            # In case of children, we set the 'parent' to the next parent
            $templateContent += ('  parent: {0}' -f (($parentResourceTypes | ForEach-Object { Get-ResourceTypeSingularName -ResourceType $_ }) -join '::'))
        }

        foreach ($parameter in ($ModuleData.parameters | Where-Object { $_.level -eq 0 -and $_.name -ne 'properties' })) {
            $templateContent += '  {0}: {0}' -f $parameter.name
        }

        $templateContent += '  properties: {'
        foreach ($parameter in ($ModuleData.parameters | Where-Object { $_.level -eq 1 -and $_.Parent -eq 'properties' })) {
            $templateContent += '    {0}: {0}' -f $parameter.name
        }

        $templateContent += @(
            '  }'
            '}'
            ''
        )


        # Add additional resources such as extensions (like RBAC)
        # -------------------------------------------------------
        # Other collected resources
        $templateContent += $ModuleData.resources

        # Add child-module references
        # ---------------------------
        foreach ($dataBlock in $linkedChildren) {
            $childResourceType = ($dataBlock.identifier -split '/')[-1]
            $childResourceTypeSingular = Get-ResourceTypeSingularName -ResourceType $childResourceType

            $hasProxyParent = [String]::IsNullOrEmpty($dataBlock.metadata.parentUrlPath)
            if ($hasProxyParent) {
                $proxyParentName = Split-Path (Split-Path $dataBlock.identifier -Parent) -Leaf
            }

            $templateContent += @(
                "module $($hasProxyParent ? "$($proxyParentName)_" : '')$($resourceTypeSingular)_$($childResourceType) '$($hasProxyParent ? "$proxyParentName/" : '')$($childResourceType)/deploy.bicep' = [for ($($childResourceTypeSingular), index) in $($childResourceType): {",
                "name: '`${uniqueString(deployment().name$($locationParameterExists ? ', location' : ''))}-$($resourceTypeSingular)-$($childResourceTypeSingular)-`${index}'",
                'params: {'
            )

            # All param names of parents
            foreach ($parentResourceType in $parentResourceTypes) {
                $templateContent += '    {0}Name: {0}Name' -f ((Get-ResourceTypeSingularName -ResourceType $parentResourceType) -split '/')[-1]
            }
            # Itself
            $templateContent += '    {0}Name: name' -f ((Get-ResourceTypeSingularName -ResourceType ($FullResourceType -split '/')[-1]) -split '/')[-1]

            # Any proxy default if any
            if ($hasProxyParent) {
                $proxyDefaultValue = ($dataBlock.metadata.urlPath -split '\/')[-3]
                $templateContent += "    {0}Name: '{1}'" -f (Get-ResourceTypeSingularName -ResourceType ($proxyParentName -split '/')[-1]), $proxyDefaultValue
            }

            # Add primary child parameters
            $allParam = $dataBlock.data.parameters + $dataBlock.data.additionalParameters
            foreach ($parameter in ($allParam | Where-Object { $_.Level -in @(0, 1) -and $_.name -ne 'properties' -and ([String]::IsNullOrEmpty($_.Parent) -or $_.Parent -eq 'properties') })) {
                $wouldBeParameter = Get-FormattedModuleParameter -ParameterData $parameter | Where-Object { $_ -like 'param *' } | ForEach-Object { $_ -replace 'param ', '' }
                $wouldBeParamElem = $wouldBeParameter -split ' = '
                $parameter.name = ($wouldBeParamElem -split ' ')[0]
                if ($wouldBeParamElem.count -gt 1) {
                    # With default

                    if ($parameter.name -eq 'lock') {
                        # Special handling as we pass the parameter down to the child
                        $templateContent += "    lock: contains($($childResourceTypeSingular), 'lock') ? $($childResourceTypeSingular).lock : lock"
                        continue
                    }

                    $wouldBeParamValue = $wouldBeParamElem[1]

                    # Special case, location function - should reference a location parameter instead
                    if ($wouldBeParamValue -like '*().location') {
                        $wouldBeParamValue = 'location'
                    }

                    $templateContent += "    $($parameter.name): contains($($childResourceTypeSingular), '$($parameter.name)') ? $($childResourceTypeSingular).$($parameter.name) : $($wouldBeParamValue)"
                } else {
                    # No default
                    $templateContent += "    $($parameter.name): $($childResourceTypeSingular).$($parameter.name)"
                }
            }

            $templateContent += @(
                # Special handling as we pass the variable down to the child
                '    enableDefaultTelemetry: enableReferencedModulesTelemetry'
                '  }'
                '}]'
                ''
            )
        }

        #######################################
        ##  Create template outputs section  ##
        #######################################

        # Output header comment
        $templateContent += @(
            '// =========== //'
            '//   Outputs   //'
            '// =========== //'
            ''
            "@description('The name of the $resourceTypeSingular.')"
            "output name string = $resourceTypeSingular.name"
            ''
            "@description('The resource ID of the $resourceTypeSingular.')"
            "output resourceId string = $resourceTypeSingular.id"
            ''
        )

        if ($targetScope -eq 'resourceGroup') {
            $templateContent += @(
                "@description('The name of the resource group the $resourceTypeSingular was created in.')"
                'output resourceGroupName string = resourceGroup().name'
                ''
            )
        }

        # Update file
        # -----------
        Set-Content -Path $templateFilePath -Value ($templateContent | Out-String).TrimEnd() -Force
    }

    end {
        Write-Debug ('{0} exited' -f $MyInvocation.MyCommand)
    }
}