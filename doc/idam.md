# Configuring IDAM

Out of the box the bundle comes with a demo/example realm and each package is configured to use said realm. This is not sufficient for production and needs to be changed to meet security requirements.

## GitLab

Configuring IDAM for GitLab is done via a few package variables and a json file. Below is an example `uds-config.yaml` that configures IDAM differently. There are more package variables for the GitLab capability documented in [it's repo](https://github.com/defenseunicorns/uds-capability-gitlab/blob/main/docs/idam.md).

The below config assumes that you have a custom realm file present called `custom-realm-saml.json` and a custom gitlab omniauth file called `gitlab-sso-saml.json` present. These must be in the directory you run `uds bundle deploy` from.

```yaml
bundle:
  deploy:
    zarf-packages:
      software-factory-idam-gitlab:
        set:
          # Change the file name to load the omniauth config from
          GITLAB_SSO_JSON: gitlab-sso-saml.json
      uds-idam:
        set:
          # Change the file name to import the keycloak realm from
          REALM_IMPORT_FILE: custom-realm-saml.json
      gitlab:
        set:
          # Change the allowed sso to match whats in `gitlab-sso-saml.json`
          IDAM_ALLOWED_SSOS: "['saml']"
```
