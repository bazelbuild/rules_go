Nogo flags
==========

Tests that verify the nogo Starlark flag interacts correctly with the setting
from ``go_register_nogo``.

flag_test
---------
Verifies that nogo may be set either in ``go_register_nogo`` (via
``go_register_toolchains`` or on the command line. The command line flag
takes precedence.
