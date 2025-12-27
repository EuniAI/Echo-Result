#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD aa55975c7d3f6c9f6d7f68accc41bb7cadf0eb9a >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff aa55975c7d3f6c9f6d7f68accc41bb7cadf0eb9a
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/testing/logging/test_caplog.py b/testing/logging/test_caplog.py
new file mode 100644
index 000000000..27018a632
--- /dev/null
+++ b/testing/logging/test_caplog.py
@@ -0,0 +1,19 @@
+import logging
+import pytest
+
+
+def test_get_records_clear_conflict(caplog):
+    """
+    Verifies that get_records() is not decoupled from records after clear().
+
+    Regression test for #9923.
+    """
+
+    def verify_consistency() -> None:
+        assert caplog.get_records("call") == caplog.records
+
+    verify_consistency()
+    logging.warning("test")
+    verify_consistency()
+    caplog.clear()
+    verify_consistency()

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(src/_pytest/logging\.py)' -m pytest -rA testing/logging/test_caplog.py
cat coverage.cover
git checkout aa55975c7d3f6c9f6d7f68accc41bb7cadf0eb9a
git apply /root/pre_state.patch
