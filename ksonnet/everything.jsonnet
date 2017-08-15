
// Import KSonnet library.
local k = import "ksonnet.beta.2/k.libsonnet";

// Import definitions for Hadoop, Zookeeper, Accumulo, Wildfly.
local hadoop = import "hadoop.jsonnet";
local zookeeper = import "zookeeper.jsonnet";
local accumulo = import "accumulo.jsonnet";
local wildfly = import "wildfly.jsonnet";

// Configuration values for sizing the cluster.
local hadoops = 3;		// Number of Hadoop nodes.
local hadoop_replication = 3;	// Data replication level on HDFS.
local zookeepers = 3;		// Number of Zookeepers.
local accumulo_slaves = 3;	// Number of Accumulo slaves.
local wildflys = 2;		// Number of Wildfly replicas.

// Compile the resource list.
local resources =
    hadoop(hadoops, hadoop_replication) +     // Hadoop.
    zookeeper(zookeepers) +		      // Zookeeper.
    accumulo(accumulo_slaves, zookeepers) +   // Accumulo.
    wildfly(wildflys, zookeepers);	      // Wildfly / REST API.

// Output the resources.
k.core.v1.list.new(resources)

