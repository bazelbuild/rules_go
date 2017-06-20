load('//go/private:go_toolchain.bzl', 'go_toolchain', 'platform', 'constraint_setting', 'constraint_value')
load('//go/private:go_tool_binary.bzl', 'go_bootstrap_toolchain')

def generate_toolchains():
  # Compatability declarations
  #TODO(toolchains): Swap as many as these as possible for values from @bazel_tools//platforms
  constraint_setting(name = "os")
  constraint_value(name = "android", setting = ":os")
  constraint_value(name = "dragonfly", setting = ":os")
  constraint_value(name = "freebsd", setting = ":os")
  constraint_value(name = "linux", setting = ":os") # @bazel_tools//platforms:linux
  constraint_value(name = "netbsd", setting = ":os")
  constraint_value(name = "openbsd", setting = ":os")
  constraint_value(name = "osx", setting = ":os") # @bazel_tools//platforms:osx
  constraint_value(name = "plan9", setting = ":os")
  constraint_value(name = "solaris", setting = ":os")
  constraint_value(name = "windows", setting = ":os") # @bazel_tools//platforms:windows
  
  constraint_setting(name = "processor")
  constraint_value(name = "x86_64", setting = ":processor") # @bazel_tools//platforms:x86_64
  constraint_value(name = "386", setting = ":processor") # @bazel_tools//platforms:386
  constraint_value(name = "arm", setting = ":processor")
  constraint_value(name = "arm64", setting = ":processor")
  constraint_value(name = "ppc64", setting = ":processor")
  constraint_value(name = "ppc64le", setting = ":processor")
  constraint_value(name = "mips", setting = ":processor")
  constraint_value(name = "mipsle", setting = ":processor")
  constraint_value(name = "mips64", setting = ":processor")
  constraint_value(name = "mips64le", setting = ":processor")
  
  # Version constraints
  constraint_setting(name = "go_version")
  constraint_setting(name = "go_minor_version")
  constraint_setting(name = "go_point_version")
  
  constraint_value(name = "go1", setting = ":go_version")
  constraint_value(name = "go1.8", setting = ":go_minor_version")
  constraint_value(name = "go1.8.3", setting = ":go_point_version")
  constraint_value(name = "go1.8.2", setting = ":go_point_version")
  constraint_value(name = "go1.8.1", setting = ":go_point_version")
  constraint_value(name = "go1.8.0", setting = ":go_point_version")
  constraint_value(name = "go1.7", setting = ":go_minor_version")
  constraint_value(name = "go1.7.6", setting = ":go_point_version")
  constraint_value(name = "go1.7.5", setting = ":go_version")
  
  # All the os types that go knows about and what their bazel name, GOOS and bazel constraint are
  os_android = struct(name="android", goos="android", constraint = ":android")
  os_darwin = struct(name="osx", goos="darwin", constraint = ":osx")
  os_dragonfly = struct(name="dragonfly", goos="dragonfly", constraint = ":dragonfly")
  os_freebsd = struct(name="freebsd", goos="freebsd", constraint = ":freebsd")
  os_linux = struct(name="linux", goos="linux", constraint = ":linux")
  os_netbsd = struct(name="netbsd", goos="netbsd", constraint = ":netbsd")
  os_openbsd = struct(name="openbsd", goos="openbsd", constraint = ":openbsd")
  os_plan9 = struct(name="plan9", goos="plan9", constraint = ":plan9")
  os_solaris = struct(name="solaris", goos="solaris", constraint = ":solaris")
  os_windows = struct(name="windows", goos="windows", constraint = ":windows")
  
  # All the target architectures go knows about, and what their bazel name, GOARCH and bazel constraint are
  arch_arm = struct(name="arm", goarch="arm", constraint = ":arm")
  arch_arm64 = struct(name="arm64", goarch="arm64", constraint = ":arm64")
  arch_386 = struct(name="386", goarch="386", constraint = ":386")
  arch_amd64 = struct(name="x86_64", goarch="amd64", constraint = ":x86_64")
  arch_ppc64 = struct(name="ppc64", goarch="ppc64", constraint = ":ppc64")
  arch_ppc64le = struct(name="ppc64le", goarch="ppc64le", constraint = ":ppc64le")
  arch_mips = struct(name="mips", goarch="mips", constraint = ":mips")
  arch_mipsle = struct(name="mipsle", goarch="mipsle", constraint = ":mipsle")
  arch_mips64 = struct(name="mips64", goarch="mips64", constraint = ":mips64")
  arch_mips64le = struct(name="mips64le", goarch="mips64le", constraint = ":mips64le")
  
  # The full set of allowed os and arch combinations for the go toolchain
  # This is the set of targets allowed, of which the set of hosts is a strict subset
  android_arm = struct(os=os_android, arch=arch_arm)
  darwin_386 = struct(os=os_darwin, arch=arch_386)
  darwin_amd64 = struct(os=os_darwin, arch=arch_amd64)
  darwin_arm = struct(os=os_darwin, arch=arch_arm)
  darwin_arm64 = struct(os=os_darwin, arch=arch_arm64)
  dragonfly_amd64 = struct(os=os_dragonfly, arch=arch_amd64)
  freebsd_386 = struct(os=os_freebsd, arch=arch_386)
  freebsd_amd64 = struct(os=os_freebsd, arch=arch_amd64)
  freebsd_arm = struct(os=os_freebsd, arch=arch_arm)
  linux_386 = struct(os=os_linux, arch=arch_386)
  linux_amd64 = struct(os=os_linux, arch=arch_amd64)
  linux_arm = struct(os=os_linux, arch=arch_arm)
  linux_arm64 = struct(os=os_linux, arch=arch_arm64)
  linux_ppc64 = struct(os=os_linux, arch=arch_ppc64)
  linux_ppc64le = struct(os=os_linux, arch=arch_ppc64le)
  linux_mips = struct(os=os_linux, arch=arch_mips)
  linux_mipsle = struct(os=os_linux, arch=arch_mipsle)
  linux_mips64 = struct(os=os_linux, arch=arch_mips64)
  linux_mips64le = struct(os=os_linux, arch=arch_mips64le)
  netbsd_386 = struct(os=os_netbsd, arch=arch_386)
  netbsd_amd64 = struct(os=os_netbsd, arch=arch_amd64)
  netbsd_arm = struct(os=os_netbsd, arch=arch_arm)
  openbsd_386 = struct(os=os_openbsd, arch=arch_386)
  openbsd_amd64 = struct(os=os_openbsd, arch=arch_amd64)
  openbsd_arm = struct(os=os_openbsd, arch=arch_arm)
  plan9_386 = struct(os=os_plan9, arch=arch_386)
  plan9_amd64 = struct(os=os_plan9, arch=arch_amd64)
  solaris_amd64 = struct(os=os_solaris, arch=arch_amd64)
  windows_386 = struct(os=os_windows, arch=arch_386)
  windows_amd64 = struct(os=os_windows, arch=arch_amd64)
  
  # The set of acceptable hosts for each of the go versions, this is essentially the
  # set of sdk's we know how to fetch
  versions = [
      struct(
          semver = [1,8,3],
          hosts = [darwin_amd64, linux_386, linux_amd64, windows_386, windows_amd64, freebsd_386, freebsd_amd64]
      ),
      struct(
          semver = [1,8,2],
          hosts = [darwin_amd64, linux_amd64],
      ),
      struct(
          semver = [1,8,1],
          hosts = [darwin_amd64, linux_amd64],
      ),
      struct(
          semver = [1,8,0],
          hosts = [darwin_amd64, linux_amd64],
      ),
      struct(
          semver = [1,7,6],
          hosts = [darwin_amd64, linux_386, linux_amd64, windows_386, windows_amd64, freebsd_386, freebsd_amd64]
      ),
      struct(
          semver = [1,7,5],
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
    major = "go%d" % (version.semver[0])
    minor = "%s.%d" % (major, version.semver[1])
    point = "%s.%d" % (minor, version.semver[2])
    version_constraints = [":" + major, ":" + minor, ":" + point]
    for host in version.hosts:
      distribution = "@go%d_%d_" % (version.semver[0], version.semver[1])
      if version.semver[2]:
        distribution += "%d_" % version.semver[2]
      distribution += "%s_%s" % (host.os.goos, host.arch.goarch)
      for target in [host] + cross_targets.get(host, []):
        toolchain_name = point + "-" + host.os.name + "-" + host.arch.name
        is_cross = host != target
        if is_cross:
          toolchain_name += "-cross-" + target.os.name + "-" + target.arch.name
        toolchains += [dict(
            name = toolchain_name,
            sdk = distribution[1:], # We have to strip off the @
            is_cross = is_cross,
            exec_compatible_with = [host.os.constraint, host.arch.constraint],
            target_compatible_with = [target.os.constraint, target.arch.constraint] + version_constraints,
            root = distribution+"//:root",
            goos = target.os.goos,
            goarch = target.arch.goarch,
            go = distribution+"//:go",
            tools = distribution+"//:tools",
            stdlib = distribution+"//:stdlib_"+target.os.goos + "_" + target.arch.goarch,
            headers = distribution+"//:headers",
            link_flags = [],
            cgo_link_flags = [],
            tags = ["manual"],
        )]

  # Now we go through the generated toolchains, adding exceptions, and removing invalid combinations.
  for toolchain in toolchains:
    if toolchain["goos"] == os_darwin.goos:
      # workaround for a bug in ld(1) on Mac OS X.
      # http://lists.apple.com/archives/Darwin-dev/2006/Sep/msg00084.html
      # TODO(yugui) Remove this workaround once rules_go stops supporting XCode 7.2
      # or earlier.
      toolchain["link_flags"] += ["-s"]
      toolchain["cgo_link_flags"] += ["-shared", "-Wl,-all_load"]
    if toolchain["goos"] == os_linux.goos:
      toolchain["cgo_link_flags"] += ["-Wl,-whole-archive"]

  # Use the final dictionaries to actually generate all the toolchains
  for toolchain in toolchains:
    go_toolchain(**toolchain)
    if not toolchain["is_cross"]:
      go_bootstrap_toolchain(
          name = toolchain["name"] + "-bootstrap",
          exec_compatible_with = toolchain["exec_compatible_with"],
          target_compatible_with = toolchain["target_compatible_with"],
          root = toolchain["root"],
          go = toolchain["go"],
          tools = toolchain["tools"],
          stdlib = toolchain["stdlib"],
          tags = ["manual"],
      )
