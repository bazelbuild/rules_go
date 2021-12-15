package main

import (
  "fmt"
  "os"
)

func main() {
  fmt.Println("STABLE_STAMP " + os.Args[1])
  fmt.Println("VOLATILE_STAMP " + os.Args[2])

  os.Exit(0)
}
