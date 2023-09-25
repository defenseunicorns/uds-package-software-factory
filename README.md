# UDS Software Factory

:construction: **This project is still early in its development.**

This is the early stages of a UDS Bundle we call the UDS Software Factory. This UDS Bundle brings together a collection of necessary Zarf packages as well as UDS Capabilities and the development version of their dependency packages. The development dependency packages are only meant to satisfy the UDS Capability's dependencies for demonstration purposes. **This UDS Bundle is not intended for a production environment**.

## Known Issues

- [Zarf](https://zarf.dev/) must be installed and on your path for the bundle to deploy successfully. This is due to how actions that call `./zarf` work currently. Issue is [here](https://github.com/defenseunicorns/uds-cli/issues/45)

## Zarf Packages and UDS Capabilities contained in this UDS Bundle

| Capability | Maturity |
|------------|----------|
| [Zarf Init Package](ghcr.io/defenseunicorns/packages/init) | Beta |
| [Defense Unicorns Big Bang Distro](https://github.com/defenseunicorns/uds-package-dubbd) | Beta |
| [Gitlab](https://github.com/defenseunicorns/uds-capability-gitlab) | Alpha |
| [Gitlab-Runner](https://github.com/defenseunicorns/uds-capability-gitlab-runner) | Alpha |
| [SonarQube](https://github.com/defenseunicorns/uds-capability-sonarqube) | Alpha |

## Prerequisites

### Kubernetes Cluster

- 1.26
- Compute power that is comparable to the **[m6id.8xlarge](https://aws.amazon.com/ec2/instance-types/#:~:text=Up%20to%2010-,m6id.8xlarge,-32)** AWS instance type used in our E2E tests.

## Documentation
change
[Identity and Access Management Configuration](doc/idam.md)
