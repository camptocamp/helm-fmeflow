HELM ?= helm

.PHONY: examples-clean
examples-clean:
	rm -f examples/basic/charts/*.tgz
	rm -f examples/external-db-traefik/charts/*.tgz
	${HELM} uninstall fmeflow-basic || true
	${HELM} uninstall fmeflow-external-db-traefik || true

.PHONY: dependencies
dependencies:
	${HELM} dependency update .

.PHONY: gen-expected
gen-expected: dependencies
	${HELM} dependency update examples/basic
	${HELM} dependency update examples/external-db-traefik
	${HELM} template --namespace=default fmeflow-basic examples/basic > tests/expected-basic.yaml
	${HELM} template --namespace=default fmeflow-external-db-traefik examples/external-db-traefik > tests/expected-external-db-traefik.yaml
	sed -i 's/[[:blank:]]\+$$//g' tests/expected*.yaml

.PHONY: example-basic
example-basic: dependencies
	${HELM} dependency update examples/basic
	${HELM} upgrade --install fmeflow-basic examples/basic

.PHONY: example-external-db-traefik
example-external-db-traefik: dependencies
	${HELM} dependency update examples/external-db-traefik
	${HELM} upgrade --install fmeflow-external-db-traefik examples/external-db-traefik
