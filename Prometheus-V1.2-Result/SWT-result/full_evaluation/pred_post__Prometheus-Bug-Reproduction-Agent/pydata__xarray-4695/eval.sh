#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 51ef2a66c4e0896eab7d2b03e3dfb3963e338e3c >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 51ef2a66c4e0896eab7d2b03e3dfb3963e338e3c
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/xarray/core/dataarray.py b/xarray/core/dataarray.py
--- a/xarray/core/dataarray.py
+++ b/xarray/core/dataarray.py
@@ -196,7 +196,7 @@ def __getitem__(self, key) -> "DataArray":
             # expand the indexer so we can handle Ellipsis
             labels = indexing.expanded_indexer(key, self.data_array.ndim)
             key = dict(zip(self.data_array.dims, labels))
-        return self.data_array.sel(**key)
+        return self.data_array.sel(key)
 
     def __setitem__(self, key, value) -> None:
         if not utils.is_dict_like(key):

EOF_114329324912
git apply -v - <<'EOF_114329324912'
diff --git a/xarray/tests/test_loc.py b/xarray/tests/test_loc.py
new file mode 100644
index 00000000..0dcf4f21
--- /dev/null
+++ b/xarray/tests/test_loc.py
@@ -0,0 +1,24 @@
+import numpy as np
+import pytest
+from xarray import DataArray
+from xarray.testing import assert_identical
+
+
+def test_loc_with_method_dimension():
+    """
+    Test that .loc works with a dimension named "method".
+
+    This is a regression test for the bug where "method" was
+    being interpreted as a kwarg to the selection method,
+    rather than a dimension name.
+    """
+    data = DataArray(
+        np.zeros((2, 2)),
+        dims=["dim1", "method"],
+        coords={"dim1": ["x", "y"], "method": ["a", "b"]},
+    )
+    expected = DataArray(0.0, coords={"dim1": "x", "method": "a"})
+
+    actual = data.loc[dict(dim1="x", method="a")]
+
+    assert_identical(expected, actual)

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(xarray/core/dataarray\.py)' -m pytest --no-header -rA  -p no:cacheprovider xarray/tests/test_loc.py
cat coverage.cover
git checkout 51ef2a66c4e0896eab7d2b03e3dfb3963e338e3c
git apply /root/pre_state.patch
