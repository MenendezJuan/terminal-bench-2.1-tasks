# no-op evidence (TEMPLATE)

A full Harbor trial directory from `--agent nop`, the null agent that changes
nothing. Copy it whole.

Must contain `verifier/reward.txt` = `0`.

**Read `error.txt`.** It has to name a TEST FAILURE COUNT. If it reports an
infrastructure error, or if the oracle and no-op produce identical output, the
environment is broken and the task measures nothing.

This is a known failure mode: an image missing a native library makes both
controls fail identically, with far fewer tests collected than the floor. No
structural check catches it. Only reading this file does.

The failure count should equal the number of tests the fix is expected to turn
green. If it does not, the verifier and the task disagree about what is graded.
