# Bazel interaction library

This library provides a Go API for interfacing with Bazel.

## Sample usage:

Querying for all targets in the repo.

```go
query := "//..."
b := bazel.New()
res, err := b.Query(query)
if err != nil {
  fmt.Printf("Error running Bazel %s\n", err)
}
for _, line := range res {
  fmt.Printf("Result: %s", line)
}
```

See the godoc for bazel.Query for more information.

Building a target in the repo.

```go
target := "//path/to/your:target"
b := bazel.New()
err := b.Build(target)
if err != nil {
  fmt.Printf("Error running Bazel %s\n", err)
}
```
