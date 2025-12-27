#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD c4e40d991c28be51de9ac560ce895ac7f9b14924 >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff c4e40d991c28be51de9ac560ce895ac7f9b14924
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/xarray/tests/test_swap_dims.py b/xarray/tests/test_swap_dims.py
new file mode 100644
index 00000000..ade5683a
--- /dev/null
+++ b/xarray/tests/test_swap_dims.py
@@ -0,0 +1,35 @@
+import numpy as np
+import pytest
+import xarray as xr
+
+
+def test_swap_dims_inplace_modification():
+    """
+    Regression test for GH6795, where .swap_dims() can modify
+    the original object in certain cases.
+    """
+    nz = 11
+    ds = xr.Dataset(
+        data_vars={
+            "y": ("z", np.random.rand(nz)),
+            "lev": ("z", np.arange(nz) * 10),
+        },
+    )
+
+    # This sequence of operations, taken from the bug report, creates a
+    # Dataset that looks like the original but triggers the bug.
+    ds2 = (
+        ds.swap_dims(z="lev")
+        .rename_dims(lev="z")
+        .reset_index("lev")
+        .reset_coords()
+    )
+
+    # This call to .swap_dims() should return a new, modified Dataset
+    # and leave `ds2` unchanged.
+    ds2.swap_dims(z="lev")
+
+    # The bug is that the dimensions of the 'lev' DataArray within `ds2`
+    # are modified in place. The assertion checks that the dimensions
+    # remain unchanged.
+    assert ds2["lev"].dims == ("z",)

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(xarray/core/dataset\.py|xarray/core/variable\.py)' -m pytest --no-header -rA  -p no:cacheprovider xarray/tests/test_swap_dims.py
cat coverage.cover
git checkout c4e40d991c28be51de9ac560ce895ac7f9b14924
git apply /root/pre_state.patch
