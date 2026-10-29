# Migration from the Safe Software fmeflow chart

This document describes how to migrate an existing FME Flow deployment from the Safe
Software `fmeflow` chart (for example the Camptocamp fork
[camptocamp/safesoftware-helm-charts](https://github.com/camptocamp/safesoftware-helm-charts)
served from the `tmp` branch) to this chart.

The migration replaces all the Kubernetes objects of the release except the system share
PersistentVolumeClaim and the TLS secret, which are taken over. Expect a short downtime:
the StatefulSets and the Services are deleted and recreated with new (release prefixed)
names, the FME Flow state itself lives in the PostgreSQL database and in the system share.

## Before the migration

1. **Backup the PostgreSQL database** used by FME Flow. The `dbinit` initContainer migrates
   the schema to the new FME Flow version on the first start, this is not reversible.
2. **Snapshot the system share** (the `fmeflow-data` PersistentVolumeClaim content, for
   example the Azure Files share), it contains the FME Flow configuration, the jobs and the
   licensing.
3. **Check the FME Flow license**: it must cover the target FME Flow version (for example
   2026.x), renew it in the system share before or right after the migration.
4. **Check the upgrade path** of a big version jump in the
   [FME Flow documentation](https://docs.safe.com/fmeflow/) (a migration/backup of the
   FME Flow configuration through the web UI is recommended before upgrading).
5. Note the current image tag and chart version to be able to roll back.

## Values mapping

| Safe Software chart                                                                   | This chart                                                                                                                                                                                                               |
| ------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `fmeflow.image.tag`                                                                   | `fmeflow.services.<service>.*.image.tag` (all the components use the same FME Flow version)                                                                                                                              |
| `fmeflow.image.pullSecrets`                                                           | `fmeflow.global.image.pullSecrets`                                                                                                                                                                                       |
| `fmeflow.database.host/port/name/user`                                                | The `hostname`/`port`/`database`/`username` keys of the database Secret (`fme-database` by default)                                                                                                                      |
| `fmeflow.database.passwordSecret/passwordSecretKey`                                   | The `password` key of the database Secret                                                                                                                                                                                |
| `fmeflow.database.adminUser/adminDatabase/adminPasswordSecret/adminPasswordSecretKey` | The `admin-username`/`admin-database`/`admin-password` keys of the database Secret (used by the `dbinit` initContainer)                                                                                                  |
| `fmeflow.database.azure`                                                              | Set the `username` key of the database Secret to `<user>@<host>` and `fmeflow.configMaps.content.AZUREPOSTGRESQL.value` to `'true'`                                                                                      |
| `fmeflow.database.ssl`                                                                | `fmeflow.configMaps.content.POSTGRESQLSSL.value: 'true'`                                                                                                                                                                 |
| `deployment.hostname`                                                                 | `fmeflow.configMaps.content.EXTERNALHOSTNAME.value`                                                                                                                                                                      |
| `deployment.port` / TLS disabled                                                      | `fmeflow.configMaps.content.EXTERNALPORT.value` / `WEBPROTOCOL.value: http`                                                                                                                                              |
| `deployment.certManager.issuerName`                                                   | `fmeflow.ingress.annotations['cert-manager.io/cluster-issuer']`                                                                                                                                                          |
| `deployment.tlsSecretName`                                                            | `fmeflow.ingress.hostGroups.<group>.tls.secretName`                                                                                                                                                                      |
| `deployment.ingress.general.ingressClassName/annotations`                             | `fmeflow.ingress.ingressClassName/annotations`                                                                                                                                                                           |
| `deployment.numCores`                                                                 | `fmeflow.services.core.replicaCount` (and `fmeflow.services.queue.replicaCount`)                                                                                                                                         |
| `fmeflow.engines.groups[]`                                                            | One `fmeflow.services.engine-<group>` service per group, with `ENGINETYPE` and `ENGINEPROPERTIES` (the FME engine group name, **keep the existing group names**, they are registered in the database) and `replicaCount` |
| `resources.core/web/queue/websocket/fmeutility/dbinit`                                | `fmeflow.services.<service>.containers.<container>.resources` and `fmeflow.services.core.initContainers.dbinit.resources`                                                                                                |
| `storage.fmeflow.size/class/accessMode`                                               | `fmeflow.persistentVolumeClaims.data.spec`                                                                                                                                                                               |
| `storage.fmeflow.existingClaim` / existing PV                                         | `fmeflow.persistentVolumeClaims.data.fullnameOverride` (reuse the claim by name) and `spec.volumeName` (bind an existing PersistentVolume)                                                                               |
| `fmeflow.extraVolumes` / `fmeflow.extraVolumeMounts`                                  | `volumes` / `volumeMounts` of each service and container (the helm-application native properties)                                                                                                                        |
| `fmeflow.healthcheck.enabled: false`                                                  | Set the probes to `{}` in the containers                                                                                                                                                                                 |
| `fmeflow.webserver.maxThreads/hikariDBMaxConnections/showPasswordLoginUI`             | `fmeflow.configMaps.content.MAXTHREADS/HIKARIDBMAXCONNECTIONS/SHOWPASSWORDLOGINUI.value`                                                                                                                                 |
| `fmeflow.debugLevel`                                                                  | `fmeflow.configMaps.content.COREDEBUGLEVEL.value`                                                                                                                                                                        |
| `externalSecrets` (app chart)                                                         | Unchanged (kept in the application chart), or use the helm-application `externalSecrets` property                                                                                                                        |

## Taking over the existing resources

Keep the system share claim name so that Helm updates the existing claim instead of
deleting and recreating it (the claim spec immutable fields — access modes, storage
class, volume name — must stay identical, the size can only grow):

The claim is named `<fullnameOverride>-data` (`<release>-fmeflow-data` by default),
set `fullnameOverride` so that the generated name is the existing claim name, for
example `fullnameOverride: fmeflow` gives `fmeflow-data`:

```yaml
fmeflow:
  fmeflow:
    persistentVolumeClaims:
      data:
        fullnameOverride: fmeflow # The claim will be named fmeflow-data
        spec:
          accessModes:
            - ReadWriteMany
          storageClassName: azurefile-csi
          resources:
            requests:
              storage: 80Gi # The current size, do not reduce it
```

Keep the TLS secret name so that cert-manager keeps the existing certificate:

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
            secretName: fmeflow-tls # The name used by the Safe Software chart
```

The database Secret (for example created by an ExternalSecret in the application
chart) is not managed by this chart: give it the name expected by the chart
(`fme-database` by default) with the keys listed in the README (`hostname`,
`port`, `database`, `username`, `password`, `admin-username`, `admin-password`,
`admin-database`), or override the `PGSQL*` environment variables of the
containers to use your own names and keys. With an ExternalSecret, adding the
missing keys to the existing resource is enough, the remote references can be
shared between the keys (for example `admin-username` and `username` pointing
to the same remote key).

## After the migration

1. Watch the `dbinit` initContainer logs of the core pod: it runs the database schema
   migration, this can take several minutes on a big version jump.
2. Check the web UI, log in, and run a job to validate the engines registration
   (the engine group names must be unchanged).
3. In the FME Flow web UI (Administration), remove the orphan hosts left by the old
   pods in the system share if any.
4. Once validated, remove the `fullnameOverride` workarounds if you do not need them
   anymore (only possible when recreating the resources, they are here to preserve the
   existing ones).

## Rollback

1. Revert the application values to the previous chart and version (the old
   StatefulSets/Services are recreated, the claim `fmeflow-data` and the TLS secret are
   untouched).
2. If the `dbinit` container already migrated the database schema to the new version,
   restore the PostgreSQL backup taken before the migration (the old FME Flow version
   cannot use a schema migrated by a newer version).
