#!/bin/bash

set -e

pushd .. # build context must be root to copy files above wtf/

docker build -t logstash -f wtf/Dockerfile .
kind load docker-image logstash:latest --name train-ticket
# pull policy is needed for kubectl run, else kind tries to pull it even when it's loaded
kubectl run logstash -n default --image=logstash -it --rm --restart='Never' --image-pull-policy Never

popd
