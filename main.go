// airgap is the offline kit lifecycle command.
package main

import (
	"os"

	"github.com/jeeftor/airgap-dev-kit/internal/cli"
)

var (
	version = "dev"
	commit  = "none"
)

func main() {
	if err := cli.New(version, commit).Execute(); err != nil {
		os.Exit(1)
	}
}
