# Examples

- [basic](basic/): a minimal FME Flow deployment, the default values with just the
  external hostname and the database host set.
- [external-db-traefik](external-db-traefik/): a deployment close to the Camptocamp
  geo-services integration: external PostgreSQL with SSL, docker registry pull secret,
  ReadWriteMany system share on `azurefile-csi`, Traefik ingress with a cert-manager
  TLS certificate.

To run an example on a local cluster (k3d or kind):

```bash
make dependencies
make example-basic
```

The FME Flow pods need a PostgreSQL database (see the `PGSQL*` configuration keys),
a valid FME Flow license in the system share to fully start, and a lot of disk space
(the images are several gigabytes each).

To stop and clean everything:

```bash
make examples-clean
```
