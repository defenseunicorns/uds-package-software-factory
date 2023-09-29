# UDS Software Factory

:construction: **This project is still early in its development.**

This is a bundle created using [uds-cli](https://github.com/defenseunicorns/uds-cli). uds-cli is a tool to declaratively orchestrate zarf packages by combining them into a bundle.

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

### UDS-CLI

- Install the release of [uds-cli](https://github.com/defenseunicorns/uds-cli/releases) that matches the version in the [makefile](https://github.com/defenseunicorns/uds-package-software-factory/blob/main/Makefile#L4).

### Kubernetes Cluster

- 1.26
- Compute power that is comparable to the **[m6id.8xlarge](https://aws.amazon.com/ec2/instance-types/#:~:text=Up%20to%2010-,m6id.8xlarge,-32)** AWS instance type used in our E2E tests.

## Documentation

[Identity and Access Management Configuration](doc/idam.md)

## Quick Start Guide

- Ensure the machine you are using has a valid kubecontext and has access to a sufficiently large cluster
- Ensure uds-cli is present on your machine by running `uds version` and verify it matches the version in the [makefile](https://github.com/defenseunicorns/uds-package-software-factory/blob/main/Makefile#L4)
- Run `uds bundle deploy oci://ghcr.io/defenseunicorns/uds-package/software-factory-demo:<swf-version> --confirm` and replace `<swf-version>` with the version of [SWF](https://github.com/defenseunicorns/uds-package-software-factory/pkgs/container/uds-package%2Fsoftware-factory-demo) you need
