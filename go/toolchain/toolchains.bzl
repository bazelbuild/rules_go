load('//go/private:go_toolchain.bzl', 'external_linker', 'go_toolchain')

DEFAULT_VERSION = "1.9"

def _generate_toolchains():
  # The full set of allowed os and arch combinations for the go toolchain
  # This is the set of targets allowed, of which the set of hosts is a strict subset
  android_arm = struct(os="android", arch="arm")
  darwin_386 = struct(os="darwin", arch="386")
  darwin_amd64 = struct(os="darwin", arch="amd64")
  darwin_arm = struct(os="darwin", arch="arm")
  darwin_arm64 = struct(os="darwin", arch="arm64")
  dragonfly_amd64 = struct(os="dragonfly", arch="amd64")
  freebsd_386 = struct(os="freebsd", arch="386")
  freebsd_amd64 = struct(os="freebsd", arch="amd64")
  freebsd_arm = struct(os="freebsd", arch="arm")
  linux_386 = struct(os="linux", arch="386")
  linux_amd64 = struct(os="linux", arch="amd64")
  linux_arm = struct(os="linux", arch="arm")
  linux_arm64 = struct(os="linux", arch="arm64")
  linux_ppc64 = struct(os="linux", arch="ppc64")
  linux_ppc64le = struct(os="linux", arch="ppc64le")
  linux_mips = struct(os="linux", arch="mips")
  linux_mipsle = struct(os="linux", arch="mipsle")
  linux_mips64 = struct(os="linux", arch="mips64")
  linux_mips64le = struct(os="linux", arch="mips64le")
  netbsd_386 = struct(os="netbsd", arch="386")
  netbsd_amd64 = struct(os="netbsd", arch="amd64")
  netbsd_arm = struct(os="netbsd", arch="arm")
  openbsd_386 = struct(os="openbsd", arch="386")
  openbsd_amd64 = struct(os="openbsd", arch="amd64")
  openbsd_arm = struct(os="openbsd", arch="arm")
  plan9_386 = struct(os="plan9", arch="386")
  plan9_amd64 = struct(os="plan9", arch="amd64")
  solaris_amd64 = struct(os="solaris", arch="amd64")
  windows_386 = struct(os="windows", arch="386")
  windows_amd64 = struct(os="windows", arch="amd64")
  
  # The set of acceptable hosts for each of the go versions, this is essentially the
  # set of sdk's we know how to fetch
  versions = [
      struct(
          name = "host",
          sdk = "@go_host_sdk",
          hosts = [darwin_amd64, linux_386, linux_amd64, windows_386, windows_amd64, freebsd_386, freebsd_amd64],
      ),
      struct(
          name = "1.9",
          hosts = [darwin_amd64, linux_386, linux_amd64, windows_386, windows_amd64, freebsd_386, freebsd_amd64],
      ),
      struct(
          name = "1.8.3",
          hosts = [darwin_amd64, linux_386, linux_amd64, windows_386, windows_amd64, freebsd_386, freebsd_amd64],
      ),
      struct(
          name = "1.8.2",
          hosts = [darwin_amd64, linux_amd64],
      ),
      struct(
          name = "1.8.1",
          hosts = [darwin_amd64, linux_amd64],
      ),
      struct(
          name = "1.8",
          hosts = [darwin_amd64, linux_amd64],
      ),
      struct(
          name = "1.7.6",
          hosts = [darwin_amd64, linux_386, linux_amd64, windows_386, windows_amd64, freebsd_386, freebsd_amd64]
      ),
      struct(
          name = "1.7.5",
          hosts = [darwin_amd64, linux_amd64],
      ),
  ]
  
  # The set of allowed cross compilations
  cross_targets = {
      linux_amd64: [windows_amd64],
      darwin_amd64: [linux_amd64],
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
      "{}_{}_{}".format(name, host.os, host.arch)
      if hasattr(version, "sdk"):
        distribution = version.sdk
      else:
        distribution = "@go{}_{}_{}".format(name, host.os, host.arch)
      for target in [host] + cross_targets.get(host, []):
        toolchain_name = "{}_{}_{}".format(full_name, host.os, host.arch)
        is_cross = host != target
        if is_cross:
          toolchain_name += "_cross_" + target.os + "_" + target.arch
        base = dict(
            name = toolchain_name,
            impl = toolchain_name + "-impl",
            host = host,
            target = target,
            typ = "@io_bazel_rules_go//go:toolchain",
            sdk = distribution[1:], # We have to strip off the @
            is_cross = is_cross,
            exec_constraints = [":"+host.os, ":"+host.arch],
            target_constraints = [":"+target.os, ":"+target.arch],
            version_constraints = version_constraints,
            link_flags = [],
            cgo_link_flags = [],
            tags = ["manual"],
            bootstrap = False,
        )
        bootstrap = _bootstrap(base)
        toolchains += [base, bootstrap]
        toolchains += [_default(base, version.name), _default(bootstrap, version.name)]

  # Now we go through the generated toolchains, adding exceptions, and removing invalid combinations.
  for toolchain in toolchains:
    if toolchain["host"].os == "darwin":
      # workaround for a bug in ld(1) on Mac OS X.
      # http://lists.apple.com/archives/Darwin-dev/2006/Sep/msg00084.html
      # TODO(yugui) Remove this workaround once rules_go stops supporting XCode 7.2
      # or earlier.
      toolchain["link_flags"] += ["-s"]
      toolchain["cgo_link_flags"] += ["-shared", "-Wl,-all_load"]
    if toolchain["host"].os == "linux":
      toolchain["cgo_link_flags"] += ["-Wl,-whole-archive"]

  return toolchains

def _bootstrap(base):
  bootstrap = dict(base)
  bootstrap["name"] = "bootstrap-" + base["name"]
  bootstrap["impl"] = "bootstrap-" + base["impl"]
  bootstrap["typ"] = "@io_bazel_rules_go//go:bootstrap_toolchain"
  bootstrap["bootstrap"] = True
  return bootstrap

def _default(base, version):
  default = dict(base)
  default["name"] = "default-" + base["name"]
  default["default"] = True
  default["version_constraints"] = []
  default["match_version"] = version
  return default

_toolchains = _generate_toolchains()
_label_prefix = "@io_bazel_rules_go//go/toolchain:"

def go_register_toolchains(go_version=DEFAULT_VERSION):
  # Use the final dictionaries to register all the toolchains
  for toolchain in _toolchains:
    if "match_version" in toolchain and toolchain["match_version"] != go_version:
      continue
    native.register_toolchains(_label_prefix + toolchain["name"])

def declare_toolchains():
  external_linker()
  # Use the final dictionaries to create all the toolchains
  for toolchain in _toolchains:
    if "default" not in toolchain:
      go_toolchain(
          name = toolchain["impl"],
          sdk = toolchain["sdk"],
          link_flags = toolchain["link_flags"],
          cgo_link_flags = toolchain["cgo_link_flags"],
          goos = toolchain["target"].os,
          goarch = toolchain["target"].arch,
          bootstrap = toolchain["bootstrap"],
          tags = ["manual"],
      )
    native.toolchain(
        name = toolchain["name"],
        toolchain_type = toolchain["typ"],
        exec_compatible_with = toolchain["exec_constraints"],
        target_compatible_with = toolchain["target_constraints"]+toolchain["version_constraints"],
        toolchain = _label_prefix + toolchain["impl"],
    )
