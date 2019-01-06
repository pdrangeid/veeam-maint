# veeam-maint

Contains 2 powershell scripts.

disable-veeam-job-schedules.ps1
Must be run as a local admin (with rights to modify Veeam job schedules)

When run it will disable all scheduled Veeam Jobs.  Record the jobs in HKEY_LOCAL_MACHINE\SOFTWARE\Veeam\Temporarily Disabled Jobs\[JOB NAME]  so they can be re-enabled later with enable-veeam-job-schedules.ps1

 Note this script WILL NOT stop currently running jobs, but simply prevent future scheduled jobs from starting.  This is intended to
 be run BEFORE scheduled maintenance or a shutdown/reboot.  Be sure to run this script with plenty of time to allow for existing
 jobs to complete before maintenance begins. 

You should be able to verify it ran.  Any previously scheduled jobs with active 'Next Run' values should now be '<not scheduled>'
If jobs were previously <Disabled> they will not be modified.  You can also verify the registry, and you should find your newly disabled schedules in the above registry key.
  
  
  When you want to re-enable the schedules you can run the counter-script:
enable-veeam-job-schedules.ps1

Enable all scheduled Veeam Jobs previously diabled with disable-veeam-job-schedules.  Read the jobs in
HKEY_LOCAL_MACHINE\SOFTWARE\Veeam\Temporarily Disabled Jobs\[JOB NAME] enable the jobs, and remove the registry entries.

To avoid "forgetting" to re-enable jobs you could use the Windows Task scheduler to regularly run the 'enable-veeam-job-schedules.ps1' script in case a maintenance window was 'forgotten' afterwards.
