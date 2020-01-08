race instrumentation
====================

race_test
---------

Embeds a library that triggers a data race inside a binary and a test.
Verifies that no race is reported by default and a race is reported when either
target is build with the ``race = "on"`` attribute or the ``--features=race``
flag.
