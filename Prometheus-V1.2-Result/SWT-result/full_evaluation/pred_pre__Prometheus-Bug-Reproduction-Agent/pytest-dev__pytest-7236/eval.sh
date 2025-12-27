#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD c98bc4cd3d687fe9b392d8eecd905627191d4f06 >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff c98bc4cd3d687fe9b392d8eecd905627191d4f06
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/testing/test_unittest_skip_pdb.py b/testing/test_unittest_skip_pdb.py
new file mode 100644
index 000000000..08549b345
--- /dev/null
+++ b/testing/test_unittest_skip_pdb.py
@@ -0,0 +1,27 @@
+import pytest
+
+def test_teardown_on_skipped_test_with_pdb(testdir):
+    """
+    tearDown is executed on skipped tests when running --pdb.
+    """
+    testdir.makepyfile(
+        """
+        import unittest
+
+        class MyTestCase(unittest.TestCase):
+            def setUp(self):
+                xxx
+            @unittest.skip("hello")
+            def test_one(self):
+                pass
+            def tearDown(self):
+                xxx
+    """
+    )
+    result = testdir.runpytest("--pdb")
+
+    # The bug causes an ERROR because tearDown is called on the skipped test.
+    # A correct run should only show the test as skipped.
+    # assert_outcomes checks for exact counts, so it will fail if there are
+    # unexpected errors.
+    result.assert_outcomes(skipped=1)

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(src/_pytest/unittest\.py)' -m pytest -rA testing/test_unittest_skip_pdb.py
cat coverage.cover
git checkout c98bc4cd3d687fe9b392d8eecd905627191d4f06
git apply /root/pre_state.patch
