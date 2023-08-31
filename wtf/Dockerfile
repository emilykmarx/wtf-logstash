FROM ubuntu:22.04

WORKDIR /usr/src/app

# Putting logstash into cluster bc probs easier than figuring out mysql port-forward for the jdbc plugin
RUN apt-get update \
    && apt-get install -y \
    wget \
    vim \
    && rm -rf /var/lib/apt/lists/*

COPY . wtf-logstash
# no-op if copying from a local version of logstash with plugin already installed
WORKDIR wtf-logstash
RUN bin/logstash-plugin install --no-verify

RUN wget --directory-prefix=wtf https://dev.mysql.com/get/Downloads/Connector-J/mysql-connector-j-8.1.0.tar.gz \
  && tar xzf wtf/mysql-connector-j-8.1.0.tar.gz -C wtf

CMD ["bin/logstash", "-f", "wtf/pipeline.conf"]
