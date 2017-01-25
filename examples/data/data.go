package data

import (
	"io/ioutil"
)

func readFile() ([]byte, error) {
	return ioutil.ReadFile("data.txt")
}
