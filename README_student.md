# Nginx MLOps project

## Run

In WSL/Linux, with Docker Compose v2, Make, Bash and curl installed:

```sh
make start-project
make test
make stop-project
```

The first build needs internet access. Wait for the services to be ready before
running tests. No host Python installation is required.

## Architecture and usage

Nginx is the prediction gateway. HTTP on port 8080 redirects to HTTPS on port 443.
Three internal v1 replicas receive ordinary prediction requests; the header
`X-Experiment-Group: debug` selects v2, which adds prediction probabilities.
The API containers do not publish their ports to the host.

`/predict` uses Basic Auth (`admin` / `admin`) and a shared per-IP limit of 10r/s,
with a burst allowance of five excess requests. The configuration explicitly sets
`limit_req_status 429`, so rejected requests receive HTTP 429 (Too Many Requests).
Clients behind one NAT may share a rate-limit bucket.

```sh
make test-api
curl --cacert deployments/nginx/certs/nginx.crt -u admin:admin \
  -H 'Content-Type: application/json' -H 'X-Experiment-Group: debug' \
  -d '{"sentence":"This is wonderful!"}' https://localhost/predict
```

The supplied self-signed localhost certificate is trusted explicitly by curl.
Browsers may show a certificate warning. Credentials and keys are local demo values.

## Monitoring bonus

Prometheus is at http://localhost:9090 and Grafana at
http://localhost:3000/d/nginx-overview (admin/admin on a fresh volume).
The datasource and dashboard are provisioned from `deployments/grafana/`.
Prometheus scrapes the exporter every three seconds; `nginx_up=1` confirms the
exporter can reach Nginx. Nginx status uses internal, unpublished port 8081.
Grafana displays availability, active connections and request rate.
Existing monitoring volumes retain saved data and any changed login password.

## Verification

`make test` runs the supplied `tests/run_tests.sh` without modifications, so the
examiner can use the original test script. No additional test cases are included.

The script checks a successful prediction, the debug response field, rejection of
incorrect credentials, and Prometheus/Grafana availability. Its rate-limit test
sends 15 concurrent requests and prints their HTTP statuses. With the current
configuration, limited requests return HTTP 429.

The original rate-limit pass/fail condition only checks that a subsequent response
is not HTTP 502; it does not automatically assert that the burst contains HTTP 429.
Consequently, a passing result alone does not prove the exact 10r/s rate or burst
recovery. The original script is retained as supplied rather than changing the
examiner's checks. It also does not automatically verify HTTP redirect, traffic
distribution across all replicas, or that Nginx metrics reach Grafana.

For configuration checks and troubleshooting:

```sh
docker compose exec -T nginx nginx -t
docker compose exec -T prometheus promtool check config /etc/prometheus/prometheus.yml
docker compose ps
docker compose logs --tail=50 nginx nginx_exporter prometheus grafana
```
