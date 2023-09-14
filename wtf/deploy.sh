#!/bin/bash

set -e

sudo sysctl -w vm.max_map_count=655300

# ElasticSearch
docker build -t elasticsearch -f es_Dockerfile .
kind load docker-image elasticsearch:8.9.0 --name train-ticket
kubectl apply -f es_deploy.yml
kubectl expose deployment/elasticsearch --type="NodePort" --port 9200

# Logstash
pushd .. # build context must be root to copy files above wtf/

docker build -t logstash -f wtf/ls_Dockerfile .
kind load docker-image logstash:latest --name train-ticket
kubectl run logstash -n default --image=logstash --restart='Never' --image-pull-policy Never # add -it and --rm to attach, and -- bash -il for just bash

popd

# To test: make requests, see that they go through the pipeline
pushd ../../train-ticket-auto-query/; python3 wtf.py; popd
# In reality, this wouldn't be in the logstash pod - just here for now for convenience
kubectl exec -it logstash -- curl http://elasticsearch:9200/wtf_index/_search?pretty=true -H 'Content-Type: application/json' \
  -d '{"query":{"query_string":{"query":"*"}}}'
# should see the requests here
