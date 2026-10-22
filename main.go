// Copyright (c) HashiCorp, Inc.
// SPDX-License-Identifier: MPL-2.0

package main

import (
	"flag"
	"log"

	"github.com/hashicorp/terraform-plugin-framework/providerserver"
	"github.com/hashicorp/terraform-plugin-go/tfprotov6/tf6server"

	"terraform-provider-hashicups/internal/provider"
)

var (
	// version is set by the linker at build time; "dev" otherwise.
	version string = "dev"
)

func main() {
	var debug bool

	flag.BoolVar(&debug, "debug", false, "set to true to run the provider with support for debuggers like delve")
	flag.Parse()
	var serveOpts []tf6server.ServeOpt
	if debug {
		serveOpts = append(serveOpts, tf6server.WithManagedDebug())
	}
	err := tf6server.Serve(
		"hashicorp.com/edu/hashicups",
		providerserver.NewProtocol6(provider.New(version)()),
		serveOpts...,
	)
	if err != nil {
		log.Fatal(err)
	}
}
