package rules

import (
	"github.com/bazelbuild/rules_go/go/tools/gazelle/config"
)

// vendoredResolver resolves external packages as packages in vendor/.
type vendoredResolver struct {
	prefix string
}

var _ labelResolver = (*vendoredResolver)(nil)

func newVendoredResolver(c *config.Config) *vendoredResolver {
	return &vendoredResolver{prefix: c.VendorPrefix}
}

func (v vendoredResolver) resolve(importpath, dir string) (label, error) {
	return label{
		pkg:  v.prefix + importpath,
		name: defaultLibName,
	}, nil
}
