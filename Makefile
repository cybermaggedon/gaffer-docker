##########################################################
# Copyright 2016 Crown Copyright, cybermaggedon
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
##########################################################

GAFFER_VERSION=1.12.0
KORYPHE_VERSION=1.8.4
VERSION=$(shell git describe | sed 's/^v//')
ACCUMULO_REPOSITORY=docker.io/cybermaggedon/accumulo-gaffer
WILDFLY_REPOSITORY=docker.io/cybermaggedon/wildfly-gaffer
ACCUMULO_VERSION=$(shell cat accumulo-version)
HADOOP_VERSION=2.10.0

DOCKER=docker

WAR_FILES=\
	uk/gov/gchq/gaffer/accumulo-rest/${GAFFER_VERSION}/accumulo-rest-${GAFFER_VERSION}.war

JAR_FILES=\
        uk/gov/gchq/gaffer/accumulo-store/${GAFFER_VERSION}/accumulo-store-${GAFFER_VERSION}-iterators.jar \
        uk/gov/gchq/gaffer/common-util/${GAFFER_VERSION}/common-util-${GAFFER_VERSION}.jar \
        uk/gov/gchq/koryphe/core/${KORYPHE_VERSION}/core-${KORYPHE_VERSION}.jar \
        uk/gov/gchq/gaffer/serialisation/${GAFFER_VERSION}/serialisation-${GAFFER_VERSION}.jar \
	uk/gov/gchq/gaffer/time-library/${GAFFER_VERSION}/time-library-${GAFFER_VERSION}.jar \
	uk/gov/gchq/gaffer/bitmap-library/${GAFFER_VERSION}/bitmap-library-${GAFFER_VERSION}.jar \
	uk/gov/gchq/gaffer/sketches-library/${GAFFER_VERSION}/sketches-library-${GAFFER_VERSION}.jar \
        org/roaringbitmap/RoaringBitmap/0.5.11/RoaringBitmap-0.5.11.jar \
	com/yahoo/datasketches/sketches-core/0.12.0/sketches-core-0.12.0.jar \
	com/yahoo/datasketches/memory/0.12.0/memory-0.12.0.jar

SUDO=
BUILD_ARGS=

#PROXY_ARGS=--build-arg HTTP_PROXY=${http_proxy}
#PROXY_ARGS += --build-arg http_proxy=${http_proxy}
#PROXY_ARGS += --build-arg HTTPS_PROXY=${https_proxy}
#PROXY_ARGS += --build-arg https_proxy=${https_proxy}

#PROXY_HOST_PORT_ARGS=--build-arg proxy_host=${proxy_host}
#PROXY_HOST_PORT_ARGS += --build-arg proxy_port=${proxy_port}

all: build container

product:
	mkdir product

# In the future this could be removed when the Gaffer binaries are published to Maven Central.
build: product
	-rm -rf product/*
	${SUDO} ${DOCKER} build ${PROXY_ARGS} ${PROXY_HOST_PORT_ARGS} \
		${BUILD_ARGS} -t gaffer-dev -f Dockerfile.dev .
	${SUDO} ${DOCKER} build ${PROXY_ARGS} ${PROXY_HOST_PORT_ARGS} \
		${BUILD_ARGS} \
		--build-arg GAFFER_VERSION=${GAFFER_VERSION} \
		--build-arg HADOOP_VERSION=${HADOOP_VERSION} \
		--build-arg ACCUMULO_VERSION=${ACCUMULO_VERSION} \
		-t gaffer-build -f Dockerfile.build .
	id=$$(${SUDO} ${DOCKER} run -d gaffer-build sleep 3600); \
	dir=/root/.m2/repository; \
	for file in ${WAR_FILES} ${JAR_FILES}; do \
		bn=$$(basename $$file); \
		${SUDO} ${DOCKER} cp $${id}:$${dir}/$${file} product/$${bn}; \
	done; \
	${SUDO} ${DOCKER} rm -f $${id}

container: wildfly.zip
	echo 'FROM cybermaggedon/accumulo:${ACCUMULO_VERSION}' > Dockerfile.accumulo
	echo 'COPY product/*.jar /usr/local/accumulo/lib/ext/' >> Dockerfile.accumulo
	${SUDO} ${DOCKER} build ${PROXY_ARGS} ${BUILD_ARGS} -t ${ACCUMULO_REPOSITORY}:${VERSION} -f Dockerfile.accumulo .
	${SUDO} ${DOCKER} build ${PROXY_ARGS} ${BUILD_ARGS} -t ${WILDFLY_REPOSITORY}:${VERSION} -f Dockerfile.wildfly .

wildfly.zip:
	wget -O $@ download.jboss.org/wildfly/19.1.0.Final/wildfly-19.1.0.Final.zip

push:
	${SUDO} ${DOCKER} push ${ACCUMULO_REPOSITORY}:${VERSION}
	${SUDO} ${DOCKER} push ${WILDFLY_REPOSITORY}:${VERSION}

# Continuous deployment support
BRANCH=master
FILE=gaffer-version
REPO=git@github.com:trustnetworks/gaffer

tools: phony
	if [ ! -d tools ]; then \
		git clone git@github.com:trustnetworks/cd-tools tools; \
	fi; \
	(cd tools; git pull)

phony:

bump-version: tools
	tools/bump-version

update-cluster-config: tools
	tools/update-version-file ${BRANCH} ${VERSION} ${FILE} ${REPO}

