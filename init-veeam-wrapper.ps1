<# 
.SYNOPSIS 
 Connect to the veeam webAPI to populate backup data in a Neo4j GraphDB
 
.DESCRIPTION 
By providing the Veeam API URL, the credentials for Veeam and Neo4j, a session will be opened to populate your database
with labels, properties and relationships between Veeam servers, jobs, restoration points, and protected VMs. 

example:
./init-veeam-wrapper.ps1 -baseapiurl "htttp://myveeamserver.mydomain.com:9399" -veeamcred myveeam -neo4jdatasource myneo4jserver

The veeamcred and neo4jdatasource profiles must have already been created using the set-regcredentials.ps1 and must have been
run as the same user account that is running init-veeam-wrapper.ps1

.NOTES 
┌─────────────────────────────────────────────────────────────────────────────────────────────┐ 
│ init-veeam-wrapper.ps1                                                                      │ 
├─────────────────────────────────────────────────────────────────────────────────────────────┤ 
│   DATE        : 11.03.2019 				               									  │ 
│   AUTHOR      : Paul Drangeid 			                   								  │ 
│   SITE        : https://blog.graphcommit.com/                                               │ 
└─────────────────────────────────────────────────────────────────────────────────────────────┘ 
#> 

param (
    [Parameter(mandatory=$true)]
    [string]$baseapiurl,
    [Parameter(mandatory=$true)]
    [string]$veeamcred,
    [string]$neo4jdatasource,
    [switch]$sessionkey,
    [int]$verbosity
    )

Try{. "$PSScriptRoot\bg-sharedfunctions.ps1" | Out-Null}

Catch{
    Write-Warning "I wasn't able to load the sharedfunctions includes (which should live in the same directory as $global:srccmdline). `nWe are going to bail now, sorry 'bout that!"
    Write-Host "Try running them manually, and see what error message is causing this to puke: $PSScriptRoot\bg-sharedfunctions.ps1"
    Unregister-PSVars
    BREAK
    }

    # Retrieve the credentials from the current users' registry.  
    # If you haven't yet stored these credentials use the following powershell command:
    # ./set-regcredentials.ps1 -credname edc-veeam -defaultuser domain\myveeamuser -credpath neo4j-wrapper\Credentials
    Show-onscreen $("`nValidate credentials for $veeamcred") 2
$Path = "HKCU:\Software\neo4j-wrapper\Credentials\$veeamcred"
$veeamuser=Ver-RegistryValue -RegPath $Path -Name $($veeamcred+"User")
$veeampw=Get-SecurePassword $Path $($veeamcred+"PW")
$pair = "$($veeamuser):$($veeampw)"
Remove-Variable -name veeampw | Out-Null
$encodedveeamCreds=[System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($pair))
Remove-Variable -name pair | Out-Null

$apiurl="$baseapiurl/sessionMngr/?v=latest"
$response=(Invoke-WebRequest $apiurl -Method 'POST' -Headers @{"Authorization"="Basic $encodedveeamCreds";Accept="application/json"} -ErrorVariable RestError)
$veeamapisession=$($response.headers["X-RestSvcSessionId"])

Remove-Variable -name encodedveeamCreds | Out-Null

if ($sessionkey -eq $true){
    #$sessionkey switch indicates I just want to generate and return a valid session key.
    #This is a quick way to get a key so you can run your own manual queries for testing.
    write-host "Session id: $veeamapisession"
    exit
}

$scriptpath = -join ($PSScriptRoot,"\get-cypher-results.ps1")
$csp= -join ($PSScriptRoot,'\refresh-veeam.cypher')
$findstring='{"base-veeam-api-url":"'+$baseapiurl+'","veeam-restsvc-sessionid":"'+$veeamapisession+'"}'
Show-onscreen $("`nExecuting the following:`n. $scriptPath -Datasource $neo4jdatasource -cypherscript $csp -logging $neo4jdatasource -findrep $findstring -verbosity $verbosity`n ") 4
#$result = . $scriptPath -Datasource $neo4jdatasource -cypherscript $csp -logging $neo4jdatasource -findrep $findstring -verbosity 4
. $scriptPath -Datasource $neo4jdatasource -cypherscript $csp -logging $neo4jdatasource -findrep $findstring -verbosity $verbosity

Remove-Variable -name veeamapisession | Out-Null

