load('//go/private:go_toolchain.bzl', 'external_linker', 'go_toolchain')

DEFAULT_VERSION = "1.9"

def _generate_toolchains():
  # The set of acceptable hosts for each of the go versions, this is essentially the
  # set of sdk's we know how to fetch
  versions = [
      struct(
          name = "host",
          sdk = "@go_host_sdk",
          hosts = ["darwin_amd64", "linux_386", "linux_amd64", "windows_386", "windows_amd64", "freebsd_386", "freebsd_amd64"],
      ),
      struct(
          name = "1.9",
          hosts = ["darwin_amd64", "linux_386", "linux_amd64", "windows_386", "windows_amd64", "freebsd_386", "freebsd_amd64"],
      ),
      struct(
          name = "1.8.3",
          hosts = ["darwin_amd64", "linux_386", "linux_amd64", "windows_386", "windows_amd64", "freebsd_386", "freebsd_amd64"],
      ),
      struct(
          name = "1.8.2",
          hosts = ["darwin_amd64", "linux_amd64"],
      ),
      struct(
          name = "1.8.1",
          hosts = ["darwin_amd64", "linux_amd64"],
      ),
      struct(
          name = "1.8",
          hosts = ["darwin_amd64", "linux_amd64"],
      ),
      struct(
          name = "1.7.6",
          hosts = ["darwin_amd64", "linux_386", "linux_amd64", "windows_386", "windows_amd64", "freebsd_386", "freebsd_amd64"]
      ),
      struct(
          name = "1.7.5",
          hosts = ["darwin_amd64", "linux_amd64"],
      ),
  ]

  # The set of allowed cross compilations
  cross_targets = {
      "linux_amd64": ["windows_amd64"],
      "darwin_amd64": ["linux_amd64"],
  }

  # Use all the above information to generate all the possible toolchains we might support
  toolchains = []
  for version in versions:
    semver = version.name.split(".", 3)
    name = "_".join(semver)
    full_name = version.name
    if len(semver) == 2:
        semver += ["0"]
        full_name += ".0"
    version_constraints = [":go"+".".join(semver[:index+1]) for index, _ in  enumerate(semver)]
    for host in version.hosts:
      if hasattr(version, "sdk"):
        distribution = version.sdk
      else:
        distribution = "@go{}_{}".format(name, host)
      for target in [host] + cross_targets.get(host, []):
        toolchain_name = "{}_{}".format(full_name, host)
        if host != target:
          toolchain_name += "_cross_" + target
        # Add the primary toolchain
        toolchains.append(dict(
            name = toolchain_name,
            host = host,
            target = target,
            sdk = distribution[1:], # We have to strip off the @
            version_constraints = version_constraints,
            link_flags = [],
            cgo_link_flags = [],
        ))
        # TODO: remove default toolchains when default constraint values arrive
        toolchains.append(dict(
            name = "default-"+toolchain_name,
            match_version = version.name,
            host = host,
            target = target,
            sdk = distribution[1:], # We have to strip off the @
            version_constraints = [],
            link_flags = [],
            cgo_link_flags = [],
        ))
  # Now we go through the generated toolchains, adding exceptions, and removing invalid combinations.
  for toolchain in toolchains:
    if "darwin" in toolchain["host"]:
      # workaround for a bug in ld(1) on Mac OS X.
      # http://lists.apple.com/archives/Darwin-dev/2006/Sep/msg00084.html
      # TODO(yugui) Remove this workaround once rules_go stops supporting XCode 7.2
      # or earlier.
      toolchain["link_flags"] += ["-s"]
      toolchain["cgo_link_flags"] += ["-shared", "-Wl,-all_load"]
    if "linux" in toolchain["host"]:
      toolchain["cgo_link_flags"] += ["-Wl,-whole-archive"]

  return toolchains

_toolchains = _generate_toolchains()
_label_prefix = "@io_bazel_rules_go//go/toolchain:"

def go_register_toolchains(go_version=DEFAULT_VERSION):
  # Use the final dictionaries to register all the toolchains
  for toolchain in _toolchains:
    if "match_version" in toolchain and toolchain["match_version"] != go_version:
      continue
    name = _label_prefix + toolchain["name"]
    native.register_toolchains(name)
    if toolchain["host"] == toolchain["target"]:
      name = name + "-bootstrap"
      native.register_toolchains(name)

def declare_toolchains():
  external_linker()
  # Use the final dictionaries to create all the toolchains
  for toolchain in _toolchains:
    go_toolchain(
        # Required fields
        name = toolchain["name"],
        sdk = toolchain["sdk"],
        host = toolchain["host"],
        target = toolchain["target"],
        # Optional fields
        link_flags = toolchain["link_flags"],
        cgo_link_flags = toolchain["cgo_link_flags"],
        constraints = toolchain["version_constraints"],
    )
