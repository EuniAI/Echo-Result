#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 7f7a36478abe7dd1fa993b115d22606aa0e35e88 >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 7f7a36478abe7dd1fa993b115d22606aa0e35e88
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/testing/test_dynamic_xfail.py b/testing/test_dynamic_xfail.py
new file mode 100644
index 000000000..e92ec5522
--- /dev/null
+++ b/testing/test_dynamic_xfail.py
@@ -0,0 +1,23 @@
+import pytest
+
+
+def test_dynamic_xfail_in_test(testdir):
+    """
+    Test that dynamically adding an xfail marker inside a test function
+    correctly marks the test as xfailed.
+    This was a regression in pytest 6.0.
+    """
+    testdir.makepyfile(
+        """
+        import pytest
+
+        def test_xfail_test(request):
+            mark = pytest.mark.xfail(reason="xfail")
+            request.node.add_marker(mark)
+            assert 0
+        """
+    )
+    result = testdir.runpytest()
+    result.stdout.fnmatch_lines([
+        "*= 1 xfailed *",
+    ])

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(src/_pytest/skipping\.py)' -m pytest -rA testing/test_dynamic_xfail.py
cat coverage.cover
git checkout 7f7a36478abe7dd1fa993b115d22606aa0e35e88
git apply /root/pre_state.patch
