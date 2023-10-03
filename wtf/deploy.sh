#!/bin/bash

set -e

# Should have already port-forwarded rmq and created logs exch (by running rmq_publisher)
# TODO there likely need to be more sleeps in here, and existing ones are not long enough
# For ES; this isn't persistent
sudo sysctl -w vm.max_map_count=655300

# Clean up
set +e
kubectl delete deployment elasticsearch
kubectl delete svc elasticsearch
kubectl delete deployment logstash
kubectl delete svc logstash
helm uninstall es-exporter
helm uninstall ls-exporter
kubectl delete -f ../../train-ticket/deployment/kubernetes-manifests/prometheus
set -e

# ElasticSearch
docker build -t elasticsearch -f es_Dockerfile .
kind load docker-image elasticsearch:8.9.0 --name train-ticket
kubectl apply -f es_deploy.yml
# expose so LS can reach it
kubectl expose deployment/elasticsearch --type="NodePort" --port 9200

# Logstash
pushd .. # build context must be root to copy files above wtf/
docker build -t logstash -f wtf/ls_Dockerfile .
popd
kind load docker-image logstash:latest --name train-ticket
kubectl apply -f ls_deploy.yml
# expose so LS exporter can reach it
kubectl expose deployment/logstash --type="NodePort" --port 9600


# Test: Make requests, see that they go through the pipeline and are counted in Prom metrics
# TODO replace this quick test with wtf.py
# pushd ../../train-ticket-auto-query/; python3 wtf.py; popd
# OR faster:
sleep 20 # wait for ls to start
pushd ../../rabbitmq-tutorials/go; go run wtf/rmq_publisher.go -msg="new"; popd
printf "\n\n Test requests made it to ES \n\n"
sleep 5 # wait for msg to get to ES
kubectl exec -it nacos-0 -- curl http://elasticsearch:9200/wtf_index/_search?pretty=true -H 'Content-Type: application/json' \
  -d '{"query":{"query_string":{"query":"*"}}}'

# Prometheus
kubectl apply -f ../../train-ticket/deployment/kubernetes-manifests/prometheus

## ES
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm install es-exporter prometheus-community/prometheus-elasticsearch-exporter --set es.uri=http://elasticsearch:9200

sleep 20 # wait for es exporter to start, and metrics to get scraped
printf "\n\n Test ES \n\n"
# Test ES exports Prom metrics
kubectl exec -it nacos-0 -- curl http://es-exporter-prometheus-elasticsearch-exporter:9108/metrics | grep elasticsearch_indices_docs_total
# Test Prom scrapes ES metrics
kubectl exec -it nacos-0 -- curl http://prometheus.kube-system.svc.cluster.local:9090/api/v1/query?query=elasticsearch_indices_docs_total

## LS
pushd ../../logstash-exporter/chart
helm install ls-exporter . --set logstash.url=http://logstash:9600

sleep 10 # wait for ls exporter to start
printf "\n\n Test LS \n\n"
# Test LS exports Prom metrics (may need to wait a bit?)
kubectl exec -it nacos-0 -- curl http://ls-exporter-logstash-exporter:9198/metrics | grep logstash_stats_pipeline_events_out
# Test Prom scrapes LS metrics
kubectl exec -it nacos-0 -- curl http://prometheus.kube-system.svc.cluster.local:9090/api/v1/query?query=logstash_stats_pipeline_events_out

popd

## RMQ
RMQ=$(kubectl get pods -l app=rabbitmq --no-headers -o custom-columns=":metadata.name")
kubectl exec -it $RMQ -- rabbitmq-plugins enable rabbitmq_prometheus
# Test RMQ exports Prom metrics (may need to wait a bit?)
kubectl exec -it nacos-0 -- curl http://rabbitmq:15692/metrics | grep rabbitmq_queues
# Test Prom scrapes RMQ metrics
kubectl exec -it nacos-0 -- curl http://prometheus.kube-system.svc.cluster.local:9090/api/v1/query?query=rabbitmq_queues

## Agent
pushd agent
docker build -t es_client -f es_client_Dockerfile .
kind load docker-image es_client:latest --name train-ticket
# TODO currently just attaching and manually running entrypoint (es_client.py)
kubectl run es-client -n default --image=es_client -it --rm --restart='Never' --image-pull-policy Never
popd
