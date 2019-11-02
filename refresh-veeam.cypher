// SECTION Delete Veeam nodes
MATCH (vvm:Veeamprotectedvm) detach delete vvm;
MATCH (vs:Veeamserver) detach delete vs;
MATCH (vb:Veeambackup) detach delete vb;
MATCH (vf:Veeamprotectedfolder) detach delete vf;
MATCH (vj:Veeamjob) detach delete vj;


// SECTION Create (:Veeamserver) nodes
WITH "base-veeam-api-url/backupservers" as url
CALL apoc.load.jsonParams(url,{Accept:"application/json",`X-RestSvcSessionId`:"veeam-restsvc-sessionid"},null) yield value
unwind value.Refs as backupserver
MERGE (vs:Veeamserver {id:backupserver.UID}) set vs.name=backupserver.Name
return vs;


// SECTION Create (:Veeamjob)-[:JOB_MANAGEDBY_SERVER]->(:Veeamserver) nodes and relationships to Veeamservers
WITH "base-veeam-api-url/jobs" as url
CALL apoc.load.jsonParams(url,{Accept:"application/json",`X-RestSvcSessionId`:"veeam-restsvc-sessionid"},null) yield value
unwind value.Refs as job
MERGE (vj:Veeamjob {id:job.UID}) set vj.name=job.Name
WITH job,vj
UNWIND job.Links as joblink
WITH * where joblink.Type='BackupServerReference'
MATCH (vs:Veeamserver {name:joblink.Name})
MERGE (vj)-[:JOB_MANAGEDBY_SERVER]->(vs)
return vj,vs;

// SECTION Create (:Veeamprotectedvm) nodes via the VeeamAPI lookupSvc
WITH "base-veeam-api-url/lookupSvc" as url
CALL apoc.load.jsonParams(url,{Accept:"application/json",`X-RestSvcSessionId`:"veeam-restsvc-sessionid"},null) yield value
unwind value.Links as link
WITH link where link.Type='HierarchyItemList' and link.Href ends with '=Vm'
CALL apoc.load.jsonParams(link.Href,{Accept:"application/json",`X-RestSvcSessionId`:"veeam-restsvc-sessionid"},null) yield value
unwind value.HierarchyItems as vmobject
MERGE (vvm:Veeamprotectedvm {id:vmobject.ObjectRef}) SET vvm.name=vmobject.ObjectName
RETURN vvm;

MATCH (vb:Veeambackup) detach delete vb;


// SECTION discover the restorepoints for each VM object (only those within the last 1 days)
WITH 1*(86400000) as backupage
WITH timestamp()-backupage as oldestbackup
WITH apoc.date.format(oldestbackup,'ms',"yyyy-MM-dd'T'HH:mm:ss'Z'") as backupdate
MATCH (vvm:Veeamprotectedvm)
WITH vvm,backupdate,"base-veeam-api-url/query?type=VmRestorePoint&format=Entities&filter=HierarchyObjRef==%22"+vvm.id+"%22;CreationTime%3E"+backupdate as url
CALL apoc.load.jsonParams(url,{Accept:"application/json",`X-RestSvcSessionId`:"veeam-restsvc-sessionid"},null) yield value
UNWIND value.Entities as vmrestorepoints
UNWIND vmrestorepoints.VmRestorePoints as vmrestorepoint
UNWIND vmrestorepoint.VmRestorePoints as restorepoint
MERGE (vb:Veeambackup {name:restorepoint.Name}) SET vb.type=restorepoint.PointType,vb.algorithm=restorepoint.Algorithm,vb.creationtime=restorepoint.CreationTimeUTC
MERGE (vb)-[:BACKUP_OF]->(vvm)
RETURN vb,vvm;

// SECTION discover the restorepoints for each VM object (only those within the last 2 days that we didn't discover a 1 day backup)
WITH 2*(86400000) as backupage
WITH timestamp()-backupage as oldestbackup
WITH apoc.date.format(oldestbackup,'ms',"yyyy-MM-dd'T'HH:mm:ss'Z'") as backupdate
MATCH (vvm:Veeamprotectedvm) where not (vvm)--(:Veeambackup)
WITH vvm,backupdate,"base-veeam-api-url/query?type=VmRestorePoint&format=Entities&filter=HierarchyObjRef==%22"+vvm.id+"%22;CreationTime%3E"+backupdate as url
CALL apoc.load.jsonParams(url,{Accept:"application/json",`X-RestSvcSessionId`:"veeam-restsvc-sessionid"},null) yield value
UNWIND value.Entities as vmrestorepoints
UNWIND vmrestorepoints.VmRestorePoints as vmrestorepoint
UNWIND vmrestorepoint.VmRestorePoints as restorepoint
MERGE (vb:Veeambackup {name:restorepoint.Name}) SET vb.type=restorepoint.PointType,vb.algorithm=restorepoint.Algorithm,vb.creationtime=restorepoint.CreationTimeUTC
MERGE (vb)-[:BACKUP_OF]->(vvm)
RETURN vb,vvm;

// SECTION discover the restorepoints for each VM object (only those within the last 7 days that we didn't discover a 2 day backup)
WITH 7*(86400000) as backupage
WITH timestamp()-backupage as oldestbackup
WITH apoc.date.format(oldestbackup,'ms',"yyyy-MM-dd'T'HH:mm:ss'Z'") as backupdate
MATCH (vvm:Veeamprotectedvm) where not (vvm)--(:Veeambackup)
WITH vvm,backupdate,"base-veeam-api-url/query?type=VmRestorePoint&format=Entities&filter=HierarchyObjRef==%22"+vvm.id+"%22;CreationTime%3E"+backupdate as url
CALL apoc.load.jsonParams(url,{Accept:"application/json",`X-RestSvcSessionId`:"veeam-restsvc-sessionid"},null) yield value
UNWIND value.Entities as vmrestorepoints
UNWIND vmrestorepoints.VmRestorePoints as vmrestorepoint
UNWIND vmrestorepoint.VmRestorePoints as restorepoint
MERGE (vb:Veeambackup {name:restorepoint.Name}) SET vb.type=restorepoint.PointType,vb.algorithm=restorepoint.Algorithm,vb.creationtime=restorepoint.CreationTimeUTC
MERGE (vb)-[:BACKUP_OF]->(vvm)
RETURN vb,vvm;

// SECTION discover the restorepoints for each VM object (only those within the last 14 days that we didn't discover a 7 day backup)
WITH 14*(86400000) as backupage
WITH timestamp()-backupage as oldestbackup
WITH apoc.date.format(oldestbackup,'ms',"yyyy-MM-dd'T'HH:mm:ss'Z'") as backupdate
MATCH (vvm:Veeamprotectedvm) where not (vvm)--(:Veeambackup)
WITH vvm,backupdate,"base-veeam-api-url/query?type=VmRestorePoint&format=Entities&filter=HierarchyObjRef==%22"+vvm.id+"%22;CreationTime%3E"+backupdate as url
CALL apoc.load.jsonParams(url,{Accept:"application/json",`X-RestSvcSessionId`:"veeam-restsvc-sessionid"},null) yield value
UNWIND value.Entities as vmrestorepoints
UNWIND vmrestorepoints.VmRestorePoints as vmrestorepoint
UNWIND vmrestorepoint.VmRestorePoints as restorepoint
MERGE (vb:Veeambackup {name:restorepoint.Name}) SET vb.type=restorepoint.PointType,vb.algorithm=restorepoint.Algorithm,vb.creationtime=restorepoint.CreationTimeUTC
MERGE (vb)-[:BACKUP_OF]->(vvm)
RETURN vb,vvm;


// SECTION discover the restorepoints for each VM object (only those that we didn't discover a 14 day backup)
MATCH (vvm:Veeamprotectedvm) where not (vvm)--(:Veeambackup)
WITH vvm,"base-veeam-api-url/query?type=VmRestorePoint&format=Entities&filter=HierarchyObjRef==%22"+vvm.id+"%22" as url
CALL apoc.load.jsonParams(url,{Accept:"application/json",`X-RestSvcSessionId`:"veeam-restsvc-sessionid"},null) yield value
UNWIND value.Entities as vmrestorepoints
UNWIND vmrestorepoints.VmRestorePoints as vmrestorepoint
UNWIND vmrestorepoint.VmRestorePoints as restorepoint
MERGE (vb:Veeambackup {name:restorepoint.Name}) SET vb.type=restorepoint.PointType,vb.algorithm=restorepoint.Algorithm,vb.creationtime=restorepoint.CreationTimeUTC
MERGE (vb)-[:BACKUP_OF]->(vvm)
RETURN vb,vvm;


// SECTION Create (:Veeamjob)-[:JOB_MANAGEDBY_SERVER]->(:Veeamserver) nodes and relationships to Veeamservers
WITH "base-veeam-api-url/jobs" as url
CALL apoc.load.jsonParams(url,{Accept:"application/json",`X-RestSvcSessionId`:"veeam-restsvc-sessionid"},null) yield value
unwind value.Refs as job
MERGE (vj:Veeamjob {id:job.UID}) set vj.name=job.Name
WITH job,vj
UNWIND job.Links as joblink
WITH * where joblink.Type='BackupServerReference'
MATCH (vs:Veeamserver {name:joblink.Name})
MERGE (vj)-[:JOB_MANAGEDBY_SERVER]->(vs)
return vj,vs;

MATCH (vj:Veeamjob)
WITH vj,split(vj.id,':')[3] as jobid
WITH vj,"base-veeam-api-url/jobs/"+jobid+"/includes" as url
CALL apoc.load.jsonParams(url,{Accept:"application/json",`X-RestSvcSessionId`:"veeam-restsvc-sessionid"},null) yield value
UNWIND value.ObjectInJobs as jobobject
FOREACH (ignoreMe in CASE WHEN jobobject.HierarchyObjRef contains ':Vm:' then [1] ELSE [] END | MERGE (vvm:Veeamprotectedvm {id:jobobject.HierarchyObjRef}) MERGE (vvm)-[r:INCLUDED_IN_VEEAM_JOB]->(vj) )
FOREACH (ignoreMe in CASE WHEN jobobject.HierarchyObjRef contains ':Folder:' then [1] ELSE [] END | MERGE (vf:Veeamprotectedfolder {id:jobobject.HierarchyObjRef}) MERGE (vf)-[r:INCLUDED_IN_VEEAM_JOB]->(vj) SET vf.name=jobobject.Name,vf.href=jobobject.Href)
RETURN *;


WITH 14*(86400000) as backupage
WITH timestamp()-backupage as oldestbackup
WITH apoc.date.format(oldestbackup,'ms',"yyyy-MM-dd'T'HH:mm:ss'Z'") as backupdate
WITH backupdate,"base-veeam-api-url/query?type=BackupJobSession&format=Entities&filter=CreationTime%3E"+backupdate as url
CALL apoc.load.jsonParams(url,{Accept:"application/json",`X-RestSvcSessionId`:"veeam-restsvc-sessionid"},null) yield value
unwind value.Entities.BackupJobSessions.BackupJobSessions as session
MERGE (vj:Veeamjob {id:session.JobUid}) set vj.name=session.JobName
WITH session,vj
UNWIND session.Links as sessionlink
OPTIONAL MATCH (vs:Veeamserver {name:sessionlink.Name}) where sessionlink.Type='BackupServerReference'
FOREACH (ignoreMe in CASE WHEN exists(vs.name) and exists(vj.name) then [1] ELSE [] END |MERGE (vj)-[:JOB_MANAGEDBY_SERVER]->(vs))
WITH vj,vs,sessionlink.Href as url where sessionlink.Type='BackupTaskSessionReferenceList'
CALL apoc.load.jsonParams(url,{Accept:"application/json",`X-RestSvcSessionId`:"NGZiZDY0MGUtMGFkNi00OGNlLWFkZjAtNDc3MzRjMTc1NTQx"},null) yield value
UNWIND value.refs as sessionvm
WITH * where sessionvm.Type='BackupTaskSessionReference'
MATCH (vvm:Veeamprotectedvm {name:split(sessionvm.Name,'@')[0]})
MERGE (vvm)-[r:INCLUDED_IN_VEEAM_JOB]->(vj)
FOREACH (ignoreMe in CASE WHEN not exists(r.lastjobsession) or split(sessionvm.Name,'@')[1] > r.lastjobsession then [1] ELSE [] END | SET r.lastjobsession=split(sessionvm.Name,'@')[1])
return vj,vs,vvm;