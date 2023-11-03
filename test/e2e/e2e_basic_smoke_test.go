package test_test

import (
	"testing"

	"github.com/defenseunicorns/uds-package-software-factory/test/e2e/types"
	"github.com/defenseunicorns/uds-package-software-factory/test/e2e/utils"
	teststructure "github.com/gruntwork-io/terratest/modules/test-structure"
	"github.com/stretchr/testify/require"
)

// TestAllServicesRunning waits until all services report that they are ready.
func TestAllServicesRunning(t *testing.T) { //nolint:funlen
	// BOILERPLATE, EXPECTED TO BE PRESENT AT THE BEGINNING OF EVERY TEST FUNCTION

	t.Parallel()
	platform := types.NewTestPlatform(t)
	defer platform.Teardown()
	utils.SetupTestPlatform(t, platform)
	// The repo has now been downloaded to /root/app and the software factory package deployment has been initiated.
	teststructure.RunTestStage(platform.T, "TEST", func() {
		// END BOILERPLATE

		// TEST CODE STARTS HERE.

		// Just make sure we can hit the cluster
		output, err := platform.RunSSHCommandAsSudo(`kubectl get nodes`)
		require.NoError(t, err, output)

		// Wait for the GitLab Webservice Deployment to exist.
		output, err = platform.RunSSHCommandAsSudo(`timeout 1200 bash -c "while ! kubectl get deployment gitlab-webservice-default -n gitlab; do sleep 5; done"`)
		require.NoError(t, err, output)

		// Wait for the GitLab Webservice Deployment to report that it is ready
		output, err = platform.RunSSHCommandAsSudo(`kubectl rollout status deployment/gitlab-webservice-default -n gitlab --watch --timeout=1200s`)
		require.NoError(t, err, output)

		// Ensure that the services do not accept discontinued TLS versions. If they reject TLSv1.1 it is assumed that they also reject anything below TLSv1.1.
		// Ensure that GitLab does not accept TLSv1.1
		output, err = platform.RunSSHCommandAsSudo(`sslscan gitlab.bigbang.dev | grep "TLSv1.1" | grep "disabled"`)
		require.NoError(t, err, output)

		// Setup DNS records for cluster services
		output, err = platform.RunSSHCommandAsSudo(`cd ~/app && utils/metallb/dns.sh && utils/metallb/hosts-write.sh`)
		require.NoError(t, err, output)

		// Ensure that GitLab is available outside of the cluster.
		output, err = platform.RunSSHCommandAsSudo(`timeout 1200 bash -c "while ! curl -L -s --fail --show-error https://gitlab.bigbang.dev/-/health > /dev/null; do sleep 5; done"`)
		require.NoError(t, err, output)

		// Wait for the GitLab Runner Deployment to exist.
		output, err = platform.RunSSHCommandAsSudo(`timeout 1200 bash -c "while ! kubectl get deployment gitlab-runner -n gitlab-runner; do sleep 5; done"`)
		require.NoError(t, err, output)

		// Wait for the GitLab Runner Deployment to report that it is ready
		output, err = platform.RunSSHCommandAsSudo(`kubectl rollout status deployment/gitlab-runner -n gitlab-runner --watch --timeout=1200s`)
		require.NoError(t, err, output)

		// Wait for the Sonarqube Statefulset to exist.
		output, err = platform.RunSSHCommandAsSudo(`timeout 1200 bash -c "while ! kubectl get statefulset sonarqube-sonarqube -n sonarqube; do sleep 5; done"`)
		require.NoError(t, err, output)

		// Wait for the Sonarqube Statefulset to report that it is ready
		output, err = platform.RunSSHCommandAsSudo(`kubectl rollout status statefulset/sonarqube-sonarqube -n sonarqube --watch --timeout=1200s`)
		require.NoError(t, err, output)

		// Ensure that the services do not accept discontinued TLS versions. If they reject TLSv1.1 it is assumed that they also reject anything below TLSv1.1.
		// Ensure that Sonarqube does not accept TLSv1.1
		output, err = platform.RunSSHCommandAsSudo(`sslscan sonarqube.bigbang.dev | grep "TLSv1.1" | grep "disabled"`)
		require.NoError(t, err, output)

		// Setup DNS records for cluster services
		output, err = platform.RunSSHCommandAsSudo(`cd ~/app && utils/metallb/dns.sh && utils/metallb/hosts-write.sh`)
		require.NoError(t, err, output)

		// Ensure that Sonarqube is available outside of the cluster.
		output, err = platform.RunSSHCommandAsSudo(`timeout 1200 bash -c "while ! curl -L -s --fail --show-error https://sonarqube.bigbang.dev/login > /dev/null; do sleep 5; done"`)
		require.NoError(t, err, output)

		// Wait for the jira statefulset to exist.
		output, err = platform.RunSSHCommandAsSudo(`timeout 1200 bash -c "while ! kubectl get statefulset jira -n jira; do sleep 5; done"`)
		require.NoError(t, err, output)

		// Wait for the jira statefulset to report that it is ready
		output, err = platform.RunSSHCommandAsSudo(`kubectl rollout status statefulset/jira -n jira --watch --timeout=1200s`)
		require.NoError(t, err, output)

		// Ensure that the services do not accept discontinued TLS versions. If they reject TLSv1.1 it is assumed that they also reject anything below TLSv1.1.
		// Ensure that jira does not accept TLSv1.1
		output, err = platform.RunSSHCommandAsSudo(`sslscan jira.bigbang.dev | grep "TLSv1.1" | grep "disabled"`)
		require.NoError(t, err, output)

		// Setup DNS records for cluster services
		output, err = platform.RunSSHCommandAsSudo(`cd ~/app && utils/metallb/dns.sh && utils/metallb/hosts-write.sh`)
		require.NoError(t, err, output)

		// Ensure that jira is available outside of the cluster.
		output, err = platform.RunSSHCommandAsSudo(`timeout 1200 bash -c "while ! curl -L -s --fail --show-error https://jira.bigbang.dev/status > /dev/null; do sleep 5; done"`)
		require.NoError(t, err, output)

		// Wait for the confluence statefulset to exist.
		output, err = platform.RunSSHCommandAsSudo(`timeout 1200 bash -c "while ! kubectl get statefulset confluence -n confluence; do sleep 5; done"`)
		require.NoError(t, err, output)

		// Wait for the confluence statefulset to report that it is ready
		output, err = platform.RunSSHCommandAsSudo(`kubectl rollout status statefulset/confluence -n confluence --watch --timeout=1200s`)
		require.NoError(t, err, output)

		// Ensure that the services do not accept discontinued TLS versions. If they reject TLSv1.1 it is assumed that they also reject anything below TLSv1.1.
		// Ensure that confluence does not accept TLSv1.1
		output, err = platform.RunSSHCommandAsSudo(`sslscan confluence.bigbang.dev | grep "TLSv1.1" | grep "disabled"`)
		require.NoError(t, err, output)

		// Setup DNS records for cluster services
		output, err = platform.RunSSHCommandAsSudo(`cd ~/app && utils/metallb/dns.sh && utils/metallb/hosts-write.sh`)
		require.NoError(t, err, output)

		// Ensure that confluence is available outside of the cluster.
		output, err = platform.RunSSHCommandAsSudo(`timeout 1200 bash -c "while ! curl -L -s --fail --show-error https://confluence.bigbang.dev/status > /dev/null; do sleep 5; done"`)
		require.NoError(t, err, output)

		// Wait for the mattermost-operator Deployment to exist.
		output, err = platform.RunSSHCommandAsSudo(`timeout 1200 bash -c "while ! kubectl get deployment mattermost-operator -n mattermost-operator; do sleep 5; done"`)
		require.NoError(t, err, output)

		// Wait for the mattermost-operator Deployment to report that it is ready
		output, err = platform.RunSSHCommandAsSudo(`kubectl rollout status deployment/mattermost-operator -n mattermost-operator --watch --timeout=1200s`)
		require.NoError(t, err, output)

		// Wait for the mattermost Deployment to exist.
		output, err = platform.RunSSHCommandAsSudo(`timeout 1200 bash -c "while ! kubectl get deployment mattermost -n mattermost; do sleep 5; done"`)
		require.NoError(t, err, output)

		// Setup DNS records for cluster services
		output, err = platform.RunSSHCommandAsSudo(`cd ~/app && utils/metallb/dns.sh && utils/metallb/hosts-write.sh`)
		require.NoError(t, err, output)

		// Ensure that Mattermost does not accept TLSv1.1
		output, err = platform.RunSSHCommandAsSudo(`sslscan chat.bigbang.dev | grep "TLSv1.1" | grep "disabled"`)
		require.NoError(t, err, output)

		// Ensure that Mattermost is available outside of the cluster.
		output, err = platform.RunSSHCommandAsSudo(`timeout 1200 bash -c "while ! curl -L -s --fail --show-error https://chat.bigbang.dev/login > /dev/null; do sleep 5; done"`)
		require.NoError(t, err, output)

		// Wait for the nexus Deployment to exist.
		output, err = platform.RunSSHCommandAsSudo(`timeout 1200 bash -c "while ! kubectl get deployment nexus-nexus-repository-manager -n nexus; do sleep 5; done"`)
		require.NoError(t, err, output)

		// Wait for the nexus Deployment to report that it is ready
		output, err = platform.RunSSHCommandAsSudo(`kubectl rollout status deployment/nexus-nexus-repository-manager -n nexus --watch --timeout=1200s`)
		require.NoError(t, err, output)

		// Ensure that the services do not accept discontinued TLS versions. If they reject TLSv1.1 it is assumed that they also reject anything below TLSv1.1.
		// Ensure that nexus does not accept TLSv1.1
		output, err = platform.RunSSHCommandAsSudo(`sslscan nexus.bigbang.dev | grep "TLSv1.1" | grep "disabled"`)
		require.NoError(t, err, output)

		// Setup DNS records for cluster services
		output, err = platform.RunSSHCommandAsSudo(`cd ~/app && utils/metallb/dns.sh && utils/metallb/hosts-write.sh`)
		require.NoError(t, err, output)

		// Ensure that nexus is available outside of the cluster.
		output, err = platform.RunSSHCommandAsSudo(`timeout 1200 bash -c "while ! curl -L -s --fail --show-error https://nexus.bigbang.dev > /dev/null; do sleep 5; done"`)
		require.NoError(t, err, output)

	})
}
