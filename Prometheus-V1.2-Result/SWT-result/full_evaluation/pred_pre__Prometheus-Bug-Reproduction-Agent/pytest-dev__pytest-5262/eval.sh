#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 58e6a09db49f34886ff13f3b7520dd0bcd7063cd >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 58e6a09db49f34886ff13f3b7520dd0bcd7063cd
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/testing/test_capture_encoded_file_mode.py b/testing/test_capture_encoded_file_mode.py
new file mode 100644
index 000000000..b40882b4a
--- /dev/null
+++ b/testing/test_capture_encoded_file_mode.py
@@ -0,0 +1,29 @@
+import os
+import sys
+
+import pytest
+
+
+@pytest.mark.skipif(not hasattr(os, "dup"), reason="test needs os.dup")
+def test_encoded_file_mode_is_text(testdir):
+    """
+    _pytest.capture.EncodedFile should not report a binary mode.
+
+    A stream may be opened in binary mode, but EncodedFile wraps it to
+    provide a text stream. This was causing problems with youtube-dl, which
+    would inspect the `mode` attribute and attempt to write bytes to the
+    stream, which is not supported by EncodedFile on Python 3.
+
+    See issue #4939.
+    """
+    testdir.makepyfile(
+        """
+        import sys
+
+        def test_mode():
+            assert 'b' not in sys.stdout.mode
+            assert 'b' not in sys.stderr.mode
+    """
+    )
+    result = testdir.runpytest()
+    result.assert_outcomes(passed=1)

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(src/_pytest/capture\.py)' -m pytest -rA testing/test_capture_encoded_file_mode.py
cat coverage.cover
git checkout 58e6a09db49f34886ff13f3b7520dd0bcd7063cd
git apply /root/pre_state.patch
