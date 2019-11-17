// SECTION Create Indexes and Contraints
CREATE CONSTRAINT ON (vs:Veeamserver) ASSERT vs.UID IS UNIQUE;
CREATE INDEX ON :Veeamserver(name);
CREATE CONSTRAINT ON (vj:Veeamjob) ASSERT vj.UID IS UNIQUE;
CREATE INDEX ON :Veeamjob(name);
CREATE INDEX ON :Veeamprotectedvm(name);
CREATE INDEX ON :Veeamprotectedvm(id);
CREATE CONSTRAINT ON (vb:Veeambackup) ASSERT vb.name IS UNIQUE;

// SECTION Create (:Veeamserver) nodes
WITH "base-veeam-api-url/backupservers?format=Entity" as url
CALL apoc.load.jsonParams(url,{Accept:"application/json",`X-RestSvcSessionId`:"veeam-restsvc-sessionid"},null) yield value
unwind value.BackupServers as backupserver
MERGE (vs:Veeamserver {id:backupserver.UID}) SET vs.name=backupserver.Name, vs.description=backupserver.Description,vs.version=vs.Version
WITH backupserver,vs
UNWIND backupserver.Links as link
WITH vs,link where link.Type='BackupServerReference'
SET vs.apiurl=split(link.Href,'/backupServers/')[0]
return vs;

// SECTION Create (:Veeamjob)-[:JOB_MANAGEDBY_SERVER]->(:Veeamserver) nodes and relationships to Veeamservers
WITH "base-veeam-api-url/jobs?format=Entity" as url
CALL apoc.load.jsonParams(url,{Accept:"application/json",`X-RestSvcSessionId`:"veeam-restsvc-sessionid"},null) yield value
unwind value.Jobs as job
MERGE (vj:Veeamjob {id:job.UID}) set vj.name=job.Name set vj.type=job.JobType,vj.scheduled=job.ScheduleConfigured
WITH job,vj
UNWIND job.Links as joblink
WITH * where joblink.Type='BackupServerReference'
MATCH (vs:Veeamserver {name:joblink.Name})
MERGE (vj)-[:JOB_MANAGEDBY_SERVER]->(vs)
return vj,vs;

// SECTION Create (:Veeamprotectedvm) nodes via the VeeamAPI lookupSvc
// TO avoid duplicates (multiple veeam servers and multiple vcenters, we use a combination of the vm-xxxxx plus the name as the unique id for a VM)
WITH "base-veeam-api-url/lookupSvc" as url
CALL apoc.load.jsonParams(url,{Accept:"application/json",`X-RestSvcSessionId`:"veeam-restsvc-sessionid"},null) yield value
unwind value.Links as link
WITH link where link.Type='HierarchyItemList' and link.Href ends with '=Vm'
CALL apoc.load.jsonParams(link.Href,{Accept:"application/json",`X-RestSvcSessionId`:"veeam-restsvc-sessionid"},null) yield value
WITH *,"[^A-Za-z\\d-. _]{1,63}" as regex1
unwind value.HierarchyItems as vmobject
WITH *,trim(apoc.text.regreplace(vmobject.ObjectName,regex1,'')) as cleanedname,split(vmobject.ObjectRef,'.')[1] as vmid
MERGE (vvm:Veeamprotectedvm {id:vmid,name:cleanedname}) SET vvm.creation='VeeamAPI lookupSvc function'
FOREACH (ignoreMe in CASE WHEN not vmobject.ObjectRef in coalesce(vvm.vobjid,[]) then [1] ELSE [] END | SET vvm.vobjid=coalesce(vvm.vobjid,[]) + vmobject.ObjectRef)
RETURN vvm;

// SECTION discover the restorepoints (since the last time this script was run) for each VM object 
MATCH (vsr:Veeamserver) where toLower(vsr.apiurl)=toLower('base-veeam-api-url') SET vsr.pendingupdate=timestamp()
WITH vsr,restorepointsmaxage*(86400000) as backupage,timestamp() AS howsoonisnow
WITH howsoonisnow,coalesce(vsr.lastupdate,timestamp()-backupage) as oldestbackup
WITH howsoonisnow,apoc.date.format(oldestbackup,'ms',"yyyy-MM-dd'T'HH:mm:ss'Z'") as backupdate
MATCH (vvm:Veeamprotectedvm) where not (vvm)--(:Veeambackup)--(:Veeamjob {type:'Backup'})
UNWIND vvm.vobjid as vobjid
WITH howsoonisnow,vvm,backupdate,"base-veeam-api-url/query?type=VmRestorePoint&format=Entities&filter=HierarchyObjRef==%22"+vobjid+"%22;CreationTime%3E"+backupdate as url
CALL apoc.load.jsonParams(url,{Accept:"application/json",`X-RestSvcSessionId`:"veeam-restsvc-sessionid"},null) yield value
UNWIND value.Entities as vmrestorepoints
UNWIND vmrestorepoints.VmRestorePoints as vmrestorepoint
UNWIND vmrestorepoint.VmRestorePoints as restorepoint
MERGE (vb:Veeambackup {name:restorepoint.Name}) SET vb.type=restorepoint.PointType,vb.algorithm=restorepoint.Algorithm,vb.creationtime=restorepoint.CreationTimeUTC
MERGE (vb)-[:BACKUP_OF]->(vvm)
WITH howsoonisnow,vb,restorepoint where not (vb)-[:PART_OF_JOB]->(:Veeamjob)
UNWIND restorepoint.Links as link
WITH howsoonisnow,vb,link.Href as url where link.Type='RestorePointReference'
CALL apoc.load.jsonParams(url,{Accept:"application/json",`X-RestSvcSessionId`:"veeam-restsvc-sessionid"},null) yield value
UNWIND value.Links as link
WITH howsoonisnow,vb,link.Href as url where link.Type='BackupReference'
CALL apoc.load.jsonParams(url,{Accept:"application/json",`X-RestSvcSessionId`:"veeam-restsvc-sessionid"},null) yield value
UNWIND value.Links as link
OPTIONAL MATCH (vbs:Veeamserver {name:link.Name}) where vbs.id ends with last(split(link.Href,'/'))
FOREACH (ignoreMe in CASE WHEN exists(vbs.name) and vbs.name <> '' then [1] ELSE [] END | MERGE (vb)-[:BACKUP_PERFORMED_ON]->(vbs))
WITH vb,link where link.Type='Backup'
MATCH (vj:Veeamjob {name:link.Name}) WHERE (vj)--(:Veeamserver)--(vb)
MERGE (vb)-[:PART_OF_JOB]->(vj)
return link,vj.name,vb.name;

// move the .pendingupdate property to .lastupdate
MATCH (vsr:Veeamserver) where toLower(vsr.apiurl)=toLower('base-veeam-api-url')
FOREACH (ignoreMe in CASE WHEN exists(vsr.pendingupdate) then [1] ELSE [] END | SET vsr.lastupdate=vsr.pendingupdate REMOVE vsr.pendingupdate);

// Relate (vm:Virtualmachine) to (:Veeamprotectedvm) via name and vmid
MATCH (vm:Virtualmachine) where not (vm)--(:Veeamprotectedvm)
MATCH (vvm:Veeamprotectedvm) where vvm.id=vm.vmid and toLower(trim(vvm.name))=toLower(trim(vm.name))
MERGE (vvm)<-[:BACKUP_VIA]-(vm);

// Relate (vm:Virtualmachine) to (:Veeamprotectedvm) via name and vmid (with name cleaning)
WITH *,"[^A-Za-z\\d-. _]{1,63}" as regex1
MATCH (vvm:Veeamprotectedvm) where not (vvm)--(:Virtualmachine)
MATCH (vm:Virtualmachine) where not (vm)--(:Veeamprotectedvm)
WITH * where vvm.id=vm.vmid
WITH *,trim(apoc.text.regreplace(vvm.name,regex1,'')) as cleanedvvmname
WITH *,trim(apoc.text.regreplace(vm.name,regex1,'')) as cleanedvmname
WITH * where cleanedvvmname=cleanedvmname
MERGE (vvm)<-[:BACKUP_VIA]-(vm);