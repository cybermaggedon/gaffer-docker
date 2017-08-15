
//
// Definition for Zookeeper resources on Kubernetes.  This creates a ZK
// cluster consisting of several Zookeepers.
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
    containerPort.newNamed("internal1", 2888),
    containerPort.newNamed("internal2", 3888),
    containerPort.newNamed("service", 2181)
];

// Volume mount points
local volumeMounts(id) = [
    mount.new("data", "/data")
];

// Environment variables
local envs(id, zks) = [
    env.new("ZOOKEEPER_MYID", "%d" % (id + 1)),
    env.new("ZOOKEEPERS", zks)
];

// Container definition.
local containers(id, zks) = [
    container.new("zookeeper", "cybermaggedon/zookeeper:3.4.10") +
        container.ports(ports()) +
        container.volumeMounts(volumeMounts(id)) +
	container.env(envs(id, zks)) +
	container.mixin.resources.limits({
	    memory: "256M", cpu: "0.5"
	}) +
	container.mixin.resources.requests({
	    memory: "256M", cpu: "0.15"
	})
];

// Volumes - this invokes a GCE permanent disk.
local volumes(id) = [
    volume.name("data") + gceDisk.fsType("ext4") +
	gceDisk.pdName("zookeeper-%d" % (id + 1))
];

// Deployment definition.  id is the node ID, zks is number Zookeepers.
local deployment(id, zks) = 
    depl.new("zk%d" % (id + 1), 1,
	     containers(id, zks),
	     {app: "zk%d" % (id + 1), component: "gaffer"}) +
    depl.mixin.spec.template.spec.volumes(volumes(id));

// Function, returns a Zookeeper list, comma separated list of ZK IDs.
local zookeeperList(count) =
    std.join(",", std.makeArray(count, function(x) "zk%d" % (x + 1)));

// Ports declared on the Hadoop service.
local servicePorts = [
    svcPort.newNamed("internal1", 2888, 2888) + svcPort.protocol("TCP"),
    svcPort.newNamed("internal2", 3888, 3888) + svcPort.protocol("TCP"),
    svcPort.newNamed("service", 2181, 2181) + svcPort.protocol("TCP")
];

// Function which returns resource definitions - deployments and services.
local resources(count) = [

    // One deployment for each Zookeeper
    deployment(id, zookeeperList(count))
    for id in std.range(0, count-1)

] + [

    // One service for each Zookeeper to allow it to be discovered by
    // Zookeeper name.
    svc.new("zk%d" % (id + 1) , {app: "zk%d" % (id + 1)}, servicePorts)
    for id in std.range(0, count-1)
    
];

// Return the function which creates resources.
resources

