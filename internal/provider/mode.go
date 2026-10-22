package provider

// FeatureMode selects how the provider treats attributes that exist in the
// schema so a module can name them before the feature behind them is
// implemented.
//
//   - "3x" (default): new attributes are implemented.
//   - "2x": models the final 2.x release, where a new attribute is present in
//     the schema, so a module configuration that names it validates, but a
//     value is rejected at validate and plan time.
//
// Set it at build time, for example:
//
//	go build -ldflags "-X terraform-provider-hashicups/internal/provider.FeatureMode=2x"
var FeatureMode = "3x"
