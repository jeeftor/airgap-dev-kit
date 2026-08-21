// airgap is the offline kit lifecycle command.
package main

import (
	"fmt"
	"os"

	"github.com/jeeftor/airgap-dev-kit/internal/cli"
)

var (
	version = "dev"
	commit  = "none"
)

func main() {
	if err := cli.New(version, commit).Execute(); err != nil {
		fmt.Fprintf(os.Stderr, "airgap: %v\n", err)
		os.Exit(1)
	}
}
