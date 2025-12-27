#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 69c7e01e5167a3137c285cb50d1978252bb8bcbf >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 69c7e01e5167a3137c285cb50d1978252bb8bcbf
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/xarray/tests/test_quantile.py b/xarray/tests/test_quantile.py
new file mode 100644
index 00000000..5a8a92fa
--- /dev/null
+++ b/xarray/tests/test_quantile.py
@@ -0,0 +1,11 @@
+import numpy as np
+import xarray as xr
+
+
+def test_quantile_keep_attrs():
+    """
+    Test that DataArray.quantile preserves attributes when keep_attrs=True.
+    """
+    da = xr.DataArray([0, 0], dims="x", attrs={"units": "K"})
+    out = da.quantile(0.9, dim="x", keep_attrs=True)
+    assert out.attrs == da.attrs

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(xarray/core/dataset\.py|xarray/core/variable\.py)' -m pytest --no-header -rA  -p no:cacheprovider xarray/tests/test_quantile.py
cat coverage.cover
git checkout 69c7e01e5167a3137c285cb50d1978252bb8bcbf
git apply /root/pre_state.patch
