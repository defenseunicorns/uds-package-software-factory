# 2. Mechanism for running automated tests

Date: 2023-07-05

## Status

Accepted

## Context

It is very important to have a mechanism for running automated tests, both locally and in CI.

It should be easy to run the tests locally and in CI. If they are difficult to run, then human nature will be to not run them as often as they should be.

There should be good environment parity between the tests that are run locally and the tests that run in CI. If there is poor environment parity, running tests locally will not be as useful for having a fast feedback loop because there will not be confidence that if the tests pass locally, they will pass in CI.

## Decision

1. We will use `make` to create an abstraction layer for running tests locally and in CI. Apart from potential deviations that become technically necessary, the mechanism for running tests both locally and in CI will be to run `make test`.
2. We will run the tests in a Docker container, both locally and in CI. This will ensure that the environment where the test is being run is the same in both places, and make it easy for new team members to get started with running tests quickly.
3. We will use [Build Harness](https://github.com/defenseunicorns/build-harness) as that Docker container, both locally and in CI. It is well maintained by Unicorns and is designed to suit the needs of this project.
4. We will adopt this exact same pattern in the underlying `uds-capability-*` repos. While the logic of what happens when `make test` is run will be different in each repo, the mechanism for running tests will be the same.

## Consequences

* We will have the ability to run tests both locally and in CI.
* We will not have to maintain separate mechanisms for running tests locally and in CI.
* It will be easy to run tests locally and in CI.
* It will be easy for new team members to get started with running tests locally since the only local dependencies are `make` and `docker`.
* We will have environment parity between tests that are run locally and those that are run in CI.
* The tests that are run in CI will likely be somewhat slower, since the Build Harness docker image is fairly large due to being a "general use" image that contains more tools than we really need for this particular project. 
