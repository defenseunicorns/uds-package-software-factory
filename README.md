# UDS Software Factory

:construction: **This project is still early in its development.**

This is the early stages of a UDS Bundle we call the UDS Software Factory. This UDS Bundle brings together a collection of necessary Zarf packages as well as UDS Capabilities and the development version of their dependency packages. The development dependency packages are only meant to satisfy the UDS Capability's dependencies for demonstration purposes. **This UDS Bundle is not intended for a production environment**.

## Zarf Packages and UDS Capabilities contained in this UDS Bundle

- [X] [Zarf Init Package](ghcr.io/defenseunicorns/packages/init)
- [X] [Defense Unicorns Big Bang Distro (DUBBD) for k3d](https://github.com/defenseunicorns/uds-package-dubbd)
- [X] [Gitlab](https://github.com/defenseunicorns/uds-capability-gitlab)
- [X] [Gitlab-Runner](https://github.com/defenseunicorns/uds-capability-gitlab-runner)
- [X] [SonarQube](https://github.com/defenseunicorns/uds-capability-sonarqube)
- [ ] More UDS Capabilities under construction

## Prerequisites

### Kubernetes Cluster

- 1.26
- Compute power that is comparable to the **[m6id.8xlarge](https://aws.amazon.com/ec2/instance-types/#:~:text=Up%20to%2010-,m6id.8xlarge,-32)** AWS instance type used in our E2E tests.

