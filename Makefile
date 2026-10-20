.PHONY: test-api start-project stop-project test

test-api:
	curl -X POST "https://localhost/predict" \
     -H "Content-Type: application/json" \
     -d '{"sentence": "Oh yeah, that was soooo cool!"}' \
	 --user admin:admin \
     --cacert ./deployments/nginx/certs/nginx.crt;

start-project:
	docker compose up -d --build
	@echo "Grafana UI: http://localhost:3000"

stop-project:
	docker compose down

test:
	bash ./tests/run_tests.sh
