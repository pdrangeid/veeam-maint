<# 
.SYNOPSIS 
 Connect to the Veeam Backup Enterprise Manager webAPI to populate backup data in a Neo4j GraphDB
 
.DESCRIPTION 
By providing the Veeam API URL, the credentials for Veeam and Neo4j, a session will be opened to populate your database
with labels, properties and relationships between Veeam servers, jobs, restoration points, and protected VMs. 

example:
./init-veeam-wrapper.ps1 -baseapiurl "htttp://myveeamserver.mydomain.com:9399" -veeamcred myveeam -neo4jdatasource myneo4jserver -days 7

The veeamcred and neo4jdatasource profiles must have previously been configured using the set-regcredentials.ps1 and must have been
run as the same user account that is now running init-veeam-wrapper.ps1

.NOTES 
┌─────────────────────────────────────────────────────────────────────────────────────────────┐ 
│ init-veeam-wrapper.ps1                                                                      │ 
├─────────────────────────────────────────────────────────────────────────────────────────────┤ 
│   DATE        : 11.20.2019 				               									  │ 
│   AUTHOR      : Paul Drangeid 			                   								  │ 
│   SITE        : https://blog.graphcommit.com/                                               │ 
│   PARAMETERS  : -baseapiurl                  :URL of your Veeam API including port          │ 
│               : -veeamcred                   :Name of Veeam credential                      │ 
│               : -neo4jdatasource             :Datasource name for n4j location and creds    │ 
│               : -nsessionkey                 :Don't run the script, just supply a valid key │ 
│               : -verbosity                   :Level of on-screen messaging (0-4)            │ 
│               : -days                        :how many days of backups to query             │ 
│               : -init                        :Run Veeam importfor the first time            │ 
│   PREREQS     :                                                                             │ 
│               : Credentials for the Veeam Backup Enterprise Manager webAPI                  │ 
│               : Other script modules:                                                       │ 
│               : see blog SITE above for other modules needed to run this                    │ 
└─────────────────────────────────────────────────────────────────────────────────────────────┘ 
#> 

param (
    [Parameter(mandatory=$true)]
    [string]$baseapiurl,
    [Parameter(mandatory=$true)]
    [string]$veeamcred,
    [string]$neo4jdatasource,
    [switch]$sessionkey,
    [int]$verbosity,
    [int]$days,
    [switch]$init
    )

    if ($null -eq $verbosity){[int]$verbosity=1} #verbosity level is 1 by default

    if ($null -eq $days){[int]$days=1} #days is 1 by default

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

# Now we have the Veeam username & password.  We need to convert them to base64 to use as a parameter when querying the 
# Veeam Backup Enterprise Manager webAPI
$encodedveeamCreds=[System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($pair))
Remove-Variable -name veeampw | Out-Null
Remove-Variable -name veeamuser | Out-Null
Remove-Variable -name pair | Out-Null

# Let's open a WebRequest to get a valid sessionkey so we can interact with the Veeam Backup Enterprise Manager webAPI
$apiurl="$baseapiurl/sessionMngr/?v=latest"
$response=(Invoke-WebRequest $apiurl -Method 'POST' -Headers @{"Authorization"="Basic $encodedveeamCreds";Accept="application/json"} -ErrorVariable RestError)
$veeamapisession=$($response.headers["X-RestSvcSessionId"])
Remove-Variable -name encodedveeamCreds | Out-Null

if ($sessionkey -eq $true){
    #$sessionkey switch tells this script you just want to generate and return a valid session key.
    #This is a quick way to get a key so you can run your own manual queries for testing.
    write-host "Session id: $veeamapisession"
    exit
}

# Now that we have the sessionkey, let's run the refresh-veeam (or init-veeam if -init switch) cypher script against the n4j database
# The get-cypher-results.ps1 will execute and show the logged transaction results.
$scriptpath = -join ($PSScriptRoot,"\get-cypher-results.ps1")
$csp= -join ($PSScriptRoot,'\refresh-veeam.cypher')
if ($init -eq $true){
$csp= -join ($PSScriptRoot,'\init-veeam.cypher')}
$findstring='{"base-veeam-api-url":"'+$baseapiurl+'","veeam-restsvc-sessionid":"'+$veeamapisession+'","restorepointsmaxage":"'+$days+'"}'
Show-onscreen $("`nExecuting the following:`n. $scriptPath -Datasource $neo4jdatasource -cypherscript $csp -logging $neo4jdatasource -findrep $findstring -verbosity $verbosity`n ") 4
. $scriptPath -Datasource $neo4jdatasource -cypherscript $csp -logging $neo4jdatasource -findrep $findstring -verbosity $verbosity

Remove-Variable -name veeamapisession | Out-Null
Remove-Variable -name findstring | Out-Null

# All done!

