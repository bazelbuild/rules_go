load(
    "//go/private:go_toolchain.bzl",
    "go_toolchain",
)
load(
    "//go/private:sdk.bzl",
    "go_download_sdk",
    "go_host_sdk",
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

DEFAULT_VERSION = "1.10.3"

MIN_SUPPORTED_VERSION = "1.9"

SDK_REPOSITORIES = {
    "1.10.3": {
        "darwin_amd64": ("go1.10.3.darwin-amd64.tar.gz", "131fd430350a3134d352ee75c5ca456cdf4443e492d0527a9651c7c04e2b458d"),
        "freebsd_386": ("go1.10.3.freebsd-386.tar.gz", "92a28ccd8caa173295490dfd3f1d10f3bc7eaf0953bf099631bc6c57a5842704"),
        "freebsd_amd64": ("go1.10.3.freebsd-amd64.tar.gz", "231d9e6f3b5acee1193cd18b98c89f1a51570fbc8ba7c6c6b67a7f7ff2985e2b"),
        "linux_386": ("go1.10.3.linux-386.tar.gz", "3d5fe1932c904a01acb13dae07a5835bffafef38bef9e5a05450c52948ebdeb4"),
        "linux_amd64": ("go1.10.3.linux-amd64.tar.gz", "fa1b0e45d3b647c252f51f5e1204aba049cde4af177ef9f2181f43004f901035"),
        "linux_arm64": ("go1.10.3.linux-arm64.tar.gz", "355128a05b456c9e68792143801ad18e0431510a53857f640f7b30ba92624ed2"),
        "linux_armv6l": ("go1.10.3.linux-armv6l.tar.gz", "d3df3fa3d153e81041af24f31a82f86a21cb7b92c1b5552fb621bad0320f06b6"),
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
        "linux_armv6l": ("go1.10.2.linux-armv6l.tar.gz", "529a16b531d4561572db6ba9d357215b58a1953437a63e76dc0c597be9e25dd2"),
        "linux_ppc64le": ("go1.10.2.linux-ppc64le.tar.gz", "f0748502c90e9784b6368937f1d157913d18acdae72ac75add50e5c0c9efc85c"),
        "linux_s390x": ("go1.10.2.linux-s390x.tar.gz", "2266b7ebdbca13c21a1f6039c9f6887cd2c01617d1e2716ff4595307a0da1d46"),
        "windows_386": ("go1.10.2.windows-386.zip", "0bb12875044674d632d1f1b2f53cf33510a6df914178fe672f3f70f6f6cdf80d"),
        "windows_amd64": ("go1.10.2.windows-amd64.zip", "0fb4a893796e8151c0b8d0a3da4ed8cbb22bf6d98a3c29c915be4d7083f146ee"),
    },
    "1.10.1": {
        "darwin_amd64": ("go1.10.1.darwin-amd64.tar.gz", "0a5bbcbbb0d150338ba346151d2864fd326873beaedf964e2057008c8a4dc557"),
        "linux_386": ("go1.10.1.linux-386.tar.gz", "acbe19d56123549faf747b4f61b730008b185a0e2145d220527d2383627dfe69"),
        "linux_amd64": ("go1.10.1.linux-amd64.tar.gz", "72d820dec546752e5a8303b33b009079c15c2390ce76d67cf514991646c6127b"),
        "linux_armv6l": ("go1.10.1.linux-armv6l.tar.gz", "feca4e920d5ca25001dc0823390df79bc7ea5b5b8c03483e5a2c54f164654936"),
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
        "linux_armv6l": ("go1.10.linux-armv6l.tar.gz", "6ff665a9ab61240cf9f11a07e03e6819e452a618a32ea05bbb2c80182f838f4f"),
        "windows_386": ("go1.10.windows-386.zip", "83edd9e52ce6d1c8f911e7bbf6f0a73952c613b4bf66438ceb1507f892240f11"),
        "windows_amd64": ("go1.10.windows-amd64.zip", "210b223031c254a6eb8fa138c3782b23af710a9959d64b551fa81edd762ea167"),
        "freebsd_386": ("go1.10.freebsd-386.tar.gz", "d1e84cc46fa7290a6849c794785d629239f07c6f3e565616fa5421dd51344211"),
        "freebsd_amd64": ("go1.10.freebsd-amd64.tar.gz", "9ecc9dd288e9727b9ed250d5adbcf21073c038391e8d96aff46c20800be317c3"),
        "linux_arm64": ("go1.10.linux-arm64.tar.gz", "efb47e5c0e020b180291379ab625c6ec1c2e9e9b289336bc7169e6aa1da43fd8"),
        "linux_ppc64le": ("go1.10.linux-ppc64le.tar.gz", "a1e22e2fbcb3e551e0bf59d0f8aeb4b3f2df86714f09d2acd260c6597c43beee"),
        "linux_s390x": ("go1.10.linux-s390x.tar.gz", "71cde197e50afe17f097f81153edb450f880267699f22453272d184e0f4681d7"),
    },
    "1.9.7": {
        "darwin_amd64": ("go1.9.7.darwin-amd64.tar.gz", "3f4f84406dcada4eec785dbc967747f61c1f1b4e36d7545161e282259e9b215f"),
        "freebsd_386": ("go1.9.7.freebsd-386.tar.gz", "9e7e42975747c80aa5efe10d9cbe258669b9f5ea7e647919ba786a0f75627bbe"),
        "freebsd_amd64": ("go1.9.7.freebsd-amd64.tar.gz", "19b2bd6b83d806602216e2cacc27e40e97b6026bde0ec18cfb990bd9f2932708"),
        "linux_386": ("go1.9.7.linux-386.tar.gz", "c689fdb0b4f4530e48b44a3e591e53660fcbc97c3757ff9c3028adadabcf8378"),
        "linux_amd64": ("go1.9.7.linux-amd64.tar.gz", "88573008f4f6233b81f81d8ccf92234b4f67238df0f0ab173d75a302a1f3d6ee"),
        "linux_arm64": ("go1.9.7.linux-arm64.tar.gz", "68f48c29f93e4c69bbbdb335f473d666b9f8791643f4003ef45283a968b41f86"),
        "linux_armv6l": ("go1.9.7.linux-armv6l.tar.gz", "83b165d617807d636d2cfe07f34920ab6e5374a07ab02d60edcaec008de608ee"),
        "linux_ppc64le": ("go1.9.7.linux-ppc64le.tar.gz", "66cc2b9d591c8ef5adc4c4454f871546b0bab6be1dcbd151c2881729884fbbdd"),
        "linux_s390x": ("go1.9.7.linux-s390x.tar.gz", "7148ba7bc6f40b342d35a28b0cc43dd8f2b2acd7fb3e8891bc95b0f783bc8c9f"),
        "windows_386": ("go1.9.7.windows-386.zip", "0748a66f221f7608d2a6e52dda93bccb5a2d4dd5d8458de481b7f88972558c3c"),
        "windows_amd64": ("go1.9.7.windows-amd64.zip", "8db4b21916a3bc79f48d0611202ee5814c82f671b36d5d2efcb446879456cd28"),
    },
    "1.9.6": {
        "darwin_amd64": ("go1.9.6.darwin-amd64.tar.gz", "3de992c35021963af33029b7c0703bf25d1a3bb9236d117ebde09a9e12dfe715"),
        "freebsd_386": ("go1.9.6.freebsd-386.tar.gz", "e038805a0211dff4935b9ec325a888aa70ab6dc655a2252ae93d8fbd6eb23413"),
        "freebsd_amd64": ("go1.9.6.freebsd-amd64.tar.gz", "d557b31eec03addeede54d007240a3d66d1f439fbf3f0666203fc3ef2e2cfe59"),
        "linux_386": ("go1.9.6.linux-386.tar.gz", "de65e35d7e540578e78a3c6917b9e9033b55617ef894a1de1a6a6da5a1b948dd"),
        "linux_amd64": ("go1.9.6.linux-amd64.tar.gz", "d1eb07f99ac06906225ac2b296503f06cc257b472e7d7817b8f822fe3766ebfe"),
        "linux_arm64": ("go1.9.6.linux-arm64.tar.gz", "8596d64b9f582d6209c04513824e428d1c356276180d2089d4dfcf4c7cf8a6cc"),
        "linux_armv6l": ("go1.9.6.linux-armv6l.tar.gz", "73e56ec4408650d9fda0be8282a9ad49c51ad17929b4d20c04cea07249726bd8"),
        "linux_ppc64le": ("go1.9.6.linux-ppc64le.tar.gz", "b1203546c68e3be7b5e36a5cfb6ff5ef94bd476f5423035bc7e65255858741ff"),
        "linux_s390x": ("go1.9.6.linux-s390x.tar.gz", "2baa6e48eedb8ec7e2a4d2454cdf05d1f46d5a07ff2f03cab5b7b8eadef7e112"),
        "windows_386": ("go1.9.6.windows-386.zip", "1ec01c451f13127bb592b74b8d3e5a9fa1a24e48e9172cda783f0cdda6434904"),
        "windows_amd64": ("go1.9.6.windows-amd64.zip", "0b3a31eb7a46ef3976098cb92fde63c0871dceced91b0a3187953456f8eb8d6e"),
    },
    "1.9.5": {
        "darwin_amd64": ("go1.9.5.darwin-amd64.tar.gz", "2300c620a307bdee08670a9190e0916337514fd0bec3ea19115329d18c49b586"),
        "linux_386": ("go1.9.5.linux-386.tar.gz", "52e0e3421ac4d9b8d8c89121ea93e5e3180a26679a8ea64ecbeb3657251634a3"),
        "linux_amd64": ("go1.9.5.linux-amd64.tar.gz", "d21bdabf4272c2248c41b45cec606844bdc5c7c04240899bde36c01a28c51ee7"),
        "linux_armv6l": ("go1.9.5.linux-armv6l.tar.gz", "e9b6f0cbd95ff3077ddeaec1958be77d9675f0cf5652a67152d28d84707a4e9e"),
        "windows_386": ("go1.9.5.windows-386.zip", "c29ea03496a5d61ddcc811110b3d6b8f774e89b19a6dc3839f2d2f82e3789635"),
        "windows_amd64": ("go1.9.5.windows-amd64.zip", "6c3ef0e069c0edb0b5e8575f0efca806f69354a7b808f9846b89046f46a260c2"),
        "freebsd_386": ("go1.9.5.freebsd-386.tar.gz", "9f8f7ad7249b26dc7bc8fdd335d89c1cae3de3232ac6c5053171eba9b5923a0a"),
        "freebsd_amd64": ("go1.9.5.freebsd-amd64.tar.gz", "141728cdde1adcb097f252d51aebbcff5e45e30f56bf066fcb158474c293c388"),
        "linux_arm64": ("go1.9.5.linux-arm64.tar.gz", "d0bb265559cd8613882e6bbd197a80ed7090684117c6fc6900aa58dea2463715"),
        "linux_ppc64le": ("go1.9.5.linux-ppc64le.tar.gz", "dfd928ab818f72b801273c669d86e6c05626f2c2addc1c7178bb715fc608daf2"),
        "linux_s390x": ("go1.9.5.linux-s390x.tar.gz", "82c86885c8cc4d62ff81f828529c72cacd0ca8b02d442dc659858c6738363775"),
    },
    "1.9.4": {
        "darwin_amd64": ("go1.9.4.darwin-amd64.tar.gz", "0e694bfa289453ecb056cc70456e42fa331408cfa6cc985a14edb01d8b4fec51"),
        "linux_386": ("go1.9.4.linux-386.tar.gz", "d440aee90dad851630559bcee2b767b543ce7e54f45162908f3e12c3489888ab"),
        "linux_amd64": ("go1.9.4.linux-amd64.tar.gz", "15b0937615809f87321a457bb1265f946f9f6e736c563d6c5e0bd2c22e44f779"),
        "linux_armv6l": ("go1.9.4.linux-armv6l.tar.gz", "3c8cf3f79754a9fd6b33e2d8f930ee37d488328d460065992c72bc41c7b41a49"),
        "windows_386": ("go1.9.4.windows-386.zip", "ad5905b211e543a1e59758acd4c6f30d446e5af8c4ea997961caf1ef02cdd56d"),
        "windows_amd64": ("go1.9.4.windows-amd64.zip", "880e011ac6f4a509308a62ec6d963dd9d561d0cdc705e93d81c750d7f1c696f4"),
        "freebsd_386": ("go1.9.4.freebsd-386.tar.gz", "ca5874943d1fe5f9698594f65bb4d82f9e0f7ca3a09b1c306819df6f7349fd17"),
        "freebsd_amd64": ("go1.9.4.freebsd-amd64.tar.gz", "d91c3dc997358af47fc0070c09586b3e7aa47282a75169fa6b00d9ac3ca61d89"),
        "linux_arm64": ("go1.9.4.linux-arm64.tar.gz", "41a71231e99ccc9989867dce2fcb697921a68ede0bd06fc288ab6c2f56be8864"),
        "linux_ppc64le": ("go1.9.4.linux-ppc64le.tar.gz", "8b25484a7b4b6db81b3556319acf9993cc5c82048c7f381507018cb7c35e746b"),
        "linux_s390x": ("go1.9.4.linux-s390x.tar.gz", "129f23b13483b1a7ccef49bc4319daf25e1b306f805780fdb5526142985edb68"),
    },
    "1.9.3": {
        "darwin_amd64": ("go1.9.3.darwin-amd64.tar.gz", "f84b39c2ed7df0c2f1648e2b90b2198a6783db56b53700dabfa58afd6335d324"),
        "linux_386": ("go1.9.3.linux-386.tar.gz", "bc0782ac8116b2244dfe2a04972bbbcd7f1c2da455a768ab47b32864bcd0d49d"),
        "linux_amd64": ("go1.9.3.linux-amd64.tar.gz", "a4da5f4c07dfda8194c4621611aeb7ceaab98af0b38bfb29e1be2ebb04c3556c"),
        "linux_armv6l": ("go1.9.3.linux-armv6l.tar.gz", "926d6cd6c21ef3419dca2e5da8d4b74b99592ab1feb5a62a4da244e6333189d2"),
        "windows_386": ("go1.9.3.windows-386.zip", "cab7d4e008adefed322d36dee87a4c1775ab60b25ce587a2b55d90c75d0bafbc"),
        "windows_amd64": ("go1.9.3.windows-amd64.zip", "4eee59bb5b70abc357aebd0c54f75e46322eb8b58bbdabc026fdd35834d65e1e"),
        "freebsd_386": ("go1.9.3.freebsd-386.tar.gz", "a755739e3be0415344d62ea3b168bdcc9a54f7862ac15832684ff2d3e8127a03"),
        "freebsd_amd64": ("go1.9.3.freebsd-amd64.tar.gz", "f95066089a88749c45fae798422d04e254fe3b622ff030d12bdf333402b186ec"),
        "linux_arm64": ("go1.9.3.linux-arm64.tar.gz", "065d79964023ccb996e9dbfbf94fc6969d2483fbdeeae6d813f514c5afcd98d9"),
        "linux_ppc64le": ("go1.9.3.linux-ppc64le.tar.gz", "c802194b1af0cd904689923d6d32f3ed68f9d5f81a3e4a82406d9ce9be163681"),
        "linux_s390x": ("go1.9.3.linux-s390x.tar.gz", "85e9a257664f84154e583e0877240822bb2fe4308209f5ff57d80d16e2fb95c5"),
    },
    "1.9.2": {
        "darwin_amd64": ("go1.9.2.darwin-amd64.tar.gz", "73fd5840d55f5566d8db6c0ffdd187577e8ebe650c783f68bd27cbf95bde6743"),
        "linux_386": ("go1.9.2.linux-386.tar.gz", "574b2c4b1a248e58ef7d1f825beda15429610a2316d9cbd3096d8d3fa8c0bc1a"),
        "linux_amd64": ("go1.9.2.linux-amd64.tar.gz", "de874549d9a8d8d8062be05808509c09a88a248e77ec14eb77453530829ac02b"),
        "linux_armv6l": ("go1.9.2.linux-armv6l.tar.gz", "8a6758c8d390e28ef2bcea511f62dcb43056f38c1addc06a8bc996741987e7bb"),
        "windows_386": ("go1.9.2.windows-386.zip", "35d3be5d7b97c6d11ffb76c1b19e20a824e427805ee918e82c08a2e5793eda20"),
        "windows_amd64": ("go1.9.2.windows-amd64.zip", "682ec3626a9c45b657c2456e35cadad119057408d37f334c6c24d88389c2164c"),
        "freebsd_386": ("go1.9.2.freebsd-386.tar.gz", "809dcb0a8457c8d0abf954f20311a1ee353486d0ae3f921e9478189721d37677"),
        "freebsd_amd64": ("go1.9.2.freebsd-amd64.tar.gz", "8be985c3e251c8e007fa6ecd0189bc53e65cc519f4464ddf19fa11f7ed251134"),
        "linux_arm64": ("go1.9.2.linux-arm64.tar.gz", "0016ac65ad8340c84f51bc11dbb24ee8265b0a4597dbfdf8d91776fc187456fa"),
        "linux_ppc64le": ("go1.9.2.linux-ppc64le.tar.gz", "adb440b2b6ae9e448c253a20836d8e8aa4236f731d87717d9c7b241998dc7f9d"),
        "linux_s390x": ("go1.9.2.linux-s390x.tar.gz", "a7137b4fbdec126823a12a4b696eeee2f04ec616e9fb8a54654c51d5884c1345"),
    },
    "1.9.1": {
        "darwin_amd64": ("go1.9.1.darwin-amd64.tar.gz", "59bc6deee2969dddc4490b684b15f63058177f5c7e27134c060288b7d76faab0"),
        "linux_386": ("go1.9.1.linux-386.tar.gz", "2cea1ce9325cb40839601b566bc02b11c92b2942c21110b1b254c7e72e5581e7"),
        "linux_amd64": ("go1.9.1.linux-amd64.tar.gz", "07d81c6b6b4c2dcf1b5ef7c27aaebd3691cdb40548500941f92b221147c5d9c7"),
        "linux_armv6l": ("go1.9.1.linux-armv6l.tar.gz", "65a0495a50c7c240a6487b1170939586332f6c8f3526abdbb9140935b3cff14c"),
        "windows_386": ("go1.9.1.windows-386.zip", "ea9c79c9e6214c9a78a107ef5a7bff775a281bffe8c2d50afa66d2d33998078a"),
        "windows_amd64": ("go1.9.1.windows-amd64.zip", "8dc72a3881388e4e560c2e45f6be59860b623ad418e7da94e80fee012221cc81"),
        "freebsd_386": ("go1.9.1.freebsd-386.tar.gz", "0da7ad96606a8ceea85652eb20816077769d51de9219d85b9b224a3390070c50"),
        "freebsd_amd64": ("go1.9.1.freebsd-amd64.tar.gz", "c4eeacbb94821c5f252897a4d49c78293eaa97b29652d789dce9e79bc6aa6163"),
        "linux_arm64": ("go1.9.1.linux-arm64.tar.gz", "d31ecae36efea5197af271ccce86ccc2baf10d2e04f20d0fb75556ecf0614dad"),
        "linux_ppc64le": ("go1.9.1.linux-ppc64le.tar.gz", "de57b6439ce9d4dd8b528599317a35fa1e09d6aa93b0a80e3945018658d963b8"),
        "linux_s390x": ("go1.9.1.linux-s390x.tar.gz", "9adf03574549db82a72e0d721ef2178ec5e51d1ce4f309b271a2bca4dcf206f6"),
    },
    "1.9": {
        "darwin_amd64": ("go1.9.darwin-amd64.tar.gz", "c2df361ec6c26fcf20d5569496182cb20728caa4d351bc430b2f0f1212cca3e0"),
        "linux_386": ("go1.9.linux-386.tar.gz", "7cccff99dacf59162cd67f5b11070d667691397fd421b0a9ad287da019debc4f"),
        "linux_amd64": ("go1.9.linux-amd64.tar.gz", "d70eadefce8e160638a9a6db97f7192d8463069ab33138893ad3bf31b0650a79"),
        "linux_armv6l": ("go1.9.linux-armv6l.tar.gz", "f52ca5933f7a8de2daf7a3172b0406353622c6a39e67dd08bbbeb84c6496f487"),
        "windows_386": ("go1.9.windows-386.zip", "ecfe6f5be56acedc56cd9ff735f239a12a7c94f40b0ea9753bbfd17396f5e4b9"),
        "windows_amd64": ("go1.9.windows-amd64.zip", "874b144b994643cff1d3f5875369d65c01c216bb23b8edddf608facc43966c8b"),
        "freebsd_386": ("go1.9.freebsd-386.tar.gz", "9e415e340eaea526170b0fd59aa55939ff4f76c126193002971e8c6799e2ed3a"),
        "freebsd_amd64": ("go1.9.freebsd-amd64.tar.gz", "ba54efb2223fb4145604dcaf8605d519467f418ab02c081d3cd0632b6b43b6e7"),
        "linux_ppc64le": ("go1.9.linux-ppc64le.tar.gz", "10b66dae326b32a56d4c295747df564616ec46ed0079553e88e39d4f1b2ae985"),
        "linux_arm64": ("go1.9.linux-arm64.tar.gz", "0958dcf454f7f26d7acc1a4ddc34220d499df845bc2051c14ff8efdf1e3c29a6"),
        "linux_s390x": ("go1.9.linux-s390x.tar.gz", "e06231e4918528e2eba1d3cff9bc4310b777971e5d8985f9772c6018694a3af8"),
    },
}

def _generate_toolchains():
    # Use all the above information to generate all the possible toolchains we might support
    toolchains = []
    for host_goos, host_goarch in GOOS_GOARCH:
        host = "{}_{}".format(host_goos, host_goarch)
        for target_goos, target_goarch in GOOS_GOARCH:
            target = "{}_{}".format(target_goos, target_goarch)
            toolchain_name = "go_{}".format(host)
            if host != target:
                toolchain_name += "_cross_" + target
            link_flags = []
            cgo_link_flags = []
            if "darwin" in host:
                cgo_link_flags.extend(["-shared", "-Wl,-all_load"])
            if "linux" in host:
                cgo_link_flags.append("-Wl,-whole-archive")

            # Add the primary toolchain
            toolchains.append(dict(
                name = toolchain_name,
                host = host,
                target = target,
                link_flags = link_flags,
                cgo_link_flags = cgo_link_flags,
            ))
    return toolchains

_toolchains = _generate_toolchains()

_label_prefix = "@io_bazel_rules_go//go/toolchain:"

def go_register_toolchains(go_version = DEFAULT_VERSION):
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

    # Use the final dictionaries to register all the toolchains
    for toolchain in _toolchains:
        name = _label_prefix + toolchain["name"]
        native.register_toolchains(name)

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

def declare_toolchains():
    # Use the final dictionaries to create all the toolchains
    for toolchain in _toolchains:
        go_toolchain(
            # Required fields
            name = toolchain["name"],
            host = toolchain["host"],
            target = toolchain["target"],
            # Optional fields
            link_flags = toolchain["link_flags"],
            cgo_link_flags = toolchain["cgo_link_flags"],
        )
