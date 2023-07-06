# 3. Tools used to run tests

Date: 2023-07-06

## Status

Accepted

## Context

We need to decide what tools we will use to run tests.

We should use tools that are already commonly used in our organization.

Per ADR #0002, the tool(s) used will be identical regardless of whether the tests are run locally or in CI.

Per ADR #0002, the tool(s) used will be used inside the Build Harness container.

## Decision

1. For all tests, we will use Golang tests, such that the tests are run inside Build Harness with `go test` (wrapped by `docker run`, wrapped by `make test`). Golang tests are easy to run inside Build Harness, both locally and in CI.
2. When tests require infrastructure deployments, we will use [Terratest](https://github.com/gruntwork-io/terratest).
3. For any test that is too large to run on a developer's laptop or a GitHub CI runner (whichever is smaller), or requires cloud resources, we will use Terratest to create a beefy EC2 instance in AWS (or whatever other infra is needed), run the test on that instance/infra, and then destroy the instance/infra. This will all happen as part of the test, with the only additional requirement if the test is being run locally being AWS creds available as environment variables.

## Consequences

- The tool(s) used will be tools that are already commonly used in our organization.
- The tool(s) used will not change between local and CI.
- We will not be constrained by machine size when running tests locally or in CI.
- Test infrastructure will be fully ephemeral.
