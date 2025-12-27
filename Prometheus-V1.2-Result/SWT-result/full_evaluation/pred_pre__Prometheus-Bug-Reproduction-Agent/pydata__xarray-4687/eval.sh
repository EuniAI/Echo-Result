#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD d3b6aa6d8b997df115a53c001d00222a0f92f63a >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff d3b6aa6d8b997df115a53c001d00222a0f92f63a
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/xarray/tests/test_where.py b/xarray/tests/test_where.py
new file mode 100644
index 00000000..dffe7be6
--- /dev/null
+++ b/xarray/tests/test_where.py
@@ -0,0 +1,15 @@
+import numpy as np
+import xarray as xr
+
+
+def test_where_preserves_attributes():
+    """
+    Test that xr.where preserves attributes of its arguments.
+    Regression test for https://github.com/pydata/xarray/issues/4139.
+    """
+    da = xr.DataArray(1)
+    da.attrs["foo"] = "bar"
+
+    result = xr.where(da == 0, -1, da)
+
+    assert da.attrs == result.attrs

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(xarray/core/computation\.py)' -m pytest --no-header -rA  -p no:cacheprovider xarray/tests/test_where.py
cat coverage.cover
git checkout d3b6aa6d8b997df115a53c001d00222a0f92f63a
git apply /root/pre_state.patch
