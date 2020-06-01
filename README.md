
# Gaffer Docker

What you have here, is Docker containers for Gaffer.  Can be deployed small for
development/trial, or larger scale for operational use.

Containerising allows a quick way to find out what Gaffer is
like and develop against the interfaces.  To run Gaffer, you need four
components:

- Wildfly, hosting the Gaffer REST API and UI.
- Accumulo, hosting the Gaffer extensions.
- Zookeeper, which is used by Accumulo.
- Hadoop, which is used by Accumulo.

I have these components available as the four containers:
- cybermaggedon/wildfly-gaffer
- cybermaggedon/accumulo-gaffer
- cybermaggedon/zookeeper
- cybermaggedon/hadoop

The code here:
- Compiles Gaffer from source in a build container, and extracts a set of
  things to be loaded into the deployable containers.
- Downloads Wildfly, and creates a container integrating Wildfly and Gaffer.
- Creates a container integrating Accumulo (cybermaggedon/accumulo) and
  Gaffer.

For Hadoop and Zookeeper, I have containers ready to use.

To run:

```

  # Run Hadoop
  docker run -d --name hadoop cybermaggedon/hadoop:2.10.0

  # Run Zookeeper
  docker run -d --name zookeeper cybermaggedon/zookeeper:3.6.1

  # Run Accumulo
  docker run -d --name accumulo --link zookeeper:zookeeper \
        --link hadoop:hadoop cybermaggedon/accumulo-gaffer:1.12.0

  # Run Wildfly, exposing port 8080.
  docker run -d --name wildfly --link zookeeper:zookeeper \
    --link hadoop:hadoop --link accumulo:accumulo \
    -p 8080:8080 cybermaggedon/wildfly-gaffer:1.12.0

```

You can then access the Gaffer API at port 8080, e.g. try accessing URL
http://HOSTNAME:8080/rest.  The UI is available at http://HOSTNAME:8080/ui.

When the container dies, the data is lost.  If you want data to persist,
put volumes on /data for Hadoop and Zookeeper, and /accumulo for Accumulo.
Wildfly needs no persistent state.

```
  # Run Hadoop
  docker run -d --name hadoop -v /data/hadoop:/data cybermaggedon/hadoop:2.10.0

  # Run Zookeeper
  docker run -d --name zookeeper -v /data/zookeeper:/data \
        cybermaggedon/zookeeper:3.6.1

  # Run Accumulo
  docker run -d --name accumulo \
        --link zookeeper:zookeeper \
        --link hadoop:hadoop cybermaggedon/accumulo-gaffer:1.12.0

  # Run Wildfly, exposing port 8080.
  docker run -d --name wildfly --link zookeeper:zookeeper \
    --link hadoop:hadoop --link accumulo:accumulo \
    -p 8080:8080 cybermaggedon/wildfly-gaffer:1.12.0

```

The default schema deployed is usable.  If you want to set your own schema
then you need to change /usr/local/wildfly/schema/* by e.g. mounting
replacement volumes.

Accumulo makes considerable use of Zookeeper, to the point that, at high
input load, Zookeeper seems to continually grow until it exhausts the
container memory footprint.  Workaround: run containers in a container engine
like Kubernetes, so that everything restarts.

If volumes don't mount because of selinux, this command may be your friend:

  ```chcon -Rt svirt_sandbox_file_t /path/of/volume```

Take a look at run_gaffer, a script which starts the four containers.
Also, <kubernetes/README.kubernetes.md> if you want to run Gaffer in Kubernetes.

To set up a cluster, you need to take control of address allocation.

```
  ############################################################################
  # Create network
  ############################################################################
  docker network create --driver=bridge --subnet=10.10.0.0/16 my_network

  ############################################################################
  # HDFS
  ############################################################################

  # Namenode
  docker run -d --ip=10.10.6.3 --net my_network \
      -e DAEMONS=namenode,datanode,secondarynamenode \
      --name=hadoop01 \
      -p 50070:50070 -p 50075:50075 -p 50090:50090 -p 9000:9000 \
      cybermaggedon/hadoop:2.10.0

  # Datanodes
  docker run -d --ip=10.10.6.4 --net my_network --link hadoop01:hadoop01 \
      -e DAEMONS=datanode -e NAMENODE_URI=hdfs://hadoop01:9000 \
      --name=hadoop02 \
      cybermaggedon/hadoop:2.10.0

  docker run -d --ip=10.10.6.5 --net my_network --link hadoop01:hadoop01 \
      -e DAEMONS=datanode -e NAMENODE_URI=hdfs://hadoop01:9000 \
      --name=hadoop03 \
      cybermaggedon/hadoop:2.10.0

  ############################################################################
  # Zookeeper cluster, 3 nodes.
  ############################################################################
  docker run -d --ip=10.10.5.10 --net my_network \
      -e ZOOKEEPERS=10.10.5.10,10.10.5.11,10.10.5.12 \
      -e ZOOKEEPER_MYID=1 \
      --name zk1 -p 2181:2181 cybermaggedon/zookeeper:3.6.1
      
  docker run -d --ip=10.10.5.11 --net my_network \
      -e ZOOKEEPERS=10.10.5.10,10.10.5.11,10.10.5.12 \
      -e ZOOKEEPER_MYID=2 --name zk2 --link zk1:zk1 \
      cybermaggedon/zookeeper:3.6.1
      
  docker run -d --ip=10.10.5.12 --net my_network \
      -e ZOOKEEPERS=10.10.5.10,10.10.5.11,10.10.5.12 \
      -e ZOOKEEPER_MYID=3 --name zk3 --link zk1:zk1 \
      cybermaggedon/zookeeper:3.6.1

  ############################################################################
  # Accumulo, 3 nodes
  ############################################################################
  docker run -d --ip=10.10.10.10 --net my_network \
      -p 50095:50095 -p 9995:9995 \
      -e ZOOKEEPERS=10.10.5.10,10.10.5.11,10.10.5.12 \
      -e HDFS_VOLUMES=hdfs://hadoop01:9000/accumulo \
      -e NAMENODE_URI= \
      -e MY_HOSTNAME=10.10.10.10 \
      -e GC_HOSTS=10.10.10.10 \
      -e MASTER_HOSTS=10.10.10.10 \
      -e SLAVE_HOSTS=10.10.10.10,10.10.10.11,10.10.10.12 \
      -e MONITOR_HOSTS=10.10.10.10 \
      -e TRACER_HOSTS=10.10.10.10 \
      --link hadoop01:hadoop01 \
      --name acc01 cybermaggedon/accumulo-gaffer:1.12.0

  docker run -d --ip=10.10.10.11 --net my_network \
      -e ZOOKEEPERS=10.10.5.10,10.10.5.11,10.10.5.12 \
      -e HDFS_VOLUMES=hdfs://hadoop01:9000/accumulo \
      -e NAMENODE_URI= \
      -e MY_HOSTNAME=10.10.10.11 \
      -e GC_HOSTS=10.10.10.10 \
      -e MASTER_HOSTS=10.10.10.10 \
      -e SLAVE_HOSTS=10.10.10.10,10.10.10.11,10.10.10.12 \
      -e MONITOR_HOSTS=10.10.10.10 \
      -e TRACER_HOSTS=10.10.10.10 \
      --link hadoop01:hadoop01 \
      --name acc02 cybermaggedon/accumulo-gaffer:1.12.0

  docker run -d --ip=10.10.10.12 --net my_network \
      -e ZOOKEEPERS=10.10.5.10,10.10.5.11,10.10.5.12 \
      -e HDFS_VOLUMES=hdfs://hadoop01:9000/accumulo \
      -e NAMENODE_URI= \
      -e MY_HOSTNAME=10.10.10.12 \
      -e GC_HOSTS=10.10.10.10 \
      -e MASTER_HOSTS=10.10.10.10 \
      -e SLAVE_HOSTS=10.10.10.10,10.10.10.11,10.10.10.12 \
      -e MONITOR_HOSTS=10.10.10.10 \
      -e TRACER_HOSTS=10.10.10.10 \
      --link hadoop01:hadoop01 \
      --name acc03 cybermaggedon/accumulo-gaffer:1.12.0

  ############################################################################
  # Wildfly, 3 nodes
  ############################################################################

  # Run Wildfly, on ports 8080-8082.
  docker run -d --name wildfly1 --ip=10.10.11.10 --net my_network \
      -e ZOOKEEPERS=10.10.5.10,10.10.5.11,10.10.5.12 \
      -p 8080:8080 cybermaggedon/wildfly-gaffer:1.12.0
  docker run -d --name wildfly2 --ip=10.10.11.11 --net my_network \
      -e ZOOKEEPERS=10.10.5.10,10.10.5.11,10.10.5.12 \
      -p 8081:8080 cybermaggedon/wildfly-gaffer:1.12.0
  docker run -d --name wildfly3 --ip=10.10.11.12 --net my_network \
      -e ZOOKEEPERS=10.10.5.10,10.10.5.11,10.10.5.12 \
      -p 8082:8080 cybermaggedon/wildfly-gaffer:1.12.0


```
To set up a resilient Accumulo cluster, you need to run each of the Accumulo
processes in its own container, so that failure can be more easily detected
and recovered.

```
  ############################################################################
  # Create network
  ############################################################################
  docker network create --driver=bridge --subnet=10.10.0.0/16 my_network

  ############################################################################
  # HDFS
  ############################################################################

  # Namenode
  docker run -d --ip=10.10.6.3 --net my_network \
      -e DAEMONS=namenode,datanode,secondarynamenode \
      --name=hadoop01 \
      -p 50070:50070 -p 50075:50075 -p 50090:50090 -p 9000:9000 \
      cybermaggedon/hadoop:2.10.0

  # Datanodes
  docker run -d --ip=10.10.6.4 --net my_network --link hadoop01:hadoop01 \
      -e DAEMONS=datanode -e NAMENODE_URI=hdfs://hadoop01:9000 \
      --name=hadoop02 \
      cybermaggedon/hadoop:2.10.0

  docker run -d --ip=10.10.6.5 --net my_network --link hadoop01:hadoop01 \
      -e DAEMONS=datanode -e NAMENODE_URI=hdfs://hadoop01:9000 \
      --name=hadoop03 \
      cybermaggedon/hadoop:2.10.0

  ############################################################################
  # Zookeeper cluster, 3 nodes.
  ############################################################################
  docker run -d --ip=10.10.5.10 --net my_network \
      -e ZOOKEEPERS=10.10.5.10,10.10.5.11,10.10.5.12 \
      -e ZOOKEEPER_MYID=1 \
      --name zk1 -p 2181:2181 cybermaggedon/zookeeper:3.6.1
      
  docker run -d --ip=10.10.5.11 --net my_network \
      -e ZOOKEEPERS=10.10.5.10,10.10.5.11,10.10.5.12 \
      -e ZOOKEEPER_MYID=2 --name zk2 --link zk1:zk1 \
      cybermaggedon/zookeeper:3.6.1
      
  docker run -d --ip=10.10.5.12 --net my_network \
      -e ZOOKEEPERS=10.10.5.10,10.10.5.11,10.10.5.12 \
      -e ZOOKEEPER_MYID=3 --name zk3 --link zk1:zk1 \
      cybermaggedon/zookeeper:3.6.1

  ############################################################################
  # Accumulo, 3 nodes
  ############################################################################

  # Master
  docker run -d --ip=10.10.10.10 --net my_network \
      -p 50095:50095 \
      -e ZOOKEEPERS=10.10.5.10,10.10.5.11,10.10.5.12 \
      -e HDFS_VOLUMES=hdfs://hadoop01:9000/accumulo \
      -e NAMENODE_URI=hdfs://hadoop01:9000/ \
      -e MY_HOSTNAME=10.10.10.10 \
      -e MASTER_HOSTS=10.10.10.10 \
      -e GC_HOSTS=10.10.10.11 \
      -e SLAVE_HOSTS=10.10.10.12,10.10.10.13,10.10.10.14 \
      -e MONITOR_HOSTS=10.10.10.15 \
      -e TRACER_HOSTS=10.10.10.16 \
      --link hadoop01:hadoop01 \
      --name acc-master \
      cybermaggedon/accumulo-gaffer:1.12.0 /start-process master

  # GC
  docker run -d --ip=10.10.10.11 --net my_network \
      -e ZOOKEEPERS=10.10.5.10,10.10.5.11,10.10.5.12 \
      -e HDFS_VOLUMES=hdfs://hadoop01:9000/accumulo \
      -e NAMENODE_URI=hdfs://hadoop01:9000/ \
      -e MY_HOSTNAME=10.10.10.11 \
      -e MASTER_HOSTS=10.10.10.10 \
      -e GC_HOSTS=10.10.10.11 \
      -e SLAVE_HOSTS=10.10.10.12,10.10.10.13,10.10.10.14 \
      -e MONITOR_HOSTS=10.10.10.15 \
      -e TRACER_HOSTS=10.10.10.16 \
      --link hadoop01:hadoop01 \
      --name acc-gc cybermaggedon/accumulo-gaffer:1.12.0 /start-process gc

  # Slave 1
  docker run -d --ip=10.10.10.12 --net my_network \
      -e ZOOKEEPERS=10.10.5.10,10.10.5.11,10.10.5.12 \
      -e HDFS_VOLUMES=hdfs://hadoop01:9000/accumulo \
      -e NAMENODE_URI=hdfs://hadoop01:9000/ \
      -e MY_HOSTNAME=10.10.10.12 \
      -e MASTER_HOSTS=10.10.10.10 \
      -e GC_HOSTS=10.10.10.11 \
      -e SLAVE_HOSTS=10.10.10.12,10.10.10.13,10.10.10.14 \
      -e MONITOR_HOSTS=10.10.10.15 \
      -e TRACER_HOSTS=10.10.10.16 \
      --link hadoop01:hadoop01 \
      --name acc-slave1 cybermaggedon/accumulo-gaffer:1.12.0 \
      /start-process tserver

  # Slave 2
  docker run -d --ip=10.10.10.13 --net my_network \
      -e ZOOKEEPERS=10.10.5.10,10.10.5.11,10.10.5.12 \
      -e HDFS_VOLUMES=hdfs://hadoop01:9000/accumulo \
      -e NAMENODE_URI=hdfs://hadoop01:9000/ \
      -e MY_HOSTNAME=10.10.10.13 \
      -e MASTER_HOSTS=10.10.10.10 \
      -e GC_HOSTS=10.10.10.11 \
      -e SLAVE_HOSTS=10.10.10.12,10.10.10.13,10.10.10.14 \
      -e MONITOR_HOSTS=10.10.10.15 \
      -e TRACER_HOSTS=10.10.10.16 \
      --link hadoop01:hadoop01 \
      --name acc-slave2 cybermaggedon/accumulo-gaffer:1.12.0 \
      /start-process tserver

  # Slave 3
  docker run -d --ip=10.10.10.14 --net my_network \
      -e ZOOKEEPERS=10.10.5.10,10.10.5.11,10.10.5.12 \
      -e HDFS_VOLUMES=hdfs://hadoop01:9000/accumulo \
      -e NAMENODE_URI=hdfs://hadoop01:9000/ \
      -e MY_HOSTNAME=10.10.10.14 \
      -e MASTER_HOSTS=10.10.10.10 \
      -e GC_HOSTS=10.10.10.11 \
      -e SLAVE_HOSTS=10.10.10.12,10.10.10.13,10.10.10.14 \
      -e MONITOR_HOSTS=10.10.10.15 \
      -e TRACER_HOSTS=10.10.10.16 \
      --link hadoop01:hadoop01 \
      --name acc-slave3 cybermaggedon/accumulo-gaffer:1.12.0 \
      /start-process tserver

  # Monitor - this has the web server.
  docker run -d --ip=10.10.10.15 --net my_network \
      -p 9995:9995 \
      -e ZOOKEEPERS=10.10.5.10,10.10.5.11,10.10.5.12 \
      -e HDFS_VOLUMES=hdfs://hadoop01:9000/accumulo \
      -e NAMENODE_URI=hdfs://hadoop01:9000/ \
      -e MY_HOSTNAME=10.10.10.15 \
      -e MASTER_HOSTS=10.10.10.10 \
      -e GC_HOSTS=10.10.10.11 \
      -e SLAVE_HOSTS=10.10.10.12,10.10.10.13,10.10.10.14 \
      -e MONITOR_HOSTS=10.10.10.15 \
      -e TRACER_HOSTS=10.10.10.16 \
      --link hadoop01:hadoop01 \
      --name acc-monitor \
      cybermaggedon/accumulo-gaffer:1.12.0 /start-process monitor

  docker run -d --ip=10.10.10.16 --net my_network \
      -e ZOOKEEPERS=10.10.5.10,10.10.5.11,10.10.5.12 \
      -e HDFS_VOLUMES=hdfs://hadoop01:9000/accumulo \
      -e NAMENODE_URI=hdfs://hadoop01:9000/ \
      -e MY_HOSTNAME=10.10.10.16 \
      -e MASTER_HOSTS=10.10.10.10 \
      -e GC_HOSTS=10.10.10.11 \
      -e SLAVE_HOSTS=10.10.10.12,10.10.10.13,10.10.10.14 \
      -e MONITOR_HOSTS=10.10.10.15 \
      -e TRACER_HOSTS=10.10.10.16 \
      --link hadoop01:hadoop01 \
      --name acc-tracer \
      cybermaggedon/accumulo-gaffer:1.12.0 /start-process tracer


  ############################################################################
  # Wildfly, 3 nodes
  ############################################################################

  # Run Wildfly, on ports 8080-8082.
  docker run -d --name wildfly1 --ip=10.10.11.10 --net my_network \
      -e ZOOKEEPERS=10.10.5.10,10.10.5.11,10.10.5.12 \
      -p 8080:8080 cybermaggedon/wildfly-gaffer:1.12.0
  docker run -d --name wildfly2 --ip=10.10.11.11 --net my_network \
      -e ZOOKEEPERS=10.10.5.10,10.10.5.11,10.10.5.12 \
      -p 8081:8080 cybermaggedon/wildfly-gaffer:1.12.0
  docker run -d --name wildfly3 --ip=10.10.11.12 --net my_network \
      -e ZOOKEEPERS=10.10.5.10,10.10.5.11,10.10.5.12 \
      -p 8082:8080 cybermaggedon/wildfly-gaffer:1.12.0


```

If you want persistence, mount volumes on ```/data``` for Hadoop and
Zookeeper.  Accumulo and Wildfly need no persistent state volumes.

For configuration options on Accumulo, see <https://github.com/cybermaggedon/accumulo-docker/blob/master/README.md>.

Our Wildfly container is configured by setting the following environment
variables:
- ```ZOOKEEPERS```: a comma-separate list of Zookeeper hostnames or IP
  addresses.
- ```ACCUMULO_INSTANCE```: Accumulo instance name.  If you've used the default
  you should have no reason to change this from the default ```accumulo```.
- ```ACCUMULO_USER``` and ```ACCUMULO_SECRET```: Username and password.

Source is at <https://github.com/cybermaggedon/gaffer-docker>.

