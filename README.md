# UDS Software Factory
:construction: **This project is still early in its development.**

A tool to facilitate the development, sharing, testing, deployment and accreditation of custom software. This package assumes all its prerequisites are met.

## Prerequisites

### Kubernetes Cluster
- 1.26
- Compute power that is comparable to the  [m6id.8xlarge](https://aws.amazon.com/ec2/instance-types/#:~:text=Up%20to%2010-,m6id.8xlarge,-32) AWS instance type used in our E2E tests.

### Defense Unicorns Big Bang Distro (DUBBD)
The UDS Software Factory capabilities are configured to use things like the istio service mesh. This package should be deployed to a cluster that contains the [Defense Unicorns Big Bang Distro](https://github.com/defenseunicorns/uds-package-dubbd).

- Minimum Version Required: [DUBBD v0.5.0](https://github.com/defenseunicorns/uds-package-dubbd/tree/v0.5.0)

### GitLab Capability
The Gitlab Capability expects the pieces listed below to exist in the cluster before being deployed.

- `gitlab` namespace exists
- `gitlab-postgres` secret created with `password` key that contains password to postgres database
- `gitlab-postgres` database is running on port `5432`
- `gitlab-uds-software-factory` database created in postgres database
- `gitlab` user created in postgres database
- `gitlab` user given write access to `gitlab-uds-software-factory` database in postgres
- `gitlab-postgres` service exists in `gitlab` namespace that points to the postgres database url
- `gitlab-redis` secret created with `password` key that contains password to redis
- `gitlab-redis` service exists in `gitlab` namespace that points to the redis master url
- `gitlab-redis` instance is running on port `6379`

### More capabilities are under construction
