
//
// Definition for Gaffer HTTP API / Wildfly on Kubernetes.  This creates a set
// of Wildfly replicas.
//

// Import KSonnet library.
local k = import "ksonnet.beta.2/k.libsonnet";

// Short-cuts to various objects in the KSonnet library.
local depl = k.extensions.v1beta1.deployment;
local container = depl.mixin.spec.template.spec.containersType;
local containerPort = container.portsType;
local resources = container.resourcesType;
local env = container.envType;
local svc = k.core.v1.service;
local svcPort = svc.mixin.spec.portsType;
local svcLabels = svc.mixin.metadata.labels;

// Ports used by deployments
local ports() = [
    containerPort.newNamed("rest", 8080)
];

// Constructs a list of Zookeeper hostnames, comma separated.
local zookeeperList(count) =
    std.join(",", std.makeArray(count, function(x) "zk%d.zk" % (x + 1)));

// Environment variables
local envs(zookeepers) = [

    // List of Zookeepers.
    env.new("ZOOKEEPERS", zookeeperList(zookeepers))
    
];

// Container definition.
local containers(zookeepers) = [
    container.new("wildfly", "gcr.io/trust-networks/gaffer:0.7.4b") +
        container.ports(ports()) +
	container.env(envs(zookeepers)) +
	container.mixin.resources.limits({
	    memory: "1G", cpu: "1.5"
	}) +
	container.mixin.resources.requests({
	    memory: "1G", cpu: "1.0"
	})
];

// Deployment definition.  id is the node ID.
local deployment(wildflys, zookeepers) = 
    depl.new("wildfly", wildflys,
	     containers(zookeepers),
	     {app: "wildfly", component: "gaffer"});

// Ports declared on the service.
local servicePorts = [
    svcPort.newNamed("rest", 8080, 8080) + svcPort.protocol("TCP")
];

// Function which returns resource definitions - deployments and services.
local resources(c) = [

    // One deployment, with a set of replicas.
    deployment(c.wildflys, c.zookeepers)

] + [

    // One service load-balanced across the replicas
    svc.new("gaffer", {app: "wildfly"}, servicePorts) +
	svcLabels({app: "gaffer", component: "gaffer"})
];

// Return the function which creates resources.
resources

