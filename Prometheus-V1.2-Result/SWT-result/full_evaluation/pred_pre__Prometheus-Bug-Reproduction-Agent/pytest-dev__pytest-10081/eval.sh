#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD da9a2b584eb7a6c7e924b2621ed0ddaeca0a7bea >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff da9a2b584eb7a6c7e924b2621ed0ddaeca0a7bea
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/testing/test_unittest_pdb.py b/testing/test_unittest_pdb.py
new file mode 100644
index 000000000..2a1ae43c3
--- /dev/null
+++ b/testing/test_unittest_pdb.py
@@ -0,0 +1,36 @@
+import pytest
+from _pytest.pytester import Pytester
+
+
+def test_pdb_unittest_skip_class_teardown(pytester: Pytester) -> None:
+    """
+    tearDown should not be called for a skipped unittest class with --pdb.
+
+    Regression test for pytest issue #7215.
+    """
+    pytester.makepyfile(
+        """
+        import unittest
+
+        @unittest.skip("hello")
+        class MyTestCase(unittest.TestCase):
+            def test_one(self):
+                pass
+            def tearDown(self):
+                # This tearDown should not be executed for a skipped class.
+                # The bug causes it to run when --pdb is used, leading to a NameError.
+                xxx
+        """
+    )
+
+    # Run pytest with --pdb in a non-interactive subprocess.
+    result = pytester.runpytest("--pdb")
+
+    # When the bug is fixed, the test is skipped and tearDown is not run.
+    # The result should be exactly one skipped test.
+    #
+    # When the bug is present, the tearDown method IS executed and raises a
+    # NameError. Pytest reports this as an error during teardown of a skipped
+    # test. This results in an outcome of `errors=1` and `skipped=1`.
+    # The assertion below will therefore fail because an unexpected error occurred.
+    result.assert_outcomes(skipped=1)

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(src/_pytest/unittest\.py)' -m pytest -rA testing/test_unittest_pdb.py
cat coverage.cover
git checkout da9a2b584eb7a6c7e924b2621ed0ddaeca0a7bea
git apply /root/pre_state.patch
