#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 6e7dc8bac831cd8cf7a53b08efa366bd84f0c0fe >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 6e7dc8bac831cd8cf7a53b08efa366bd84f0c0fe
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/testing/test_unittest_fixtures.py b/testing/test_unittest_fixtures.py
new file mode 100644
index 000000000..2154550b4
--- /dev/null
+++ b/testing/test_unittest_fixtures.py
@@ -0,0 +1,26 @@
+import pytest
+from _pytest.pytester import Pytester
+
+
+def test_unittest_setup_class_fixture_is_private(pytester: Pytester) -> None:
+    """
+    Check that unittest setUpClass fixtures are private.
+
+    The fixture generated for ``unittest.TestCase.setUpClass`` should
+    be considered "private" and not be displayed by ``--fixtures`` by default.
+    """
+    p = pytester.makepyfile(
+        """
+        import unittest
+
+        class Tests(unittest.TestCase):
+            @classmethod
+            def setUpClass(cls):
+                pass
+
+            def test_1(self):
+                pass
+        """
+    )
+    result = pytester.runpytest("--fixtures", p)
+    result.stdout.no_fnmatch_line("*unittest_setUpClass_fixture_Tests*")

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(src/_pytest/unittest\.py|src/_pytest/python\.py)' -m pytest -rA testing/test_unittest_fixtures.py
cat coverage.cover
git checkout 6e7dc8bac831cd8cf7a53b08efa366bd84f0c0fe
git apply /root/pre_state.patch
