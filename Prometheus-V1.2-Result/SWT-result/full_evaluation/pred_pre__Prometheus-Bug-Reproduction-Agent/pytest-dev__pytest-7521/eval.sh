#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 41d211c24a6781843b174379d6d6538f5c17adb9 >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 41d211c24a6781843b174379d6d6538f5c17adb9
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/testing/test_capfd_issue_7671.py b/testing/test_capfd_issue_7671.py
new file mode 100644
index 000000000..f0bd0f68e
--- /dev/null
+++ b/testing/test_capfd_issue_7671.py
@@ -0,0 +1,12 @@
+import pytest
+
+
+def test_capfd_preserves_carriage_return(capfd):
+    """
+    capfd.readouterr() should not convert \r to \n.
+
+    Regression test for https://github.com/pytest-dev/pytest/issues/7671
+    """
+    print("Greetings from DOS", end="\r")
+    out, err = capfd.readouterr()
+    assert out == "Greetings from DOS\r"

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(src/_pytest/capture\.py)' -m pytest -rA testing/test_capfd_issue_7671.py
cat coverage.cover
git checkout 41d211c24a6781843b174379d6d6538f5c17adb9
git apply /root/pre_state.patch
