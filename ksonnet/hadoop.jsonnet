
//
// Definition for Hadoop HDFS resources on Kubernetes.  This creates a Hadoop
// cluster consisting of a master node (running namenode and datanode) and
// slave datanodes.
//

// Import KSonnet library.
local k = import "ksonnet.beta.2/k.libsonnet";

// Short-cuts to various objects in the KSonnet library.
local depl = k.extensions.v1beta1.deployment;
local container = depl.mixin.spec.template.spec.containersType;
local containerPort = container.portsType;
local mount = container.volumeMountsType;
local volume = depl.mixin.spec.template.spec.volumesType;
local resources = container.resourcesType;
local env = container.envType;
local gceDisk = volume.mixin.gcePersistentDisk;
local svc = k.core.v1.service;
local svcPort = svc.mixin.spec.portsType;
local svcLabels = svc.mixin.metadata.labels;

// Ports used by deployments
local ports() = [
    containerPort.newNamed("namenode-http", 50070),
    containerPort.newNamed("datanode", 50075),
    containerPort.newNamed("namenode-rpc", 9000)
];

// Volume mount points
local volumeMounts(id) = [
    mount.new("data", "/data")
];

// Environment variables
local envs(id, replication) = [

    // Set Hadoop data replication to 3.
    env.new("DFS_REPLICATION", std.toString(replication))

] + if id == 0 then
[

    // The first node runs namenode and secondarynamenode
    env.new("DAEMONS", "namenode,secondarynamenode,datanode"),

] else [

    // Everything else just runs a datanode, and needs to know the
    // namenode's URI.
    env.new("DAEMONS", "datanode"),
    env.new("NAMENODE_URI", "hdfs://hadoop0000:9000")
    
];

// Container definition.
local containers(id, replication) = [
    container.new("hadoop", "cybermaggedon/hadoop:2.8.0") +
        container.ports(ports()) +
        container.volumeMounts(volumeMounts(id)) +
	container.env(envs(id, replication)) +
	container.mixin.resources.limits({
	    memory: "1024M", cpu: "1.0"
	}) +
	container.mixin.resources.requests({
	    memory: "1024M", cpu: "0.5"
	})
];

// Volumes - this invokes a GCE permanent disk.
local volumes(id) = [
    volume.name("data") + gceDisk.fsType("ext4") +
	gceDisk.pdName("hadoop-%04d" % id)
];

// Deployment definition.  id is the node ID.
local deployment(id, replication) = 
    depl.new("hadoop%04d" % id, 1,
	     containers(id, replication),
	     {app: "hadoop%04d" % id, component: "gaffer"}) +
    depl.mixin.spec.template.spec.volumes(volumes(id));

// Ports declared on the service.
local servicePorts = [
    svcPort.newNamed("rpc", 9000, 9000) + svcPort.protocol("TCP")
];

// Function which returns resource definitions - deployments and services.
local resources(config) = [
    
    // One deployment per Hadoop node.
    deployment(id, config.hadoop_replication) for id in std.range(0, config.hadoops-1)
				
] + [

    // One service for the first node (name node).
    svc.new("hadoop0000", {app: "hadoop0000"}, servicePorts) +
	svcLabels({app: "hadoop0000", component: "gaffer"})
    
];

// Return the function which creates resources.
resources

