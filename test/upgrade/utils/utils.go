// Package utils contains helper functions for the upgrade tests
package utils

import (
	"fmt"
	"os"
	"testing"
	"time"

	customteststructure "github.com/defenseunicorns/uds-package-software-factory/test/upgrade/terratest/teststructure"
	"github.com/defenseunicorns/uds-package-software-factory/test/upgrade/types"
	"github.com/gruntwork-io/terratest/modules/aws"
	"github.com/gruntwork-io/terratest/modules/random"
	"github.com/gruntwork-io/terratest/modules/retry"
	"github.com/gruntwork-io/terratest/modules/terraform"
	teststructure "github.com/gruntwork-io/terratest/modules/test-structure"
	"github.com/stretchr/testify/require"
)

// SetupTestPlatform uses Terratest to create an EC2 instance. It then (on the new instance) downloads
// the repo specified by env var REPO_URL at the ref specified by env var GIT_BRANCH, installs Zarf,
// logs into registry1.dso.mil using env vars REGISTRY1_USERNAME and REGISTRY1_PASSWORD, builds all
// the packages, and deploys the init package, the flux package, and the software factory package.
// It is finished when the zarf command returns from deploying the software factory package. It is
// the responsibility of the test being run to do the appropriate waiting for services to come up.
func SetupTestPlatform(t *testing.T, platform *types.TestPlatform) { //nolint:funlen
	t.Helper()
	repoURL, err := getEnvVar("REPO_URL")
	require.NoError(t, err)
	gitBranch, err := getEnvVar("GIT_BRANCH")
	require.NoError(t, err)
	awsRegion, err := getAwsRegion()
	require.NoError(t, err)
	registry1Username, err := getEnvVar("REGISTRY1_USERNAME")
	require.NoError(t, err)
	registry1Password, err := getEnvVar("REGISTRY1_PASSWORD")
	require.NoError(t, err)
	ghcrUsername, err := getEnvVar("GHCR_USERNAME")
	require.NoError(t, err)
	ghcrPassword, err := getEnvVar("GHCR_PASSWORD")
	require.NoError(t, err)
	latestversion, err := getEnvVar("LATEST_VERSION")
	require.NoError(t, err)
	awsAvailabilityZone := getAwsAvailabilityZone(awsRegion)
	namespace := "uds-swf"
	stage := "terratest"
	name := fmt.Sprintf("upgrade-%s", random.UniqueId())
	instanceType := "m6i.8xlarge"
	teststructure.RunTestStage(t, "SETUP", func() {
		keyPairName := fmt.Sprintf("%s-%s-%s", namespace, stage, name)
		keyPair := aws.CreateAndImportEC2KeyPair(t, awsRegion, keyPairName)
		terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
			TerraformDir: platform.TestFolder,
			Vars: map[string]interface{}{
				"aws_region":            awsRegion,
				"aws_availability_zone": awsAvailabilityZone,
				"namespace":             namespace,
				"stage":                 stage,
				"name":                  name,
				"key_pair_name":         keyPairName,
				"instance_type":         instanceType,
			},
		})
		teststructure.SaveTerraformOptions(t, platform.TestFolder, terraformOptions)
		// Use a custom version of this function because the upstream version leaks the private SSH key in the pipeline logs
		customteststructure.SaveEc2KeyPair(t, platform.TestFolder, keyPair)
		terraform.InitAndApply(t, terraformOptions)

		// It can take a minute or so for the instance to boot up, so retry a few times
		err = waitForInstanceReady(t, platform, 5*time.Second, 15) //nolint:gomnd
		require.NoError(t, err)

		// Install Docker Dependencies
		output, err := platform.RunSSHCommandAsSudo(`apt install -y ca-certificates curl gnupg lsb-release`)
		require.NoError(t, err, output)

		// Add Docker GPG Key
		output, err = platform.RunSSHCommandAsSudo(`mkdir -m 0755 -p /etc/apt/keyrings && curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg`)
		require.NoError(t, err, output)

		// Setup Docker APT Repo
		output, err = platform.RunSSHCommandAsSudo(`echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null`)
		require.NoError(t, err, output)

		// Update APT repos including new docker repo
		output, err = platform.RunSSHCommandAsSudo(`apt update -y`)
		require.NoError(t, err, output)

		// Install Docker
		output, err = platform.RunSSHCommandAsSudo(`apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin`)
		require.NoError(t, err, output)

		// Download and install k3d
		output, err = platform.RunSSHCommandAsSudo(`curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash`)
		require.NoError(t, err, output)

		// Download kubectl binary
		output, err = platform.RunSSHCommandAsSudo(`curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"`)
		require.NoError(t, err, output)

		// Install kubectl
		output, err = platform.RunSSHCommandAsSudo(`install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl`)
		require.NoError(t, err, output)

		// Install dependencies. Doing it here since the instance user-data is being flaky, still saying things like make are not installed
		output, err = platform.RunSSHCommandAsSudo(`apt update && apt install -y jq git make wget sslscan && sysctl -w vm.max_map_count=262144`)
		require.NoError(t, err, output)

		// Clone the repo idempotently
		output, err = platform.RunSSHCommandAsSudo(fmt.Sprintf(`rm -rf ~/app && git clone --depth 1 %v --branch %v --single-branch ~/app`, repoURL, gitBranch))
		require.NoError(t, err, output)

		// Install Zarf
		output, err = platform.RunSSHCommandAsSudo(`cd ~/app && make build/zarf`)
		require.NoError(t, err, output)

		// Add the zarf binary to the path
		output, err = platform.RunSSHCommandAsSudo(`cd ~/app && cp build/zarf /usr/local/bin/zarf`)
		require.NoError(t, err, output)

		// Copy zarf-config.yaml to the build folder
		output, err = platform.RunSSHCommandAsSudo(`cd ~/app && cp test/upgrade/zarf-config.yaml build/zarf-config.yaml`)
		require.NoError(t, err, output)

		// Copy uds-config.yaml to the build folder
		output, err = platform.RunSSHCommandAsSudo(`cd ~/app && cp test/upgrade/uds-config.yaml build/uds-config.yaml`)
		require.NoError(t, err, output)

		// Log into registry1.dso.mil
		output, err = platform.RunSSHCommandAsSudo(fmt.Sprintf(`~/app/build/zarf tools registry login registry1.dso.mil -u %v -p %v`, registry1Username, registry1Password))
		require.NoError(t, err, output)

		// Log into ghcr.io
		output, err = platform.RunSSHCommandAsSudo(fmt.Sprintf(`~/app/build/zarf tools registry login ghcr.io -u %v -p %v`, ghcrUsername, ghcrPassword))
		require.NoError(t, err, output)

		// Build
		output, err = platform.RunSSHCommandAsSudo(`cd ~/app && make build/all`)
		require.NoError(t, err, output)

		// Cluster
		output, err = platform.RunSSHCommandAsSudo(`cd ~/app && make cluster/reset`)
		require.NoError(t, err, output)

		// Deploy current SWF version
		output, err = platform.RunSSHCommandAsSudo(fmt.Sprintf(`~/app/build/uds bundle deploy oci://ghcr.io/defenseunicorns/uds-package/software-factory-demo:%s --confirm --no-progress`, latestversion))
		require.NoError(t, err, output)

		// Upgrade to branch SWF version
		output, err = platform.RunSSHCommandAsSudo(`cd ~/app && make deploy`)
		require.NoError(t, err, output)

	})
}

// getAwsRegion returns the desired AWS region to use by first checking the env var AWS_REGION, then checking
// AWS_DEFAULT_REGION if AWS_REGION isn't set. If neither is set it returns an error.
func getAwsRegion() (string, error) {
	val, present := os.LookupEnv("AWS_REGION")
	if !present {
		val, present = os.LookupEnv("AWS_DEFAULT_REGION")
	}
	if !present {
		return "", fmt.Errorf("expected either AWS_REGION or AWS_DEFAULT_REGION env var to be set, but they were not")
	}

	fmt.Printf("Using AWS region: %v", val)

	return val, nil
}

// getAwsAvailabilityZone returns the desired AWS Availability Zone to use by first checking the env var AWS_AVAILABILITY_ZONE,
// We default to {awsRegion}b if env var is not specified.
func getAwsAvailabilityZone(awsRegion string) string {
	zoneLetter, present := os.LookupEnv("AWS_AVAILABILITY_ZONE")
	var zone string
	if !present {
		zone = fmt.Sprintf("%s%s", awsRegion, "c")
	} else {
		zone = fmt.Sprintf("%s%s", awsRegion, zoneLetter)
	}

	return zone
}

// getEnvVar gets an environment variable, returning an error if it isn't found.
func getEnvVar(varName string) (string, error) {
	val, present := os.LookupEnv(varName)
	if !present {
		return "", fmt.Errorf("expected env var %v not set", varName)
	}

	return val, nil
}

// waitForInstanceReady tries/retries a simple SSH command until it works successfully, meaning the server is ready to accept connections.
func waitForInstanceReady(t *testing.T, platform *types.TestPlatform, timeBetweenRetries time.Duration, maxRetries int) error {
	t.Helper()
	_, err := retry.DoWithRetryE(t, "Wait for the instance to be ready", maxRetries, timeBetweenRetries, func() (string, error) {
		_, err := platform.RunSSHCommandAsSudo("whoami")
		if err != nil {
			return "", fmt.Errorf("unknown error: %w", err)
		}

		return "", nil
	})
	if err != nil {
		return fmt.Errorf("error while waiting for instance to be ready: %w", err)
	}

	// Wait another 5 seconds because race conditions suck
	time.Sleep(5 * time.Second) //nolint:gomnd

	return nil
}
