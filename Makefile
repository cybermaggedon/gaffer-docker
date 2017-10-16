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

GAFFER_VERSION=1.0.0
KORYPHE_VERSION=1.0.0
VERSION=$(shell git describe | sed 's/^v//')
ACCUMULO_REPOSITORY=docker.io/cybermaggedon/accumulo-gaffer
WILDFLY_REPOSITORY=docker.io/cybermaggedon/wildfly-gaffer

WAR_FILES=\
	gaffer/accumulo-rest/${GAFFER_VERSION}/accumulo-rest-${GAFFER_VERSION}.war

JAR_FILES=\
        gaffer/accumulo-store/${GAFFER_VERSION}/accumulo-store-${GAFFER_VERSION}-iterators.jar \
        gaffer/common-util/${GAFFER_VERSION}/common-util-${GAFFER_VERSION}.jar \
        koryphe/core/${KORYPHE_VERSION}/core-${KORYPHE_VERSION}.jar \
        gaffer/serialisation/${GAFFER_VERSION}/serialisation-${GAFFER_VERSION}.jar

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
	${SUDO} docker build ${PROXY_ARGS} ${PROXY_HOST_PORT_ARGS} ${BUILD_ARGS} --build-arg GAFFER_VERSION=${GAFFER_VERSION} -t gaffer-build -f Dockerfile.build .
	id=$$(${SUDO} docker run -d gaffer-build sleep 3600); \
	dir=/root/.m2/repository/uk/gov/gchq; \
	for file in ${WAR_FILES} ${JAR_FILES}; do \
		bn=$$(basename $$file); \
		${SUDO} docker cp $${id}:$${dir}/$${file} product/$${bn}; \
	done; \
	${SUDO} docker rm -f $${id}

container: wildfly-11.0.0.CR1.zip
	${SUDO} docker build ${PROXY_ARGS} ${BUILD_ARGS} -t ${ACCUMULO_REPOSITORY}:${VERSION} -f Dockerfile.accumulo .
	${SUDO} docker build ${PROXY_ARGS} ${BUILD_ARGS} -t ${WILDFLY_REPOSITORY}:${VERSION} -f Dockerfile.wildfly .

wildfly-11.0.0.CR1.zip:
	wget -O $@ download.jboss.org/wildfly/11.0.0.CR1/wildfly-11.0.0.CR1.zip

push:
	${SUDO} docker push ${ACCUMULO_REPOSITORY}:${VERSION}
	${SUDO} docker push ${WILDFLY_REPOSITORY}:${VERSION}
