MATCH (n:Veeambackup) detach delete n;
MATCH (n:Veeamjob) detach delete n;
MATCH (n:Veeamserver) detach delete n;
MATCH (n:Veeamprotectedvm) detach delete n;
// SECTION Create Indexes and Contraints
CREATE CONSTRAINT ON (vs:Veeamserver) ASSERT vs.UID IS UNIQUE;
CREATE INDEX ON :Veeamserver(name);
CREATE CONSTRAINT ON (vj:Veeamjob) ASSERT vj.UID IS UNIQUE;
CREATE INDEX ON :Veeamjob(name);
CREATE INDEX ON :Veeamprotectedvm(name);
CREATE INDEX ON :Veeamprotectedvm(id);
CREATE CONSTRAINT ON (vb:Veeambackup) ASSERT vb.name IS UNIQUE;
