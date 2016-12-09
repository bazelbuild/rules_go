package rules

// vendoredResolver resolves external packages as packages in vendor/.
type vendoredResolver struct{}

func (v vendoredResolver) resolve(importpath, dir string) (label, error) {
	return label{
		pkg:  "vendor/" + importpath,
		name: defaultLibName,
	}, nil
}
