# Defense Unicorns Software Factory

## Prerequisites

### GitLab

- `gitlab` namespace exists
- `gitlab-postgres` secret created with `password` key that contains password to postgres database
- `gitlab-uds-software-factory` database created in postgres database
- `gitlab` user created in postgres database
- `gitlab` user given write access to `gitlab-uds-software-factory` database in postgres
- `gitlab-postgres` service exists in `gitlab` namespace that points to the postgres database url