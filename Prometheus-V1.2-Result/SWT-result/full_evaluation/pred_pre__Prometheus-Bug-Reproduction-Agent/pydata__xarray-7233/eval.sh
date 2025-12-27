#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 51d37d1be95547059251076b3fadaa317750aab3 >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 51d37d1be95547059251076b3fadaa317750aab3
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/xarray/tests/test_coarsen_nondim_coords.py b/xarray/tests/test_coarsen_nondim_coords.py
new file mode 100644
index 00000000..6019c94a
--- /dev/null
+++ b/xarray/tests/test_coarsen_nondim_coords.py
@@ -0,0 +1,16 @@
+import numpy as np
+import xarray as xr
+
+
+def test_coarsen_construct_keeps_nondim_coords():
+    """
+    Test that ds.Coarsen.construct does not demote non-dimensional
+    coordinates to variables.
+    """
+    da = xr.DataArray(np.arange(24), dims=["time"])
+    da = da.assign_coords(day=365 * da)
+    ds = da.to_dataset(name="T")
+
+    actual = ds.coarsen(time=12).construct(time=("year", "month"))
+
+    assert "day" in actual.coords

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(xarray/core/rolling\.py)' -m pytest --no-header -rA  -p no:cacheprovider xarray/tests/test_coarsen_nondim_coords.py
cat coverage.cover
git checkout 51d37d1be95547059251076b3fadaa317750aab3
git apply /root/pre_state.patch
