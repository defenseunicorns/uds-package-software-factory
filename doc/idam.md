# Configuring IDAM

Out of the box the bundle comes with a demo/example realm and each package is configured to use said realm. This is not sufficient for production and needs to be changed to meet security requirements.

## GitLab

Configuring IDAM for GitLab is done via a few package variables and a json file. Below is an example `uds-config.yaml` that configures IDAM differently. There are more package variables for the GitLab capability documented in [it's repo](https://github.com/defenseunicorns/uds-capability-gitlab/blob/main/docs/idam.md).

The below config assumes that you have a custom realm file present called `custom-realm-saml.json` and a custom gitlab omniauth file called `gitlab-sso-saml.json` present. These must be in the directory you run `uds deploy` from.

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

## Sonarqube

Configuring IDAM for SonarQube is done solely via package variables. Below is an example `uds-config.yaml` that configures sonarqube for IDAM. SonarQube is configured by default to use the built in baby-yoda realm. There are more variables for the SonarQube capability documented in [it's repo](https://github.com/defenseunicorns/uds-capability-sonarqube/blob/main/docs/idam.md).

The `software-factory-idam-sonarqube` package retrieves the `SONARQUBE_IDAM_SAML_CERT` directly from the keycloak endpoint as an example of how to do so.

```yaml
bundle:
  deploy:
    zarf-packages:
      sonarqube:
        set:
          # Enable SSO for SonarQube
          SONARQUBE_IDAM_ENABLED: "true"
          # The client id created in IDAM for SonarQube
          SONARQUBE_IDAM_CLIENT_ID: "some_client_id"
          # The displayed name of sso on the SonarQube login page
          SONARQUBE_IDAM_PROVIDER_NAME: example-sso
          # The realm endpoint to auth against
          SONARQUBE_IDAM_REALM_URL: https://keycloak.exmaple.com/auth/realms/exampleRealm
          # The SAML attribute to parse login from
          SONARQUBE_IDAM_ATTR_LOGIN: login_name_attribute
          # The SAML attribute to parse account name from
          SONARQUBE_IDAM_ATTR_NAME: account_name_attribute
          # The SAML attribute to parse email from
          SONARQUBE_IDAM_PROVIDER_EMAIL: account_email_attribute
```
