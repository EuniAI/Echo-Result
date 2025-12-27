#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 19b088636eb7d3f65ab7a1046ac672e0689371d8 >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 19b088636eb7d3f65ab7a1046ac672e0689371d8
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/xarray/tests/test_weighted_mean_boolean.py b/xarray/tests/test_weighted_mean_boolean.py
new file mode 100644
index 00000000..bbe0a10d
--- /dev/null
+++ b/xarray/tests/test_weighted_mean_boolean.py
@@ -0,0 +1,18 @@
+import numpy as np
+import pytest
+
+import xarray as xr
+from xarray import DataArray
+from xarray.tests import assert_equal
+
+
+def test_weighted_mean_boolean_weights():
+    """
+    Test weighted mean with boolean weights.
+    This reproduces issue where boolean weights were not handled correctly.
+    """
+    dta = xr.DataArray([1.0, 1.0, 1.0])
+    wgt = xr.DataArray(np.array([1, 1, 0], dtype=bool))
+    result = dta.weighted(wgt).mean()
+    expected = xr.DataArray(1.0)
+    assert_equal(result, expected)

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(xarray/core/weighted\.py)' -m pytest --no-header -rA  -p no:cacheprovider xarray/tests/test_weighted_mean_boolean.py
cat coverage.cover
git checkout 19b088636eb7d3f65ab7a1046ac672e0689371d8
git apply /root/pre_state.patch
