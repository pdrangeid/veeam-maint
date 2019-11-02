param (
    [string]$baseapiurl,
    [string]$veeamcred,
    [string]$neo4jdatasource,
    [switch]$session,
    [integer]$verbosity
    )

Try{. "$PSScriptRoot\bg-sharedfunctions.ps1" | Out-Null}
#Try{. "C:\Program Files\Blue Net Inc\Graph-Commit\bg-sharedfunctions.ps1" | Out-Null}
Catch{
    Write-Warning "I wasn't able to load the sharedfunctions includes (which should live in the same directory as $global:srccmdline). `nWe are going to bail now, sorry 'bout that!"
    Write-Host "Try running them manually, and see what error message is causing this to puke: $PSScriptRoot\bg-sharedfunctions.ps1"
    Unregister-PSVars
    BREAK
    }

    # Retrieve the credentials from the current users' registry.  
    # If you haven't yet stored these credentials use the following powershell command:
    # ./set-regcredentials.ps1 -credname edc-veeam -defaultuser domain\myveeamuser -credpath neo4j-wrapper\Credentials
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

if ($session -eq $true){
    write-host "Session id: $veeamapisession"
    exit
}

$scriptpath = -join ($PSScriptRoot,"\get-cypher-results.ps1")
$csp= -join ($PSScriptRoot,'\refresh-veeam.cypher')
$findstring=' {"base-veeam-api-url":"'+$baseapiurl+'","veeam-restsvc-sessionid":"'+$veeamapisession+'"}'
$result = . $scriptPath -Datasource $neo4jdatasource -cypherscript $csp -logging $neo4jdatasource -findrep $findstring -verbosity $verbosity

Remove-Variable -name veeamapisession | Out-Null

