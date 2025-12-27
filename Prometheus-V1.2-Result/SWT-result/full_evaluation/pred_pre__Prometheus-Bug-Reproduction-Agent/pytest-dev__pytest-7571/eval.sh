#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 422685d0bdc110547535036c1ff398b5e1c44145 >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 422685d0bdc110547535036c1ff398b5e1c44145
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/testing/logging/test_caplog.py b/testing/logging/test_caplog.py
new file mode 100644
index 000000000..6292fa42a
--- /dev/null
+++ b/testing/logging/test_caplog.py
@@ -0,0 +1,27 @@
+import logging
+
+import pytest
+
+
+def test_set_level_is_restored(testdir):
+    """
+    Tests that caplog.set_level() is restored at the end of the test.
+
+    This is a regression test for issue #7553, where the log level was
+    leaking between tests.
+    """
+    testdir.makepyfile(
+        """
+        import logging
+
+        def test_level_set(caplog):
+            caplog.set_level(42)
+
+        def test_level_restored(caplog):
+            assert caplog.handler.level == 0
+        """
+    )
+    result = testdir.runpytest()
+    # If the level is not restored, test_level_restored will fail,
+    # and runpytest will return a non-zero exit code.
+    assert result.ret == 0

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(src/_pytest/logging\.py)' -m pytest -rA testing/logging/test_caplog.py
cat coverage.cover
git checkout 422685d0bdc110547535036c1ff398b5e1c44145
git apply /root/pre_state.patch
