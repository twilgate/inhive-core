package main

import (
	"os"

	"github.com/TwilgateLabs/inhive-core/cmd"
)

func main() {
	cmd.ParseCli(os.Args[1:])
}
