Boringcrypto
===========

Tests to ensure that support for building with boringcrypto is working as expected.

boringcrypto_test
--------------

Test that the build is failed if a non-local Go version less than 1.19 is requested to be built with
boringcrypto. Test that binaries built with boringcrypto stdlib have X:boringcrypto in version
information.