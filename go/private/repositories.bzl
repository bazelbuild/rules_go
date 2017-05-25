# Copyright 2014 The Bazel Authors. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Once nested repositories work, this file should cease to exist.

load("//go/private:toolchain.bzl", "go_sdk_repository", "go_repository_select")
load("//go/private:repository_tools.bzl", "go_repository_tools")
load("//go/private:bzl_format.bzl", "bzl_format_repositories")
load("//go/private:go_repository.bzl", "go_repository")

_sdk_repositories = {
    # 1.8.3 repositories
    "go1.8.3.darwin-amd64.tar.gz": "f20b92bc7d4ab22aa18270087c478a74463bd64a893a94264434a38a4b167c05",
    "go1.8.3.linux-386.tar.gz": "ff4895eb68fb1daaec41c540602e8bb4c1e8bb2f0e7017367171913fc9995ed2",
    "go1.8.3.linux-amd64.tar.gz": "1862f4c3d3907e59b04a757cfda0ea7aa9ef39274af99a784f5be843c80c6772",
    "go1.8.3.linux-armv6l.tar.gz": "3c30a3e24736ca776fc6314e5092fb8584bd3a4a2c2fa7307ae779ba2735e668",
    "go1.8.3.windows-386.zip": "9e2bfcb8110a3c56f23b91f859963269bc29fd114190fecfd0a539395272a1c7",
    "go1.8.3.windows-amd64.zip": "de026caef4c5b4a74f359737dcb2d14c67ca45c45093755d3b0d2e0ee3aafd96",
    "go1.8.3.freebsd-386.tar.gz": "d301cc7c2b8b0ccb384ac564531beee8220727fd27ca190b92031a2e3e230224",
    "go1.8.3.freebsd-amd64.tar.gz": "1bf5f076d48609012fe01b95e2a58e71e56719a04d576fe3484a216ad4b9c495",
    "go1.8.3.linux-ppc64le.tar.gz": "e5fb00adfc7291e657f1f3d31c09e74890b5328e6f991a3f395ca72a8c4dc0b3",
    "go1.8.3.linux-s390x.tar.gz": "e2ec3e7c293701b57ca1f32b37977ac9968f57b3df034f2cc2d531e80671e6c8",
    # 1.8.2 repositories
    'go1.8.2.linux-amd64.tar.gz': '5477d6c9a4f96fa120847fafa88319d7b56b5d5068e41c3587eebe248b939be7',
    'go1.8.2.darwin-amd64.tar.gz': '3f783c33686e6d74f6c811725eb3775c6cf80b9761fa6d4cebc06d6d291be137',
    # 1.8.1 repositories
    'go1.8.1.linux-amd64.tar.gz': 'a579ab19d5237e263254f1eac5352efcf1d70b9dacadb6d6bb12b0911ede8994',
    'go1.8.1.darwin-amd64.tar.gz': '25b026fe2f4de7c80b227f69588b06b93787f5b5f134fbf2d652926c08c04bcd',
    # 1.8 repositories
    'go1.8.linux-amd64.tar.gz': '3ab94104ee3923e228a2cb2116e5e462ad3ebaeea06ff04463479d7f12d27ca',
    'go1.8.darwin-amd64.tar.gz': 'fdc9f98b76a28655a8770a1fc8197acd8ef746dd4d8a60589ce19604ba2a120',
    # 1.7.6 repositories
    'go1.7.6.darwin-amd64.tar.gz': '2eec332ac3162d9e19125645176a9477245b47f4657c2f2715818f2a4739f245',
    'go1.7.6.linux-386.tar.gz': '99f79d4e0f966f492794963ecbf4b08c16a9a268f2c09053a5ce10b343ee4082',
    'go1.7.6.linux-amd64.tar.gz': 'ad5808bf42b014c22dd7646458f631385003049ded0bb6af2efc7f1f79fa29ea',
    'go1.7.6.linux-armv6l.tar.gz': 'fc5c40fb1f76d0978504b94cd06b5ea6e0e216ba1d494060d081e022540900f8',
    'go1.7.6.windows-386.zip': 'adc772f1d38a38a985d95247df3d068a42db841489f72a228f51080125f78b8f',
    'go1.7.6.windows-amd64.zip': '3c648f9b89b7e0ed746c211dbf959aa230c8034506dd70c9852bf0f94d06065d',
    'go1.7.6.freebsd-386.tar.gz': '43559a1489b5aa670a3b78da54aebc8064d32c3c6eecd2430270e399e2e0a278',
    'go1.7.6.freebsd-amd64.tar.gz': '79f6afb90980159bfec10165d8102dbb6cf2a1aee018fb66b2eb799ba5e51205',
    'go1.7.6.linux-ppc64le.tar.gz': '8b5b602958396f165a3547a1308ab91ae3f2ad8ecb56063571a37aadc2df2332',
    'go1.7.6.linux-s390x.tar.gz': 'd692643d1ac4f4dea8fb6d949ffa750e974e63ff0ee6ca2a7c38fc7c90da8b5b',
    # 1.7.5 repositories
    'go1.7.5.linux-amd64.tar.gz': '2e4dd6c44f0693bef4e7b46cc701513d74c3cc44f2419bf519d7868b12931ac3',
    'go1.7.5.darwin-amd64.tar.gz': '2e2a5e0a5c316cf922cf7d59ee5724d49fc35b07a154f6c4196172adfc14b2ca',
}

def go_repositories(
    go_version = None,
    go_linux = None,
    go_darwin = None):

  for filename, sha256 in _sdk_repositories.items():
    name = filename
    for suffix in [".tar.gz", ".zip"]:
      if name.endswith(suffix):
        name = name[:-len(suffix)]
    go_sdk_repository(
        name = name,
        url = "https://storage.googleapis.com/golang/" + filename,
        sha256 = sha256,
        strip_prefix = "go",
    )

  # Needed for gazelle and wtool
  native.http_archive(
      name = "com_github_bazelbuild_buildtools",
      url = "https://codeload.github.com/bazelbuild/buildtools/zip/d5dcc29f2304aa28c29ecb8337d52bb9de908e0c",
      strip_prefix = "buildtools-d5dcc29f2304aa28c29ecb8337d52bb9de908e0c",
      type = "zip",
  )

  # Needed for fetch repo
  go_repository(
      name = "org_golang_x_tools",
      importpath = "golang.org/x/tools",
      urls = ["https://codeload.github.com/golang/tools/zip/3d92dd60033c312e3ae7cac319c792271cf67e37"],
      strip_prefix = "tools-3d92dd60033c312e3ae7cac319c792271cf67e37",
      type = "zip",
  )

  bzl_format_repositories()

  go_repository_select(go_version, go_linux, go_darwin)
  go_repository_tools(name = "io_bazel_rules_go_repository_tools")
