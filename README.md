# Helm chart for FME Flow

A Helm chart to deploy [FME Flow](https://www.safe.com/fme/fme-flow/) (2024.1 and newer) on Kubernetes,
built on top of the [camptocamp/helm-application](https://github.com/camptocamp/helm-application) chart.

Migrating an existing deployment from the Safe Software `fmeflow` chart? See [MIGRATION.md](MIGRATION.md).

## Components

| Service           | Kind        | Description                                                                                                                       |
| ----------------- | ----------- | --------------------------------------------------------------------------------------------------------------------------------- |
| `core`            | StatefulSet | The `dbinit` initContainer (database schema creation/migration) and the `core`, `web` (UI, port 8080) and `fmeutility` containers |
| `queue`           | StatefulSet | The FME Flow queue                                                                                                                |
| `websocket`       | StatefulSet | The web UI notifications                                                                                                          |
| `engine-standard` | Deployment  | The STANDARD engine group                                                                                                         |
| `engine-dynamic`  | Deployment  | The DYNAMIC engine group (disabled by default)                                                                                    |

All the object names are generated from the Helm release name (the helm-application naming
conventions), several FME Flow instances can be deployed in the same namespace with different
release names (each instance needs its own database, system share and hostname).

## Include this chart as dependency of your own chart

With the OCI repository (recommended, this is what ArgoCD uses):

```yaml
dependencies:
  - name: fmeflow
    repository: oci://ghcr.io/camptocamp/helm-fmeflow
    version: <version-number-here>
```

Or with the GitHub Pages repository:

```yaml
dependencies:
  - name: fmeflow
    repository: https://camptocamp.github.io/helm-fmeflow
    version: <version-number-here>
```

The chart values are then under the `fmeflow:` key, the helm-application values are under
the `fmeflow.fmeflow:` key.

## Configuration

See the [examples](examples/) and the comments in [values.yaml](values.yaml).

### FME Flow version

All the images use the same tag, set it in every container, or override the
`fmeflow-version` YAML anchor usage with your own values, for example:

```yaml
fmeflow:
  fmeflow:
    services:
      core:
        initContainers:
          dbinit:
            image:
              tag: '2026.3.1'
        containers:
          core:
            image:
              tag: '2026.3.1'
          web:
            image:
              tag: '2026.3.1'
          fmeutility:
            image:
              tag: '2026.3.1'
      queue:
        containers:
          queue:
            image:
              tag: '2026.3.1'
      websocket:
        containers:
          websocket:
            image:
              tag: '2026.3.1'
      engine-standard:
        containers:
          engine:
            image:
              tag: '2026.3.1'
```

The `sha` property of the images can be used to pin the digests (filled by the
image hash automation in the argocd-gs-\*-apps repositories).

### Deployment wide configuration

The external hostname, the database connection and the FME Flow tuning live in a
ConfigMap (`fme.fmeflow.configMaps.content`) injected as environment variables in the
containers, override the values there instead of overriding every container:

```yaml
fmeflow:
  fmeflow:
    configMaps:
      content:
        EXTERNALHOSTNAME:
          value: fme.example.com
        PGSQLHOSTNAME:
          value: pg.example.com
        PGSQLUSERNAME:
          value: fmeflow@pg.example.com # Azure Database for PostgreSQL format
        AZUREPOSTGRESQL:
          value: 'true'
        POSTGRESQLSSL:
          value: 'true'
```

The database passwords are read from a Secret, by default `fme-database` with the
`password` and `admin-password` keys, override the `PGSQLPASSWORD` and
`PGSQLADMINPASSWORD` environment variables of the containers to use your own
(for example an ExternalSecret).

### Storage

The FME Flow system share is a PersistentVolumeClaim (`fme.fmeflow.persistentVolumeClaims.data`)
mounted by all the components in `/data/fmeflowdata`, it should be `ReadWriteMany` when the
components can run on different nodes. Use `fullnameOverride` to reuse an existing claim
(see [MIGRATION.md](MIGRATION.md)).

### Ingress and TLS

Enable the top level ingress and the ingress of the `core` (web UI, path `/`) and
`websocket` (path `/websocket`) services, the TLS certificate is issued by cert-manager
with the Ingress annotations:

```yaml
fmeflow:
  fmeflow:
    ingress:
      enabled: true
      ingressClassName: traefik
      annotations:
        cert-manager.io/cluster-issuer: letsencrypt-prod
        traefik.ingress.kubernetes.io/router.tls: 'true'
      hostGroups:
        main:
          hosts:
            - fme.example.com
          tls:
            enabled: true
            secretName: fme-tls
    services:
      core:
        ingress:
          enabled: true
      websocket:
        ingress:
          enabled: true
```

### Image pull secrets

The FME Flow images are on Docker Hub (`safesoftware/*`), reference existing docker
registry secrets with `fme.fmeflow.global.image.pullSecrets`.

### Health checks

The liveness/readiness/startup probes are enabled by default, disable them by setting
the probes to `{}` in the corresponding containers.

## Contributing

Install the pre-commit hooks (we use `prek`):

```bash
prek install --allow-missing-config --config=.pre-commit-config.yaml
```

The golden files in `tests/` are generated from the `examples/` by the `helm-template-gen`
pre-commit hook, they can also be regenerated with:

```bash
make gen-expected
```

To run an example on a local cluster (k3d/kind), see the [Makefile](Makefile):

```bash
make example-basic
```
