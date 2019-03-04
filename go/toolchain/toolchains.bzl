load(
    "//go/private:go_toolchain.bzl",
    "generate_toolchains",
    "go_toolchain",
)
load(
    "//go/private:sdk.bzl",
    "go_download_sdk",
    "go_host_sdk",
)
load(
    "//go/private:nogo.bzl",
    "go_register_nogo",
)
load(
    "//go/platform:list.bzl",
    "GOARCH",
    "GOOS",
    "GOOS_GOARCH",
)
load(
    "@io_bazel_rules_go//go/private:skylib/lib/versions.bzl",
    "versions",
)

DEFAULT_VERSION = "1.12"

MIN_SUPPORTED_VERSION = "1.10"

SDK_REPOSITORIES = {
    "1.12": {
        "darwin_amd64": ("go1.12.darwin-amd64.tar.gz", "6c7e07349403f71588ef4e93a6d4ae31f8e5de1497a0a42fd998fe9b6bd07c8e"),
        "freebsd_386": ("go1.12.freebsd-386.tar.gz", "5f66cc122e91249d9b371b2c8635b0b50db513812e3efaf9d6defbc28bff3a1c"),
        "freebsd_amd64": ("go1.12.freebsd-amd64.tar.gz", "b4c063a3f39de4f837475cb982507926d7cab4f64d35e1dc0d6dce555b3fe143"),
        "linux_386": ("go1.12.linux-386.tar.gz", "3ac1db65a6fa5c13f424b53ee181755429df0c33775733cede1e0d540440fd7b"),
        "linux_amd64": ("go1.12.linux-amd64.tar.gz", "750a07fef8579ae4839458701f4df690e0b20b8bcce33b437e4df89c451b6f13"),
        "linux_arm64": ("go1.12.linux-arm64.tar.gz", "b7bf59c2f1ac48eb587817a2a30b02168ecc99635fc19b6e677cce01406e3fac"),
        "linux_arm": ("go1.12.linux-armv6l.tar.gz", "ea0636f055763d309437461b5817452419411eb1f598dc7f35999fae05bcb79a"),
        "linux_ppc64le": ("go1.12.linux-ppc64le.tar.gz", "5be21e7035efa4a270802ea04fb104dc7a54e3492641ae44632170b93166fb68"),
        "linux_s390x": ("go1.12.linux-s390x.tar.gz", "c0aef360b99ebb4b834db8b5b22777b73a11fa37b382121b24bf587c40603915"),
        "windows_386": ("go1.12.windows-386.zip", "c6606bfdc4d8b080fc40f72a072eb380ead77a02a4f99a6b953df6d9c7029970"),
        "windows_amd64": ("go1.12.windows-amd64.zip", "880ced1aecef08b3471a84381b6c7e2c0e846b81dd97ecb629b534d941f282bd"),
    },
    "1.11.5": {
        "darwin_amd64": ("go1.11.5.darwin-amd64.tar.gz", "b970d8fdd5245193073395ce7b7775dd9deea980d4ce5e68b3b80ee9edcf2afc"),
        "freebsd_386": ("go1.11.5.freebsd-386.tar.gz", "29d208de22cf4561404f4e4866cbb3d937d1043ce65e0a4e4bb88a8c8ac754ea"),
        "freebsd_amd64": ("go1.11.5.freebsd-amd64.tar.gz", "edd594da33d497a3499b362af3a3b3281c2e1de2b68b869154d4151aa82d85e2"),
        "linux_386": ("go1.11.5.linux-386.tar.gz", "acd8e05f8d3eed406e09bb58eab89de3f0a139d4aef15f74adeed2d2c24cb440"),
        "linux_amd64": ("go1.11.5.linux-amd64.tar.gz", "ff54aafedff961eb94792487e827515da683d61a5f9482f668008832631e5d25"),
        "linux_arm64": ("go1.11.5.linux-arm64.tar.gz", "6ee9a5714444182a236d3cc4636e74cfc5e24a1bacf0463ac71dcf0e7d4288ed"),
        "linux_arm": ("go1.11.5.linux-armv6l.tar.gz", "b26b53c94923f78955236386fee0725ef4e76b6cb47e0df0ed0c0c4724e7b198"),
        "linux_ppc64le": ("go1.11.5.linux-ppc64le.tar.gz", "66e83152c68cb35d41f21453377d6a811585c9e01a6ac54b19f7a6e2cbb3d1f5"),
        "linux_s390x": ("go1.11.5.linux-s390x.tar.gz", "56209e5498c64a8338cd6f0fe0c2e2cbf6857c0acdb10c774894f0cc0d19f413"),
        "windows_386": ("go1.11.5.windows-386.zip", "b569f7a45056ab810364d7ac9ee6357e9a098fc3e4c75e016948736fa93ee229"),
        "windows_amd64": ("go1.11.5.windows-amd64.zip", "1c734fe614fa052f44694e993f2d06f24a56b6703ee46fdfb2b9bf277819fe40"),
    },
    "1.11.4": {
        "darwin_amd64": ("go1.11.4.darwin-amd64.tar.gz", "48ea987fb610894b3108ecf42e7a4fd1c1e3eabcaeb570e388c75af1f1375f80"),
        "freebsd_386": ("go1.11.4.freebsd-386.tar.gz", "7c302a5fcb25c7a4d370e856218b748994bbb129810306260293cdfba0a80650"),
        "freebsd_amd64": ("go1.11.4.freebsd-amd64.tar.gz", "e5a99add3e60e38ef559e211584bb09a883ccc46a6fb1432dcaa9fd052689b71"),
        "linux_386": ("go1.11.4.linux-386.tar.gz", "cecd2da1849043237d5f0756a93d601db6798fa3bb27a14563d201088aa415f3"),
        "linux_amd64": ("go1.11.4.linux-amd64.tar.gz", "fb26c30e6a04ad937bbc657a1b5bba92f80096af1e8ee6da6430c045a8db3a5b"),
        "linux_arm64": ("go1.11.4.linux-arm64.tar.gz", "b76df430ba8caff197b8558921deef782cdb20b62fa36fa93f81a8c08ab7c8e7"),
        "linux_arm": ("go1.11.4.linux-armv6l.tar.gz", "9f7a71d27fef69f654a93e265560c8d9db1a2ca3f1dcdbe5288c46facfde5821"),
        "linux_ppc64le": ("go1.11.4.linux-ppc64le.tar.gz", "1f10146826acd56716b00b9188079af53823ddd79ceb6362e78e2f3aafb370ab"),
        "linux_s390x": ("go1.11.4.linux-s390x.tar.gz", "4467442dacf89eb94c5d6f9f700204cb360be82db60e6296cc2ef8d0e890cd42"),
        "windows_386": ("go1.11.4.windows-386.zip", "bc25ea25406878986f91c92ae802f25f033cb0163b4aeac7e7185f71d0ede788"),
        "windows_amd64": ("go1.11.4.windows-amd64.zip", "eeb20e21702f2b9469d9381df5de85e2f731b64a1f54effe196d0f7d0227fe14"),
    },
    "1.11.3": {
        "darwin_amd64": ("go1.11.3.darwin-amd64.tar.gz", "3d164d44fcb06a4bbd69d19d8d91308d601f7d855a1037346389644803fdf148"),
        "freebsd_386": ("go1.11.3.freebsd-386.tar.gz", "2b4aacf3dc09c8b210fe3daf00f7c17c97d29503070200ba46e04f2d93790672"),
        "freebsd_amd64": ("go1.11.3.freebsd-amd64.tar.gz", "29b3fcc8d80ac1ea10cd82ca78d3dac4e7242333b882855ea7bc8e3a9d974116"),
        "linux_386": ("go1.11.3.linux-386.tar.gz", "c3fadf7f8652c060e18b7907fb8e15b853955b25aa661dbd991f6d6bc581d7a9"),
        "linux_amd64": ("go1.11.3.linux-amd64.tar.gz", "d20a4869ffb13cee0f7ee777bf18c7b9b67ef0375f93fac1298519e0c227a07f"),
        "linux_arm64": ("go1.11.3.linux-arm64.tar.gz", "723c54cb081dd629a44d620197e4a789dccdfe6dee7f8b4ad7a6659f76952056"),
        "linux_arm": ("go1.11.3.linux-armv6l.tar.gz", "384933e6e97b74c5125011c8f0539362bbed5a015978a34e441d7333d8e519b9"),
        "linux_ppc64le": ("go1.11.3.linux-ppc64le.tar.gz", "57c89a047ef4f539580af4cadebf1364a906891b065afa0664592e72a034b0ee"),
        "linux_s390x": ("go1.11.3.linux-s390x.tar.gz", "183258709c051ceb2900dee5ee681abb0bc440624c8f657374bde2a5658bef27"),
        "windows_386": ("go1.11.3.windows-386.zip", "07a38035d642ae81820551ce486f2ac7d541c0caf910659452b4661656db0691"),
        "windows_amd64": ("go1.11.3.windows-amd64.zip", "bc168207115eb0686e226ed3708337b161946c1acb0437603e1221e94f2e1f0f"),
    },
    "1.11.2": {
        "darwin_amd64": ("go1.11.2.darwin-amd64.tar.gz", "be2a9382ef85792280951a78e789e8891ddb1df4ac718cd241ea9d977c85c683"),
        "freebsd_386": ("go1.11.2.freebsd-386.tar.gz", "7daf8c1995e6eb343c4b487ba4d6b8fb5463cdead8a8bde867a25cc7168ff77b"),
        "freebsd_amd64": ("go1.11.2.freebsd-amd64.tar.gz", "a0b46726b102067bdd9a9b863f2bce4d23e4478118162bb9b2362733eb28cabf"),
        "linux_386": ("go1.11.2.linux-386.tar.gz", "e74f2f37b43b9b1bcf18008a11e0efb8921b41dff399a4f48ac09a4f25729881"),
        "linux_amd64": ("go1.11.2.linux-amd64.tar.gz", "1dfe664fa3d8ad714bbd15a36627992effd150ddabd7523931f077b3926d736d"),
        "linux_arm64": ("go1.11.2.linux-arm64.tar.gz", "98a42b9b8d3bacbcc6351a1e39af52eff582d0bc3ac804cd5a97ce497dd84026"),
        "linux_arm": ("go1.11.2.linux-armv6l.tar.gz", "b9d16a8eb1f7b8fdadd27232f6300aa8b4427e5e4cb148c4be4089db8fb56429"),
        "linux_ppc64le": ("go1.11.2.linux-ppc64le.tar.gz", "23291935a299fdfde4b6a988ce3faa0c7a498aab6d56bbafbf1e7476468529a3"),
        "linux_s390x": ("go1.11.2.linux-s390x.tar.gz", "a67ef820ef8cfecc8d68c69dd5bf513aaf647c09b6605570af425bf5fe8a32f0"),
        "windows_386": ("go1.11.2.windows-386.zip", "c0c5ab568d9cf260cd7d281e0a489ef91f4b943813d99dac78b61607dca17283"),
        "windows_amd64": ("go1.11.2.windows-amd64.zip", "086c59df0dce54d88f30edd50160393deceb27e73b8d6b46b9ee3f88b0c02e28"),
    },
    "1.11.1": {
        "darwin_amd64": ("go1.11.1.darwin-amd64.tar.gz", "1f2b29c8b08a140f06c88d055ad68104ccea9ca75fd28fbc95fe1eeb61a29bef"),
        "freebsd_386": ("go1.11.1.freebsd-386.tar.gz", "db02787955495a4128811705dabf1b09c6d9674d59ebf93bc7be40a1ead7d91f"),
        "freebsd_amd64": ("go1.11.1.freebsd-amd64.tar.gz", "b2618f92bf5365c3e4f2a1f82997505d6356364310fdc0b9137734c4c9df29d8"),
        "linux_386": ("go1.11.1.linux-386.tar.gz", "52935db83719739d84a389a8f3b14544874fba803a316250b8d596313283aadf"),
        "linux_amd64": ("go1.11.1.linux-amd64.tar.gz", "2871270d8ff0c8c69f161aaae42f9f28739855ff5c5204752a8d92a1c9f63993"),
        "linux_arm64": ("go1.11.1.linux-arm64.tar.gz", "25e1a281b937022c70571ac5a538c9402dd74bceb71c2526377a7e5747df5522"),
        "linux_arm": ("go1.11.1.linux-armv6l.tar.gz", "bc601e428f458da6028671d66581b026092742baf6d3124748bb044c82497d42"),
        "linux_ppc64le": ("go1.11.1.linux-ppc64le.tar.gz", "f929d434d6db09fc4c6b67b03951596e576af5d02ff009633ca3c5be1c832bdd"),
        "linux_s390x": ("go1.11.1.linux-s390x.tar.gz", "93afc048ad72fa2a0e5ec56bcdcd8a34213eb262aee6f39a7e4dfeeb7e564c9d"),
        "windows_386": ("go1.11.1.windows-386.zip", "5cc3681c954e23d40b0c2565765ec34f4b4e834348e03e1d1e6fd1c3a75b8202"),
        "windows_amd64": ("go1.11.1.windows-amd64.zip", "230a08d4260ded9d769f072512a49bffe8bfaff8323e839c2db7cf7c9c788130"),
    },
    "1.11": {
        "darwin_amd64": ("go1.11.darwin-amd64.tar.gz", "9749e6cb9c6d05cf10445a7c9899b58e72325c54fee9783ed1ac679be8e1e073"),
        "freebsd_386": ("go1.11.freebsd-386.tar.gz", "e4c2a9bd43932cb8f3226e866737e4a0f8cdda93db9d82754a0ffea04af1a259"),
        "freebsd_amd64": ("go1.11.freebsd-amd64.tar.gz", "535a7561a229bfe7bece68c8e315421fd9fbbd3a599b461944113c8d8240b28f"),
        "linux_386": ("go1.11.linux-386.tar.gz", "1a91932b65b4af2f84ef2dce10d790e6a0d3d22c9ea1bdf3d8c4d9279dfa680e"),
        "linux_amd64": ("go1.11.linux-amd64.tar.gz", "b3fcf280ff86558e0559e185b601c9eade0fd24c900b4c63cd14d1d38613e499"),
        "linux_arm64": ("go1.11.linux-arm64.tar.gz", "e4853168f41d0bea65e4d38f992a2d44b58552605f623640c5ead89d515c56c9"),
        "linux_arm": ("go1.11.linux-armv6l.tar.gz", "8ffeb3577d8ca5477064f1cb8739835973c866487f2bf81df1227eaa96826acd"),
        "linux_ppc64le": ("go1.11.linux-ppc64le.tar.gz", "e874d617f0e322f8c2dda8c23ea3a2ea21d5dfe7177abb1f8b6a0ac7cd653272"),
        "linux_s390x": ("go1.11.linux-s390x.tar.gz", "c113495fbb175d6beb1b881750de1dd034c7ae8657c30b3de8808032c9af0a15"),
        "windows_386": ("go1.11.windows-386.zip", "d3279f0e3d728637352eff0aa1e11268a0eb01f13644bcbce1c066139f5a90db"),
        "windows_amd64": ("go1.11.windows-amd64.zip", "29f9291270f0b303d0b270f993972ead215b1bad3cc674a0b8a09699d978aeb4"),
    },
    "1.10.8": {
        "darwin_amd64": ("go1.10.8.darwin-amd64.tar.gz", "f41bc914a721ac98a187df824b3b40f0a7f35bfb3c6d31221bdd940d537d3c28"),
        "freebsd_386": ("go1.10.8.freebsd-386.tar.gz", "029219c9588fd6af498898e783963c7ce3489270304987c561990d8d01169d7b"),
        "freebsd_amd64": ("go1.10.8.freebsd-amd64.tar.gz", "fc1ab404793cb9322e6e7348c274bf7d3562cc8bfb7b17e3b7c6e5787c89da2b"),
        "linux_386": ("go1.10.8.linux-386.tar.gz", "10202da0b7f2a0f2c2ec4dd65375584dd829ce88ccc58e5fe1fa1352e69fecaf"),
        "linux_amd64": ("go1.10.8.linux-amd64.tar.gz", "d8626fb6f9a3ab397d88c483b576be41fa81eefcec2fd18562c87626dbb3c39e"),
        "linux_arm64": ("go1.10.8.linux-arm64.tar.gz", "0921a76e78022ec2ae217e85b04940e2e9912b4c3218d96a827deedb9abe1c7b"),
        "linux_arm": ("go1.10.8.linux-armv6l.tar.gz", "6fdbc67524fc4c15fc87014869dddce9ecda7958b78f3cb1bbc5b0a9b61bfb95"),
        "linux_ppc64le": ("go1.10.8.linux-ppc64le.tar.gz", "9054bcc7582ebb8a69ca43447a38e4b9ea11d08f05511cc7f13720e3a12ff299"),
        "linux_s390x": ("go1.10.8.linux-s390x.tar.gz", "6f71b189c6cf30f7736af21265e992990cb0374138b7a70b0880cf8579399a69"),
        "windows_386": ("go1.10.8.windows-386.zip", "9ded97d830bef3734ea6de70df0159656d6a63e01484175b34d72b8db326bda0"),
        "windows_amd64": ("go1.10.8.windows-amd64.zip", "ab63b55c349f75cce4b93aefa9b52828f50ebafb302da5057db0e686d7873d7a"),
    },
    "1.10.7": {
        "darwin_amd64": ("go1.10.7.darwin-amd64.tar.gz", "700725a36d29d6e5d474a887acbf490c3d2762d719bdfef8370e22198077297d"),
        "freebsd_386": ("go1.10.7.freebsd-386.tar.gz", "d45bd54c38169ba228a67a17c92560e5a455405f6f5116a030c512510b06987c"),
        "freebsd_amd64": ("go1.10.7.freebsd-amd64.tar.gz", "21c9bda5fa37d668348e65b2374de6da84c85d601e45bbba4d8e2c86450f2a95"),
        "linux_386": ("go1.10.7.linux-386.tar.gz", "55cd25e550cb8ce8250dbc9eda56b9c10b3097c7f6beed45066fbaaf8c6c1ebd"),
        "linux_amd64": ("go1.10.7.linux-amd64.tar.gz", "1aabe10919048822f3bb1865f7a22f8b78387a12c03cd573101594bc8fb33579"),
        "linux_arm64": ("go1.10.7.linux-arm64.tar.gz", "cb5a274f7c8f6186957e4503e724dda8aeffe84b76a146748c55ea5bb22d9ae4"),
        "linux_arm": ("go1.10.7.linux-armv6l.tar.gz", "1f81c995f829c8fc7def4d0cc1bde63cac1834386e6f650f2cd7be56ab5e8b98"),
        "linux_ppc64le": ("go1.10.7.linux-ppc64le.tar.gz", "11279ffebfcfa875b0552839d428cc72e2056e68681286429b57173c0da91fb4"),
        "linux_s390x": ("go1.10.7.linux-s390x.tar.gz", "e0d7802029ed8d2720a2b27ec1816e71cb29f818380abb8b449080e97547881e"),
        "windows_386": ("go1.10.7.windows-386.zip", "bbd297a456aded5dcafe91194aafec883802cd0982120c735d15a39810248ea7"),
        "windows_amd64": ("go1.10.7.windows-amd64.zip", "791e2d5a409932157ac87f4da7fa22d5e5468b784d5933121e4a747d89639e15"),
    },
    "1.10.6": {
        "darwin_amd64": ("go1.10.6.darwin-amd64.tar.gz", "419e7a775c39074ff967b4e66fa212eb4fd310b1f15675ce13977b57635dd3a8"),
        "freebsd_386": ("go1.10.6.freebsd-386.tar.gz", "d1f0aef497588865967256030cb676c6c62f6a4b53649814e753ae150fbaa960"),
        "freebsd_amd64": ("go1.10.6.freebsd-amd64.tar.gz", "194a1a39a96bb8d7ed8370dae7768db47109f628aea4f1588f677f66c384955a"),
        "linux_386": ("go1.10.6.linux-386.tar.gz", "171fe6cbecb2845b875a35ac7ad758d4c0c5bd03f330fa35d340de85b9070e71"),
        "linux_amd64": ("go1.10.6.linux-amd64.tar.gz", "acbdedf28b55b38d2db6f06209a25a869a36d31bdcf09fd2ec3d40e1279e0592"),
        "linux_arm64": ("go1.10.6.linux-arm64.tar.gz", "0fcbfbcbf6373c0b6876786900a4a100c1ed9af86bd3258f23ab498cca4c02a1"),
        "linux_arm": ("go1.10.6.linux-armv6l.tar.gz", "4da252fc7e834b7ce35d349fb581aa84a08adece926a0b9a8e4216451ffcb11e"),
        "linux_ppc64le": ("go1.10.6.linux-ppc64le.tar.gz", "ebd7e4688f3e1baabbc735453b19c6c27116e1f292bf46622123bfc4c160c747"),
        "linux_s390x": ("go1.10.6.linux-s390x.tar.gz", "0223daa57bdef5bf85d308f6d2793c58055d294c13cbaca240ead2f568de2e9f"),
        "windows_386": ("go1.10.6.windows-386.zip", "2f3ded109a37d53bd8600fa23c07d9abea41fb30a5f5954bbc97e9c57d8e0ce0"),
        "windows_amd64": ("go1.10.6.windows-amd64.zip", "fc57f16c23b7fb41b664f549ff2ed6cca340555e374c5ff52fa296cd3f228f32"),
    },
    "1.10.5": {
        "darwin_amd64": ("go1.10.5.darwin-amd64.tar.gz", "36873d9935f7f3519da11c9e928b66c94ccbf71c37df71b7635e804a226ae631"),
        "freebsd_386": ("go1.10.5.freebsd-386.tar.gz", "6533503d07f1f966966d5342584eca036aea72339af6da3b2db74bee94df8ac1"),
        "freebsd_amd64": ("go1.10.5.freebsd-amd64.tar.gz", "a742a8a2feec059ee32d79c9d72a11c87857619eb6d4fa7910c62a49901142c4"),
        "linux_386": ("go1.10.5.linux-386.tar.gz", "bc1bd42405a551ba7ac86b79b9d23a5635f21de53caf684acd8bf5dfee8bef5d"),
        "linux_amd64": ("go1.10.5.linux-amd64.tar.gz", "a035d9beda8341b645d3f45a1b620cf2d8fb0c5eb409be36b389c0fd384ecc3a"),
        "linux_arm64": ("go1.10.5.linux-arm64.tar.gz", "b4c16fcee18bc79de2fa4776c8d0f9bc164ddfc32101e96fe1da83ebe881e3df"),
        "linux_arm": ("go1.10.5.linux-armv6l.tar.gz", "1d864a6d0ec599de9112c8354dcaaa886b4df928757966939402598e9bd9c238"),
        "linux_ppc64le": ("go1.10.5.linux-ppc64le.tar.gz", "8fc13736d383312710249b24adf05af59ff14dacb73d9bd715ff463bc89c5c5f"),
        "linux_s390x": ("go1.10.5.linux-s390x.tar.gz", "e90269495fab7ef99aea6937caf7a049896b2dc7b181456f80a506e69a8b57fc"),
        "windows_386": ("go1.10.5.windows-386.zip", "e936532cc0d3ea9470129ba6df3714924fbc709a9441209a8154503cf16823f2"),
        "windows_amd64": ("go1.10.5.windows-amd64.zip", "d88a32eb4d1fc3b11253c9daa2ef397c8700f3ba493b41324b152e6cda44d2b4"),
    },
    "1.10.4": {
        "darwin_amd64": ("go1.10.4.darwin-amd64.tar.gz", "2ba324f01de2b2ece0376f6d696570a4c5c13db67d00aadfd612adc56feff587"),
        "freebsd_386": ("go1.10.4.freebsd-386.tar.gz", "d2d375daf6352e7b2d4f0dc8a90d1dbc463b955221b9d87fb1fbde805c979bb2"),
        "freebsd_amd64": ("go1.10.4.freebsd-amd64.tar.gz", "ad2fbf6ab2d1754f4ae5d8f6488bdcc6cc48dd15cac29207f38f7cbf0978ed17"),
        "linux_386": ("go1.10.4.linux-386.tar.gz", "771f48e55776d4abc9c2a74907457066c7c282ac05fa01cf5ff4422ced76d2ee"),
        "linux_amd64": ("go1.10.4.linux-amd64.tar.gz", "fa04efdb17a275a0c6e137f969a1c4eb878939e91e1da16060ce42f02c2ec5ec"),
        "linux_arm64": ("go1.10.4.linux-arm64.tar.gz", "2e0f9e99aeefaabba280b2bf85db0336da122accde73603159b3d72d0b2bd512"),
        "linux_arm": ("go1.10.4.linux-armv6l.tar.gz", "4e1e80bd98f3598c0c48ba0c189c836d01b602bfc769b827a4bfed01d2c14b21"),
        "linux_ppc64le": ("go1.10.4.linux-ppc64le.tar.gz", "1cfc147357c0be91a988998046997c5f30b20c6baaeb6cd5774717714db76093"),
        "linux_s390x": ("go1.10.4.linux-s390x.tar.gz", "5593d770d6544090c1bb20d57bb34c743131470695e195fbe5352bf056927a35"),
        "windows_386": ("go1.10.4.windows-386.zip", "407e5619048c427de4a65b26edb17d54c220f8c30ebd358961b1785a38394ec9"),
        "windows_amd64": ("go1.10.4.windows-amd64.zip", "5499aa98399664df8dc1da5c3aaaed14b3130b79c713b5677a0ee9e93854476c"),
    },
    "1.10.3": {
        "darwin_amd64": ("go1.10.3.darwin-amd64.tar.gz", "131fd430350a3134d352ee75c5ca456cdf4443e492d0527a9651c7c04e2b458d"),
        "freebsd_386": ("go1.10.3.freebsd-386.tar.gz", "92a28ccd8caa173295490dfd3f1d10f3bc7eaf0953bf099631bc6c57a5842704"),
        "freebsd_amd64": ("go1.10.3.freebsd-amd64.tar.gz", "231d9e6f3b5acee1193cd18b98c89f1a51570fbc8ba7c6c6b67a7f7ff2985e2b"),
        "linux_386": ("go1.10.3.linux-386.tar.gz", "3d5fe1932c904a01acb13dae07a5835bffafef38bef9e5a05450c52948ebdeb4"),
        "linux_amd64": ("go1.10.3.linux-amd64.tar.gz", "fa1b0e45d3b647c252f51f5e1204aba049cde4af177ef9f2181f43004f901035"),
        "linux_arm64": ("go1.10.3.linux-arm64.tar.gz", "355128a05b456c9e68792143801ad18e0431510a53857f640f7b30ba92624ed2"),
        "linux_arm": ("go1.10.3.linux-armv6l.tar.gz", "d3df3fa3d153e81041af24f31a82f86a21cb7b92c1b5552fb621bad0320f06b6"),
        "linux_ppc64le": ("go1.10.3.linux-ppc64le.tar.gz", "f3640b2f0990a9617c937775f669ee18f10a82e424e5f87a8ce794a6407b8347"),
        "linux_s390x": ("go1.10.3.linux-s390x.tar.gz", "34385f64651f82fbc11dc43bdc410c2abda237bdef87f3a430d35a508ec3ce0d"),
        "windows_386": ("go1.10.3.windows-386.zip", "89696a29bdf808fa9861216a21824ae8eb2e750a54b1424ce7f2a177e5cd1466"),
        "windows_amd64": ("go1.10.3.windows-amd64.zip", "a3f19d4fc0f4b45836b349503e347e64e31ab830dedac2fc9c390836d4418edb"),
    },
    "1.10.2": {
        "darwin_amd64": ("go1.10.2.darwin-amd64.tar.gz", "360ad908840217ee1b2a0b4654666b9abb3a12c8593405ba88ab9bba6e64eeda"),
        "freebsd_386": ("go1.10.2.freebsd-386.tar.gz", "f272774839a95041cf8874171ef6a8c6692e8784544ca05abbb29c66643d24a9"),
        "freebsd_amd64": ("go1.10.2.freebsd-amd64.tar.gz", "6174ff4c2da7ebb064e7f2b28419d2cd5d3f7de34bec9e42d3716bdb190c9955"),
        "linux_386": ("go1.10.2.linux-386.tar.gz", "ea4caddf76b86ed5d101a61bc9a273be5b24d81f0567270bb4d5beaaded9b567"),
        "linux_amd64": ("go1.10.2.linux-amd64.tar.gz", "4b677d698c65370afa33757b6954ade60347aaca310ea92a63ed717d7cb0c2ff"),
        "linux_arm64": ("go1.10.2.linux-arm64.tar.gz", "d6af66c71b12d63c754d5bf49c3007dc1c9821eb1a945118bfd5a539a327c4c8"),
        "linux_arm": ("go1.10.2.linux-armv6l.tar.gz", "529a16b531d4561572db6ba9d357215b58a1953437a63e76dc0c597be9e25dd2"),
        "linux_ppc64le": ("go1.10.2.linux-ppc64le.tar.gz", "f0748502c90e9784b6368937f1d157913d18acdae72ac75add50e5c0c9efc85c"),
        "linux_s390x": ("go1.10.2.linux-s390x.tar.gz", "2266b7ebdbca13c21a1f6039c9f6887cd2c01617d1e2716ff4595307a0da1d46"),
        "windows_386": ("go1.10.2.windows-386.zip", "0bb12875044674d632d1f1b2f53cf33510a6df914178fe672f3f70f6f6cdf80d"),
        "windows_amd64": ("go1.10.2.windows-amd64.zip", "0fb4a893796e8151c0b8d0a3da4ed8cbb22bf6d98a3c29c915be4d7083f146ee"),
    },
    "1.10.1": {
        "darwin_amd64": ("go1.10.1.darwin-amd64.tar.gz", "0a5bbcbbb0d150338ba346151d2864fd326873beaedf964e2057008c8a4dc557"),
        "linux_386": ("go1.10.1.linux-386.tar.gz", "acbe19d56123549faf747b4f61b730008b185a0e2145d220527d2383627dfe69"),
        "linux_amd64": ("go1.10.1.linux-amd64.tar.gz", "72d820dec546752e5a8303b33b009079c15c2390ce76d67cf514991646c6127b"),
        "linux_arm": ("go1.10.1.linux-armv6l.tar.gz", "feca4e920d5ca25001dc0823390df79bc7ea5b5b8c03483e5a2c54f164654936"),
        "windows_386": ("go1.10.1.windows-386.zip", "2f09edd066cc929bb362262afab27609e8d4b96f7dfd3f3844238e3214db9b8a"),
        "windows_amd64": ("go1.10.1.windows-amd64.zip", "17f7664131202b469f4264161ff3cd0796e8398249d2b646bbe4990301afc678"),
        "freebsd_386": ("go1.10.1.freebsd-386.tar.gz", "3e7f0967348d554ebe385f2372411ecfdbdc3074c8ff3ccb9f2910a765c4e472"),
        "freebsd_amd64": ("go1.10.1.freebsd-amd64.tar.gz", "41f57f91363c81523ec23d4a25f0ba92bd66a8c1a35b6df82491a8413bd2cd62"),
        "linux_arm64": ("go1.10.1.linux-arm64.tar.gz", "1e07a159414b5090d31166d1a06ee501762076ef21140dcd54cdcbe4e68a9c9b"),
        "linux_ppc64le": ("go1.10.1.linux-ppc64le.tar.gz", "91d0026bbed601c4aad332473ed02f9a460b31437cbc6f2a37a88c0376fc3a65"),
        "linux_s390x": ("go1.10.1.linux-s390x.tar.gz", "e211a5abdacf843e16ac33a309d554403beb63959f96f9db70051f303035434b"),
    },
    "1.10": {
        "darwin_amd64": ("go1.10.darwin-amd64.tar.gz", "511a4799e8d64cda3352bb7fe72e359689ea6ef0455329cda6b6e1f3137326c1"),
        "linux_386": ("go1.10.linux-386.tar.gz", "2d26a9f41fd80eeb445cc454c2ba6b3d0db2fc732c53d7d0427a9f605bfc55a1"),
        "linux_amd64": ("go1.10.linux-amd64.tar.gz", "b5a64335f1490277b585832d1f6c7f8c6c11206cba5cd3f771dcb87b98ad1a33"),
        "linux_arm": ("go1.10.linux-armv6l.tar.gz", "6ff665a9ab61240cf9f11a07e03e6819e452a618a32ea05bbb2c80182f838f4f"),
        "windows_386": ("go1.10.windows-386.zip", "83edd9e52ce6d1c8f911e7bbf6f0a73952c613b4bf66438ceb1507f892240f11"),
        "windows_amd64": ("go1.10.windows-amd64.zip", "210b223031c254a6eb8fa138c3782b23af710a9959d64b551fa81edd762ea167"),
        "freebsd_386": ("go1.10.freebsd-386.tar.gz", "d1e84cc46fa7290a6849c794785d629239f07c6f3e565616fa5421dd51344211"),
        "freebsd_amd64": ("go1.10.freebsd-amd64.tar.gz", "9ecc9dd288e9727b9ed250d5adbcf21073c038391e8d96aff46c20800be317c3"),
        "linux_arm64": ("go1.10.linux-arm64.tar.gz", "efb47e5c0e020b180291379ab625c6ec1c2e9e9b289336bc7169e6aa1da43fd8"),
        "linux_ppc64le": ("go1.10.linux-ppc64le.tar.gz", "a1e22e2fbcb3e551e0bf59d0f8aeb4b3f2df86714f09d2acd260c6597c43beee"),
        "linux_s390x": ("go1.10.linux-s390x.tar.gz", "71cde197e50afe17f097f81153edb450f880267699f22453272d184e0f4681d7"),
    },
}

_label_prefix = "@io_bazel_rules_go//go/toolchain:"

def go_register_toolchains(go_version = DEFAULT_VERSION, nogo = None):
    """See /go/toolchains.rst#go-register-toolchains for full documentation."""
    if "go_sdk" not in native.existing_rules():
        if go_version in SDK_REPOSITORIES:
            if not versions.is_at_least(MIN_SUPPORTED_VERSION, go_version):
                print("DEPRECATED: go_register_toolchains: support for Go versions before {} will be removed soon".format(MIN_SUPPORTED_VERSION))
            go_download_sdk(
                name = "go_sdk",
                sdks = SDK_REPOSITORIES[go_version],
            )
        elif go_version == "host":
            go_host_sdk(
                name = "go_sdk",
            )
        else:
            fail("Unknown go version {}".format(go_version))

    if nogo:
        # Override default definition in go_rules_dependencies().
        go_register_nogo(
            name = "io_bazel_rules_nogo",
            nogo = nogo,
        )

def declare_constraints():
    for goos, constraint in GOOS.items():
        if constraint:
            native.alias(
                name = goos,
                actual = constraint,
            )
        else:
            native.constraint_value(
                name = goos,
                constraint_setting = "@bazel_tools//platforms:os",
            )
    for goarch, constraint in GOARCH.items():
        if constraint:
            native.alias(
                name = goarch,
                actual = constraint,
            )
        else:
            native.constraint_value(
                name = goarch,
                constraint_setting = "@bazel_tools//platforms:cpu",
            )
    for goos, goarch in GOOS_GOARCH:
        native.platform(
            name = goos + "_" + goarch,
            constraint_values = [
                ":" + goos,
                ":" + goarch,
            ],
        )

def declare_toolchains(host, sdk, builder):
    # Use the final dictionaries to create all the toolchains
    for toolchain in generate_toolchains(host, sdk, builder):
        go_toolchain(**toolchain)
