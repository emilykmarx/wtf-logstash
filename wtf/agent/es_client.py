from elasticsearch import Elasticsearch
import subprocess

def main():
  es = Elasticsearch(hosts="http://elasticsearch:9200")

  # Query ES
  resp = es.search(index="wtf_index", query={"match_all": {}})
  n_hits = resp['hits']['total']['value']
  print(f"Got {n_hits} hits")
  for hit in resp['hits']['hits']:
    print(hit["_source"])

  if n_hits == 0:
    # Get bits from Prometheus metrics
    subprocess.check_output("wtf-prometheus-agent/target/debug/fetch_one -c prom_bounds.toml",
                            shell=True, text=True)

if __name__ == '__main__':
  main()
