#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD cb828ebe70b4fa35cd5f9a7ee024272237eab351 >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff cb828ebe70b4fa35cd5f9a7ee024272237eab351
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/testing/test_patch_numpy.py b/testing/test_patch_numpy.py
new file mode 100644
index 000000000..f99a31f6f
--- /dev/null
+++ b/testing/test_patch_numpy.py
@@ -0,0 +1,19 @@
+import pytest
+
+def test_patch_with_numpy_array(testdir):
+    """
+    Test that patching with a numpy array doesn't break collection (#3245).
+    """
+    pytest.importorskip("numpy")
+    testdir.makepyfile(
+        """
+        import numpy as np
+        from unittest.mock import patch
+
+        @patch('sys.version', new=np.array([-5.5, 3.0]))
+        def test_patched_with_array():
+            pass
+    """
+    )
+    result = testdir.runpytest()
+    result.assert_outcomes(passed=1)

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(src/_pytest/compat\.py)' -m pytest -rA testing/test_patch_numpy.py
cat coverage.cover
git checkout cb828ebe70b4fa35cd5f9a7ee024272237eab351
git apply /root/pre_state.patch
