#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 3cedd79e6c121910220f8e6df77c54a0b344ea94 >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 3cedd79e6c121910220f8e6df77c54a0b344ea94
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .[test] --verbose
git apply -v - <<'EOF_114329324912'
diff --git a/astropy/units/tests/test_unrecognized_unit.py b/astropy/units/tests/test_unrecognized_unit.py
new file mode 100644
index 0000000000..613c6e0b3e
--- /dev/null
+++ b/astropy/units/tests/test_unrecognized_unit.py
@@ -0,0 +1,13 @@
+import pytest
+from astropy import units as u
+
+
+def test_unrecognized_unit_comparison_with_none():
+    """
+    Test that comparing an UnrecognizedUnit with None doesn't raise a
+    TypeError, but returns False. See #3108.
+    """
+    x = u.Unit('asdf', parse_strict='silent')
+    # We are deliberately not using `is None` here because that
+    # doesn't trigger the bug.
+    assert not (x == None)  # nopep8

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(astropy/units/core\.py)' -m pytest --no-header -rA  -p no:cacheprovider astropy/units/tests/test_unrecognized_unit.py
cat coverage.cover
git checkout 3cedd79e6c121910220f8e6df77c54a0b344ea94
git apply /root/pre_state.patch
