<# 
.SYNOPSIS 
 Enable all scheduled Veeam Jobs previously diables with disable-veeam-job-schedules.  Read the jobs in
 HKEY_LOCAL_MACHINE\SOFTWARE\Veeam\Temporarily Disabled Jobs\[JOB NAME] enable the jobs, and remove the registry entries

 Note this script WILL NOT stop currently running jobs, but simply prevent future scheduled jobs from starting.  This is

.DESCRIPTION 
 
  
.NOTES 
┌─────────────────────────────────────────────────────────────────────────────────────────────┐ 
│ enable-veeam-job-schedules.ps1                                                             │ 
├─────────────────────────────────────────────────────────────────────────────────────────────┤ 
│   DATE        : 2019.1.4  				               									  │ 
│   AUTHOR      : Paul Drangeid 			                   								  │ 
│   DESCRIPTION : Initial Beta Draft v0.1	               									  │ 
│                                                                                             │ 
│                                                                                             │ 
└─────────────────────────────────────────────────────────────────────────────────────────────┘ 
#> 
$global:scriptname = $($MyInvocation.MyCommand.Name)

Write-Host "`nLoading includes: $pwd\bg-sharedfunctions.ps1"
Try{. "$pwd\bg-sharedfunctions.ps1" | Out-Null}
Catch{
    Write-Warning "I wasn't able to load the sharedfunctions includes.  We are going to bail now, sorry 'bout that! "
    Write-Host "Try running them manually, and see what error message is causing this to puke: .\bg-sharedfunctions.ps1"
    BREAK
    }

 Prepare-EventLog
 #LogError "this is the actual error" "And here's some details to help provide context for the errors."

Add-PSSnapin -Name VeeamPSSnapIn

$Path = "HKLM:\Software\Veeam\Temporarily Disabled Jobs"
$Keys=Get-ChildItem $Path

ForEach ($Key in $Keys) {
    Write-Host "Try to re-enable "$($Key.PSchildname)
$Result = Enable-VBRJobSchedule -Job $($Key.PSchildname)
$EnabledJob=Get-VBRJob -Name $($Key.PSchildname) 
if  (![string]::IsNullorEmpty($EnabledJob.ScheduleOptions.NextRun)){
    Write-Host "Successfully Enabled Veeam Job '$($Key.PSchildname)'"
    $RegPath = -Join($Path,"\",$($Key.PSchildname))
    Write-Host $RegPath
    Remove-Item -path $RegPath -Recurse | Out-Null
}# Next run is nolonger blank
}# Key



