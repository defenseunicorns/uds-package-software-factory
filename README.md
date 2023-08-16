# UDS Software Factory
:construction: **This project is still early in its development.**

A tool to facilitate the development, sharing, testing, deployment and accreditation of custom software. This package assumes all its prerequisites are met.

## Capabilities

  - [X] Gitlab
  - [X] Gitlab-Runner
  - [X] SonarQube
  - [ ] Nexus
  - [ ] Mattermost

## Prerequisites

### Kubernetes Cluster
- 1.26
- Compute power that is comparable to the **[m6id.8xlarge](https://aws.amazon.com/ec2/instance-types/#:~:text=Up%20to%2010-,m6id.8xlarge,-32)** AWS instance type used in our E2E tests.

### Defense Unicorns Big Bang Distro (DUBBD)
The UDS Software Factory capabilities are configured to use things like the istio service mesh. This package should be deployed to a cluster that contains the [Defense Unicorns Big Bang Distro](https://github.com/defenseunicorns/uds-package-dubbd).

- Minimum Version Required: [DUBBD v0.5.0](https://github.com/defenseunicorns/uds-package-dubbd/tree/v0.5.0)

### GitLab Capability
The Gitlab Capability expects the pieces listed below to exist in the cluster before being deployed.

#### General

- Create `gitlab` namespace
- Label `gitlab` namespace with `istio-injection: enabled`

#### Database

- A Postgres database is running on port `5432` and accessible to the cluster
- This database can be logged into via the username `gitlab`
- This database instance has a psql database created called `gitlab-uds-software-factory`
- The `gitlab` user has read/write access to `gitlab-uds-software-factory`
- Create `gitlab-postgres` service in `gitlab` namespace that points to the psql database
- Create `gitlab-postgres` secret in `gitlab` namespace with the key `password` that contains the password to the `gitlab` user for the psql database

#### Redis / Redis Equivalent

- An instance of Redis or Redis equivalent (elasticache, etc.) is running on port `6379` and accessible to the cluster
- The redis instance accepts anonymous auth (password only)
- Create `gitlab-redis` service in `gitlab` namespace that points to the redis instance
- Create `gitlab-redis` secret in `gitlab` namespace with the key `password` that contains the password to the redis instance

#### Object Storage

Object Storage works a bit differently as there are many kinds of file stores gitlab can be configured to use.

- Create the secret `gitlab-object-store` in the `gitlab` namespace with the following keys:
  - An example for in-cluster Minio can be found in this repository at the path `utils/pkg-deps/gitlab/minio/secret.yaml`
  - `connection`
    - This key refers to the configuration for the main gitlab service. The documentation for what goes in this key is located [here](https://docs.gitlab.com/16.0/ee/administration/object_storage.html#configure-the-connection-settings)
  - `registry`
    - This key refers to the configuration for the gitlab registry. The documentation for what goes in this key is located [here](https://docs.docker.com/registry/configuration/#storage)
  - `backups`
    - This key refers to the configuration for the gitlab-toolbox backup tool. It relies on a program called `s3cmd`. The documentation for what goes in this key is located [here](https://s3tools.org/kb/item14.htm)
- Below are the list of buckets that need to be created before starting GitLab:
  - gitlab-artifacts
  - gitlab-backups
  - gitlab-ci-secure-files
  - gitlab-dependency-proxy
  - git-lfs
  - gitlab-mr-diffs
  - gitlab-packages
  - gitlab-pages
  - gitlab-terraform-state
  - gitlab-uploads
  - registry
  - runner-cache
  - tmp

### GitLab-Runner Capability
The Gitlab-Runner Capability expects the pieces listed below to exist in the cluster before being deployed.

#### General

- Create `gitlab-runner-sandbox` namespace
- Label `gitlab-runner-sandbox` namespace with `istio-injection: enabled` & `zarf.dev/agent: ignore`
- Create an `rbac` file for the `gitlab-runner` service account

#### RBAC file

- The `rbac.yaml` should create a `ClusterRole` with the following values:
```
rules:
  - apiGroups: [""]
    resources: ["configmaps", "pods", "pods/attach", "secrets", "services"]
    verbs: ["get", "list", "watch", "create", "patch", "update", "delete"]
  - apiGroups: [""]
    resources: ["pods/exec"]
    verbs: ["create", "patch", "delete"]
```
- The `ClusterRole` should then be bound using a `RoleBinding` in the `gitlab-runner-sandbox` namespace to the service account that `gitlab-runner` uses
example:
```
kind: RoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: gitlab-runner-sandbox
  namespace: gitlab-runner-sandbox
subjects:
- kind: ServiceAccount
  name: default
  namespace: gitlab-runner
roleRef:
  kind: ClusterRole
  name: gitlab-runner-sandbox
```

### SonarQube Capability
The SonarQube Capability expects the database listed below to exist in the cluster before being deployed.

#### General

- Create `sonarqube` namespace
- Label `sonarqube` namespace with `istio-injection: enabled`

#### Database

- A Postgres database is running on port `5432` and accessible to the cluster
- This database can be logged into via the username `sonarqube`
- This database instance has a psql database created called `sonarqube-uds-software-factory`
- The `sonarqube` user has read/write access to `sonarqube-uds-software-factory`
- Create `sonarqube-postgres` service in `sonarqube` namespace that points to the psql database
- Create `sonarqube-postgres` secret in `sonarqube` namespace with the key `password` that contains the password to the `sonarqube` user for the psql database

### More capabilities are under construction
