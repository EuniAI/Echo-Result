#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD f0632c0fc7339f68e992ed63ae4cfac76cd41aad >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff f0632c0fc7339f68e992ed63ae4cfac76cd41aad
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/tests/test_datetime_tex_spacing.py b/tests/test_datetime_tex_spacing.py
new file mode 100644
index 0000000000..f2a2dd7c10
--- /dev/null
+++ b/tests/test_datetime_tex_spacing.py
@@ -0,0 +1,21 @@
+import datetime
+import pytest
+import matplotlib.dates as mdates
+
+
+def test_datetime_tex_spacing():
+    r"""
+    Test that with usetex=True, the colons in datetimes are spaced correctly.
+
+    The bug is that colons are interpreted as binary relations, and thus
+    get too much space around them. The fix is to wrap them in ``\mathord{}``.
+    """
+    # A DateFormatter with a format that has a colon.
+    formatter = mdates.DateFormatter('%H:%M', usetex=True)
+    # We can pass any date number; 0 is the epoch (1970-01-01 00:00:00).
+    formatted_string = formatter(0)
+
+    # This is the string that should be produced with the fix.
+    # Without the fix, it would be '$\mathdefault{00:00}$'.
+    expected = '$\mathdefault{00\mathord{:}00}$'
+    assert formatted_string == expected

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(lib/matplotlib/dates\.py)' -m pytest --no-header -rA  -p no:cacheprovider tests/test_datetime_tex_spacing.py
cat coverage.cover
git checkout f0632c0fc7339f68e992ed63ae4cfac76cd41aad
git apply /root/pre_state.patch
