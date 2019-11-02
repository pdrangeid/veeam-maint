
//SECTION Identify the last known restorepoint for each Veeam protected VM

//Remove the lastgoodbackup property from all nodes
MATCH (vpvm:Veeamprotectedvm) REMOVE vpvm.lastgoodbackup;

//set the last good restorepoint value for each Veeamprotectedvm object
MATCH (vvm:Veeambackup)--(vpvm:Veeamprotectedvm)
WITH vvm,vpvm
ORDER BY vvm.creationtime DESC
WITH vpvm,collect(vvm.creationtime)[0] as maxtime
SET vpvm.lastgoodbackup=maxtime;

MATCH (vpvm:Veeamprotectedvm)-[r:LAST_BACKUP_SUCCESS]->(:Lastgoodbackup) detach delete r;

// MATCH backups that have success within the last 6 hours
MATCH (lgb:Lastgoodbackup {name:'6 hours'})
MATCH (vpvm:Veeamprotectedvm) where datetime(vpvm.lastgoodbackup).epochmillis >(timestamp()-lgb.delta)
MERGE (vpvm)-[:LAST_BACKUP_SUCCESS]->(lgb)
RETURN vpvm,lgb;

// MATCH backups that have success within the last 12 hours
MATCH (lgb:Lastgoodbackup {name:'12 hours'})
MATCH (vpvm:Veeamprotectedvm) where not (vpvm)--(:Lastgoodbackup) and datetime(vpvm.lastgoodbackup).epochmillis >(timestamp()-lgb.delta)
MERGE (vpvm)-[:LAST_BACKUP_SUCCESS]->(lgb)
RETURN vpvm,lgb;

// MATCH backups that have success within the last 24 hours
MATCH (lgb:Lastgoodbackup {name:'24 hours'})
MATCH (vpvm:Veeamprotectedvm) where not (vpvm)--(:Lastgoodbackup) and datetime(vpvm.lastgoodbackup).epochmillis >(timestamp()-lgb.delta)
MERGE (vpvm)-[:LAST_BACKUP_SUCCESS]->(lgb)
RETURN vpvm,lgb;

// MATCH backups that have success within the last 2 days
MATCH (lgb:Lastgoodbackup {name:'2 days'})
MATCH (vpvm:Veeamprotectedvm) where not (vpvm)--(:Lastgoodbackup) and datetime(vpvm.lastgoodbackup).epochmillis >(timestamp()-lgb.delta)
MERGE (vpvm)-[:LAST_BACKUP_SUCCESS]->(lgb)
RETURN vpvm,lgb;

// MATCH backups that have success within the last 7 days
MATCH (lgb:Lastgoodbackup {name:'7 days'})
MATCH (vpvm:Veeamprotectedvm) where not (vpvm)--(:Lastgoodbackup) and datetime(vpvm.lastgoodbackup).epochmillis >(timestamp()-lgb.delta)
MERGE (vpvm)-[:LAST_BACKUP_SUCCESS]->(lgb)
RETURN vpvm,lgb;

// MATCH backups that have success but it is over a week
MATCH (lgb:Lastgoodbackup {name:'over a week'})
MATCH (vpvm:Veeamprotectedvm) where not (vpvm)--(:Lastgoodbackup) and exists(vpvm.lastgoodbackup) and datetime(vpvm.lastgoodbackup).epochmillis is not null
MERGE (vpvm)-[:LAST_BACKUP_SUCCESS]->(lgb)
RETURN vpvm,lgb;

// MATCH backups that have never been backed up
MATCH (lgb:Lastgoodbackup {name:'never'})
MATCH (vpvm:Veeamprotectedvm) where not (vpvm)--(:Lastgoodbackup)
MERGE (vpvm)-[:LAST_BACKUP_SUCCESS]->(lgb)
RETURN vpvm,lgb;