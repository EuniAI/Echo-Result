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
diff --git a/astropy/units/core.py b/astropy/units/core.py
--- a/astropy/units/core.py
+++ b/astropy/units/core.py
@@ -728,7 +728,7 @@ def __eq__(self, other):
         try:
             other = Unit(other, parse_strict='silent')
         except (ValueError, UnitsError, TypeError):
-            return False
+            return NotImplemented
 
         # Other is Unit-like, but the test below requires it is a UnitBase
         # instance; if it is not, give up (so that other can try).
@@ -1710,8 +1710,12 @@ def _unrecognized_operator(self, *args, **kwargs):
         _unrecognized_operator
 
     def __eq__(self, other):
-        other = Unit(other, parse_strict='silent')
-        return isinstance(other, UnrecognizedUnit) and self.name == other.name
+        try:
+            other = Unit(other, parse_strict='silent')
+        except (ValueError, UnitsError, TypeError):
+            return NotImplemented
+
+        return isinstance(other, type(self)) and self.name == other.name
 
     def __ne__(self, other):
         return not (self == other)

EOF_114329324912
git apply -v - <<'EOF_114329324912'
diff --git a/astropy/units/tests/test_regression.py b/astropy/units/tests/test_regression.py
new file mode 100644
index 0000000000..c3db65e1df
--- /dev/null
+++ b/astropy/units/tests/test_regression.py
@@ -0,0 +1,20 @@
+# -*- coding: utf-8 -*-
+# Licensed under a 3-clause BSD style license - see LICENSE.rst
+"""
+Regression tests for the units package
+"""
+
+import pytest
+from astropy import units as u
+
+
+def test_unrecognized_unit_compare_with_none():
+    """
+    Regression test for a TypeError when comparing an UnrecognizedUnit
+    with None. See #3108.
+    """
+    unrecognized = u.Unit('asdf', parse_strict='silent')
+    # We are deliberately not using `is None` here because that
+    # doesn't trigger the __eq__ method where the bug lies.
+    assert not (unrecognized == None)  # nopep8
+    assert unrecognized != None  # nopep8

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(astropy/units/core\.py)' -m pytest --no-header -rA  -p no:cacheprovider astropy/units/tests/test_regression.py
cat coverage.cover
git checkout 3cedd79e6c121910220f8e6df77c54a0b344ea94
git apply /root/pre_state.patch
