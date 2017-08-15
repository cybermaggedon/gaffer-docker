
all: everything.json

%.json: %.jsonnet jsonnet ksonnet
	jsonnet/jsonnet -J ksonnet/ ${@:%.json=%.jsonnet} > $@

everything.json: hadoop.jsonnet zookeeper.jsonnet accumulo.jsonnet \
	wildfly.jsonnet

everything.yaml: everything.json
	kubectl convert -f everything.json -o yaml > $@

ksonnet:
	git clone https://github.com/ksonnet/ksonnet-lib ksonnet

jsonnet:
	rm -rf jsonnet.WORKING
	git clone https://github.com/google/jsonnet jsonnet.WORKING
	(cd jsonnet.WORKING; make)
	mv jsonnet.WORKING jsonnet

apply:
	kubectl apply -f everything.json

delete:
	kubectl delete -f everything.json

