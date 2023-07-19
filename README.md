# Defense Unicorns Software Factory

## Prerequisites

### GitLab

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