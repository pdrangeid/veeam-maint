<# 
.SYNOPSIS 
 Disable all scheduled Veeam Jobs.  Record the jobs in HKEY_LOCAL_MACHINE\SOFTWARE\Veeam\Temporarily Disabled Jobs\[JOB NAME]
 so they can be re-enabled later with enable-veeam-job-schedules.ps1

 Note this script WILL NOT stop currently running jobs, but simply prevent future scheduled jobs from starting.  This is intended to
 be run BEFORE scheduled maintenance or a shutdown/reboot.  Be sure to run this script with plenty of time to allow for existing
 jobs to complete before maintenance begins. 
 
.DESCRIPTION 
 
  
.NOTES 
┌─────────────────────────────────────────────────────────────────────────────────────────────┐ 
│ disable-veeam-job-schedules.ps1                                                             │ 
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

ForEach($Job in Get-VBRJob) {
if  (![string]::IsNullorEmpty($Job.ScheduleOptions.NextRun)){

$Path = -Join("HKLM:\Software\Veeam\Temporarily Disabled Jobs\",$($Job.Name))

if (Test-Path $Path) {
$Key = Get-Item -LiteralPath $Path -ErrorAction SilentlyContinue| Out-Null
    $Datedisabled=$((Get-ItemProperty -Path $Path -Name "ScheduleDisabled").ScheduleDisabled)
    Write-Host $($Job.Name) " was already disabled on $Datedisabled"
}# Test-Path
else{
AddRegPath $Path | Out-Null
New-ItemProperty -Path $Path -Name "ScheduleDisabled" -Value $(Get-Date) -Force | Out-Null
}
$Result = Get-VBRJob -Name $($Job.Name) | Disable-VBRJobSchedule
#Write-Host $Result
Write-Host "Disabled Job: "$Job.Name

} # NextRun has a value

} # ForEach Job

