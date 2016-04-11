// Command extract_package is a helper program that extracts a package name
// from a golang source file.
package main

import (
	"fmt"
	"go/parser"
	"go/token"
	"log"
	"os"
)

func extract(fname string) (string, error) {
	fset := token.NewFileSet()
	f, err := parser.ParseFile(fset, fname, nil, parser.PackageClauseOnly)
	if err != nil {
		return "", err
	}
	return f.Name.String(), nil
}

func main() {
	args := os.Args
	if len(args) != 2 {
		log.Fatal("Usage: extract_package GO_FILE")
	}
	name, err := extract(args[1])
	if err != nil {
		log.Fatal(err)
	}
	fmt.Println(name)
}
