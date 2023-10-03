#!/bin/bash

set -e

# TODO readme for e2e tt and ELK deps & deploy

# Logstash
# Get logstash files (regular and mine)
wget https://artifacts.elastic.co/downloads/logstash/logstash-8.9.0-linux-x86_64.tar.gz
tar xzvf logstash-8.9.0-linux-x86_64.tar.gz
git clone --recurse-submodules https://github.com/emilykmarx/wtf-logstash.git
rm logstash-8.9.0/Gemfile # want to use my version of Gemfile
cp -r logstash-8.9.0/* wtf-logstash/

# Prometheus
git clone https://github.com/kuskoman/logstash-exporter
