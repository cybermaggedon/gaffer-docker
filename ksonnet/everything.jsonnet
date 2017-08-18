
// Import KSonnet library.
local k = import "ksonnet.beta.2/k.libsonnet";

// Import definitions for Hadoop, Zookeeper, Accumulo, Wildfly.
local hadoop = import "hadoop.jsonnet";
local zookeeper = import "zookeeper.jsonnet";
local accumulo = import "accumulo.jsonnet";
local wildfly = import "wildfly.jsonnet";

// Configuration values for sizing the cluster.
local config = {
      hadoops: 1000,		// Number of Hadoop nodes.
      hadoop_replication: 6,	// Data replication level on HDFS.
      zookeepers: 23,		// Number of Zookeepers.
      accumulo_slaves: 1000,	// Number of Accumulo slaves.
      wildflys: 6		// Number of Wildfly replicas.
};

// Compile the resource list.
local resources =
    hadoop(config) +     // Hadoop.
    zookeeper(config) +		      // Zookeeper.
    accumulo(config) +   // Accumulo.
    wildfly(config);	      // Wildfly / REST API.

// Output the resources.
k.core.v1.list.new(resources)

