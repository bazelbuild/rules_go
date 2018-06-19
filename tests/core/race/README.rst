race instrumentation
====================

race_auto_test
--------------

Triggers a data race inside of a test but does not explicitly enable race mode.
Should pass if race instrumentation is disabled.

race_on_test
------------

Checks that race mode is actually enabled in binaries and tests that enable
it through an attribute by running a binary (``race_bin``) and a test
(``race_on_tester``) and verifying that they fail.

Also checks that the ``race`` tag is enabled in the test itself and in
a library.

race_feature_test
-----------------

Checks that race mode can be enabled with ``--features=race`` by running
``race_auto_test`` with that flag and verifying that it fails.

