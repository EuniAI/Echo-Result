#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD e05fddea852d08fc0845f954b79deb9e9f9ff883 >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff e05fddea852d08fc0845f954b79deb9e9f9ff883
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/xarray/core/nanops.py b/xarray/core/nanops.py
--- a/xarray/core/nanops.py
+++ b/xarray/core/nanops.py
@@ -26,13 +26,9 @@ def _maybe_null_out(result, axis, mask, min_count=1):
     """
     xarray version of pandas.core.nanops._maybe_null_out
     """
-    if hasattr(axis, "__len__"):  # if tuple or list
-        raise ValueError(
-            "min_count is not available for reduction with more than one dimensions."
-        )
 
     if axis is not None and getattr(result, "ndim", False):
-        null_mask = (mask.shape[axis] - mask.sum(axis) - min_count) < 0
+        null_mask = (np.take(mask.shape, axis).prod() - mask.sum(axis) - min_count) < 0
         if null_mask.any():
             dtype, fill_value = dtypes.maybe_promote(result.dtype)
             result = result.astype(dtype)

EOF_114329324912
git apply -v - <<'EOF_114329324912'
diff --git a/xarray/tests/test_nanops.py b/xarray/tests/test_nanops.py
new file mode 100644
index 00000000..df518092
--- /dev/null
+++ b/xarray/tests/test_nanops.py
@@ -0,0 +1,17 @@
+import numpy as np
+import xarray as xr
+from xarray.testing import assert_equal
+
+
+def test_sum_min_count_multiple_dims():
+    """
+    Test sum with min_count over multiple dimensions.
+
+    Regression test for https://github.com/pydata/xarray/issues/4352, where
+    sum() with min_count would raise an error when reducing over multiple
+    dimensions.
+    """
+    da = xr.DataArray([[1.0, 2.0, 3.0], [4.0, 5.0, 6.0]])
+    actual = da.sum(dim=["dim_0", "dim_1"], min_count=1)
+    expected = xr.DataArray(21.0)
+    assert_equal(actual, expected)

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(xarray/core/nanops\.py)' -m pytest --no-header -rA  -p no:cacheprovider xarray/tests/test_nanops.py
cat coverage.cover
git checkout e05fddea852d08fc0845f954b79deb9e9f9ff883
git apply /root/pre_state.patch
