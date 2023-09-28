// Package types contains the types that are used in the e2e tests
package types

import (
	"context"
	"errors"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"

	scp "github.com/bramvdbogaerde/go-scp"
	"github.com/bramvdbogaerde/go-scp/auth"
	"github.com/gruntwork-io/terratest/modules/aws"
	"github.com/gruntwork-io/terratest/modules/logger"
	"github.com/gruntwork-io/terratest/modules/ssh"
	"github.com/gruntwork-io/terratest/modules/terraform"
	teststructure "github.com/gruntwork-io/terratest/modules/test-structure"
	"github.com/stretchr/testify/require"
	goSsh "golang.org/x/crypto/ssh"
)

// TestPlatform is the test "state" that allows for helper functions such as deferring the teardown step.
type TestPlatform struct {
	T          *testing.T
	TestFolder string
}

// NewTestPlatform generates the test "state" object that allows for helper functions such as deferring the teardown step.
func NewTestPlatform(t *testing.T) *TestPlatform {
	t.Helper()
	testPlatform := new(TestPlatform)
	testPlatform.T = t
	tempFolder := teststructure.CopyTerraformFolderToTemp(t, "..", "tf/public-ec2-instance")
	testPlatform.TestFolder = tempFolder

	// Since Terraform is going to be run with that temp folder as the CWD, we also need our .tool-versions file to be
	// in that directory so that the right version of Terraform is being run there. I can neither confirm nor deny that
	// this took me 2 days to figure out...
	// Since we can't be sure what the working directory is, we are going to walk up one directory at a time until we
	// find a .tool-versions file and then copy it into the temp folder
	found := false
	filePath := ".tool-versions"
	for !found {
		//nolint:gocritic
		if _, err := os.Stat(filePath); err == nil {
			// The file exists
			found = true
		} else if errors.Is(err, os.ErrNotExist) {
			// The file does *not* exist. Add a "../" and try again
			filePath = fmt.Sprintf("../%v", filePath)
		} else {
			// Schrodinger: file may or may not exist. See err for details.
			// Therefore, do *NOT* use !os.IsNotExist(err) to test for file existence
			require.NoError(t, err)
		}
	}
	err := copyFile(filePath, fmt.Sprintf("%v/.tool-versions", testPlatform.TestFolder))
	require.NoError(t, err)

	return testPlatform
}

// RunSSHCommand provides a simple way to run a shell command on the server that is created using Terraform.
func (platform *TestPlatform) RunSSHCommand(command string) (string, error) {
	return platform.runSSHCommandWithOptionalSudo(command, false)
}

// RunSSHCommandAsSudo provides a simple way to run a shell command with sudo on the server that is created using Terraform.
func (platform *TestPlatform) RunSSHCommandAsSudo(command string) (string, error) {
	return platform.runSSHCommandWithOptionalSudo(command, true)
}

// CopyFileOverScp provides a way to copy large files over scp
func (platform *TestPlatform) CopyFileOverScp(src string, dest string, mode os.FileMode) error {
	terraformOptions := teststructure.LoadTerraformOptions(platform.T, platform.TestFolder)
	keyPair := teststructure.LoadEc2KeyPair(platform.T, platform.TestFolder)
	instanceIP := terraform.Output(platform.T, terraformOptions, "public_instance_ip")

	// Write private key to temp file
	os.WriteFile(platform.TestFolder+"/private_key", []byte(keyPair.KeyPair.PrivateKey), 0644)

	// Setup scp connection
	clientConfig, _ := auth.PrivateKey("ubuntu", platform.TestFolder+"/private_key", goSsh.InsecureIgnoreHostKey())
	client := scp.NewClient(instanceIP+":22", &clientConfig)

	logger.Default.Logf(platform.T, "Establishing ssh connection to %s", instanceIP)

	// Establish ssh connection
	err := client.Connect()
	if err != nil {
		return fmt.Errorf("unable to connect to remote host: %w", err)
	}

	logger.Default.Logf(platform.T, "Connection established to %s", instanceIP)

	logger.Default.Logf(platform.T, "Opening file to copy: %s", src)

	// Open file to copy
	srcFile, err := os.Open(src)
	if err != nil {
		return fmt.Errorf("unable to open src file: %w", err)
	}
	defer srcFile.Close()
	defer client.Close()

	logger.Default.Logf(platform.T, "File opened: %s", src)

	logger.Default.Logf(platform.T, "Copying file to remote host: %s", dest)

	// Copy file to remote host
	err = client.CopyFromFile(context.TODO(), *srcFile, dest, "0644")
	if err != nil {
		return fmt.Errorf("unable to copy file: %w", err)
	}

	logger.Default.Logf(platform.T, "File copied to remote host: %s", dest)

	return nil
}

func (platform *TestPlatform) runSSHCommandWithOptionalSudo(command string, asSudo bool) (string, error) {
	precommand := "bash -c"
	if asSudo {
		precommand = fmt.Sprintf(`sudo %v`, precommand)
	}
	terraformOptions := teststructure.LoadTerraformOptions(platform.T, platform.TestFolder)
	keyPair := teststructure.LoadEc2KeyPair(platform.T, platform.TestFolder)
	host := ssh.Host{
		Hostname:    terraform.Output(platform.T, terraformOptions, "public_instance_ip"),
		SshKeyPair:  keyPair.KeyPair,
		SshUserName: "ubuntu",
	}
	var origOutput string
	count := 0
	const teeSuffix = ` | tee -a /tmp/terratest-ssh.log`
	// Try up to 3 times to do the command, to avoid "i/o timeout" errors which are transient
attemptLoop:
	for count < 3 {
		count++
		errorChan := make(chan error)
		go func(output *string) {
			defer close(errorChan)
			stdout, err := ssh.CheckSshCommandE(platform.T, host, fmt.Sprintf(`%v '%v'`, precommand, command)+teeSuffix)
			*output = stdout
			errorChan <- err
		}(&origOutput)

		for {
			select {
			case err := <-errorChan:
				readTeeFile(platform.T, host)
				if err != nil {
					if strings.Contains(err.Error(), "i/o timeout") {
						// There was an error, but it was an i/o timeout, so wait a few seconds and try again
						logger.Default.Logf(platform.T, "i/o timeout error, trying again")
						time.Sleep(3 * time.Second)
						continue attemptLoop
					} else {
						return "nil", fmt.Errorf("ssh command failed: %w", err)
					}
				} else {
					return origOutput, nil
				}
			case <-time.After(10 * time.Second):
				readTeeFile(platform.T, host)
			}
		}
	}
	return origOutput, nil
}

// Teardown brings down the Terraform infrastructure that was created.
func (platform *TestPlatform) Teardown() {
	teststructure.RunTestStage(platform.T, "TEARDOWN", func() {
		keyPair := teststructure.LoadEc2KeyPair(platform.T, platform.TestFolder)
		terraformOptions := teststructure.LoadTerraformOptions(platform.T, platform.TestFolder)
		terraform.Destroy(platform.T, terraformOptions)
		aws.DeleteEC2KeyPair(platform.T, keyPair)
	})
}

func readTeeFile(t *testing.T, host ssh.Host) {
	output, err := ssh.CheckSshCommandE(t, host, `cat /tmp/terratest-ssh.log && printf "" > /tmp/terratest-ssh.log`)
	if err != nil {
		logger.Default.Logf(t, "error reading log file: %v", err)
	} else {
		logger.Default.Logf(t, output)
	}
}

// copyFile copies a file from src to dst. If src and dst files exist, and are
// the same, then return success. Otherwise, attempt to create a hard link
// between the two files. If that fails, copy the file contents from src to dst.
func copyFile(src string, dest string) error {
	sourceFileInfo, err := os.Stat(src)
	if err != nil {
		return fmt.Errorf("failed to stat file: %w", err)
	}
	if !sourceFileInfo.Mode().IsRegular() {
		// cannot copy non-regular files (e.g., directories,
		// symlinks, devices, etc.)
		return fmt.Errorf("non-regular source file %s (%q)", sourceFileInfo.Name(), sourceFileInfo.Mode().String())
	}
	destFileInfo, err := os.Stat(dest)
	if err != nil {
		if !os.IsNotExist(err) {
			return fmt.Errorf("unknown error: %w", err)
		}
	} else {
		if !(destFileInfo.Mode().IsRegular()) {
			return fmt.Errorf("non-regular destination file %s (%q)", destFileInfo.Name(), destFileInfo.Mode().String())
		}
		if os.SameFile(sourceFileInfo, destFileInfo) {
			return nil
		}
	}
	err = os.Link(src, dest)
	if err == nil {
		return nil
	}
	err = copyFileContents(src, dest)
	if err != nil {
		return err
	}

	return nil
}

// copyFileContents copies the contents of the file named src to the file named
// by dst. The file will be created if it does not already exist. If the
// destination file exists, all it's contents will be replaced by the contents
// of the source file.
func copyFileContents(src string, dest string) error {
	cleanSrc := filepath.Clean(src)
	cleanDst := filepath.Clean(dest)
	srcFile, err := os.Open(cleanSrc)
	if err != nil {
		return fmt.Errorf("unable to open src file: %w", err)
	}
	defer func(in *os.File) {
		_ = in.Close()
	}(srcFile)
	dstFile, err := os.Create(cleanDst)
	if err != nil {
		return fmt.Errorf("unable to create dest file: %w", err)
	}
	defer func() {
		cerr := dstFile.Close()
		if err == nil {
			err = cerr
		}
	}()
	if _, err = io.Copy(dstFile, srcFile); err != nil {
		return fmt.Errorf("unable to copy file: %w", err)
	}
	err = dstFile.Sync()

	return nil
}
