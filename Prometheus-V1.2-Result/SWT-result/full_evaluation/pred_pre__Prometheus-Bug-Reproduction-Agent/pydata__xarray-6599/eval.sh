#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 6bb2b855498b5c68d7cca8cceb710365d58e6048 >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 6bb2b855498b5c68d7cca8cceb710365d58e6048
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/xarray/tests/test_polyval.py b/xarray/tests/test_polyval.py
new file mode 100644
index 00000000..9f37f702
--- /dev/null
+++ b/xarray/tests/test_polyval.py
@@ -0,0 +1,55 @@
+import numpy as np
+import pytest
+import xarray as xr
+
+from xarray.testing import assert_allclose
+
+
+def test_polyval_timedelta_coord() -> None:
+    """
+    Test polyval with a timedelta64 coordinate.
+    Regression test for GH:6564.
+    """
+    values = np.array(
+        [
+            "2021-04-01T05:25:19.000000000",
+            "2021-04-01T05:25:29.000000000",
+            "2021-04-01T05:25:39.000000000",
+            "2021-04-01T05:25:49.000000000",
+            "2021-04-01T05:25:59.000000000",
+            "2021-04-01T05:26:09.000000000",
+        ],
+        dtype="datetime64[ns]",
+    )
+    azimuth_time = xr.DataArray(
+        values, name="azimuth_time", coords={"azimuth_time": values - values[0]}
+    )
+
+    polyfit_coefficients = xr.DataArray(
+        [
+            [2.33333335e-43, 1.62499999e-43, 2.79166678e-43],
+            [-1.15316667e-30, 1.49518518e-31, 9.08833333e-31],
+            [-2.50272583e-18, -1.23851062e-18, -2.99098229e-18],
+            [5.83965193e-06, -1.53321770e-07, -4.84640242e-06],
+            [4.44739216e06, 1.45053974e06, 5.29960857e06],
+        ],
+        dims=("degree", "axis"),
+        coords={"axis": [0, 1, 2], "degree": [4, 3, 2, 1, 0]},
+    )
+
+    actual = xr.polyval(azimuth_time, polyfit_coefficients)
+
+    expected = xr.DataArray(
+        [
+            [4447392.16, 1450539.74, 5299608.57],
+            [4505537.25588366, 1448882.82238152, 5250846.359196],
+            [4563174.92026797, 1446979.12250014, 5201491.44401733],
+            [4620298.31815291, 1444829.59596699, 5151549.377964],
+            [4676900.67053846, 1442435.23739315, 5101025.78153601],
+            [4732975.25442459, 1439797.08038974, 5049926.34223336],
+        ],
+        dims=("azimuth_time", "axis"),
+        coords={"azimuth_time": values, "axis": [0, 1, 2]},
+    )
+
+    assert_allclose(actual, expected)

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(xarray/core/computation\.py)' -m pytest --no-header -rA  -p no:cacheprovider xarray/tests/test_polyval.py
cat coverage.cover
git checkout 6bb2b855498b5c68d7cca8cceb710365d58e6048
git apply /root/pre_state.patch
