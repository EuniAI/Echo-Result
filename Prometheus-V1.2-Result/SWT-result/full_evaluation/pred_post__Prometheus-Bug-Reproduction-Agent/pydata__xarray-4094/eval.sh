#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD a64cf2d5476e7bbda099b34c40b7be1880dbd39a >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff a64cf2d5476e7bbda099b34c40b7be1880dbd39a
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/xarray/core/dataarray.py b/xarray/core/dataarray.py
--- a/xarray/core/dataarray.py
+++ b/xarray/core/dataarray.py
@@ -1961,7 +1961,7 @@ def to_unstacked_dataset(self, dim, level=0):
         # pull variables out of datarray
         data_dict = {}
         for k in variables:
-            data_dict[k] = self.sel({variable_dim: k}).squeeze(drop=True)
+            data_dict[k] = self.sel({variable_dim: k}, drop=True).squeeze(drop=True)
 
         # unstacked dataset
         return Dataset(data_dict)

EOF_114329324912
git apply -v - <<'EOF_114329324912'
diff --git a/xarray/tests/test_dataset_issue4034.py b/xarray/tests/test_dataset_issue4034.py
new file mode 100644
index 00000000..674114ee
--- /dev/null
+++ b/xarray/tests/test_dataset_issue4034.py
@@ -0,0 +1,23 @@
+import numpy as np
+import pytest
+
+import xarray as xr
+from xarray import DataArray, Dataset
+from xarray.tests import assert_identical
+
+
+class TestDataset:
+    def test_to_stacked_array_to_unstacked_dataset_single_dim(self):
+        """
+        Test roundtrip of to_stacked_array and to_unstacked_dataset for
+        a Dataset with only single-dimension variables.
+        Regression test for https://github.com/pydata/xarray/issues/4034
+        """
+        arr = xr.DataArray(
+            np.arange(3),
+            coords=[("x", [0, 1, 2])],
+        )
+        data = xr.Dataset({"a": arr, "b": arr})
+        stacked = data.to_stacked_array("y", sample_dims=["x"])
+        unstacked = stacked.to_unstacked_dataset("y")
+        assert_identical(data, unstacked)

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(xarray/core/dataarray\.py)' -m pytest --no-header -rA  -p no:cacheprovider xarray/tests/test_dataset_issue4034.py
cat coverage.cover
git checkout a64cf2d5476e7bbda099b34c40b7be1880dbd39a
git apply /root/pre_state.patch
