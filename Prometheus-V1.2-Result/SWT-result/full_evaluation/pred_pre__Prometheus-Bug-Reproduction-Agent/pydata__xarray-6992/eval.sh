#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 45c0a114e2b7b27b83c9618bc05b36afac82183c >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 45c0a114e2b7b27b83c9618bc05b36afac82183c
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/xarray/tests/test_reset_index.py b/xarray/tests/test_reset_index.py
new file mode 100644
index 00000000..e427c85e
--- /dev/null
+++ b/xarray/tests/test_reset_index.py
@@ -0,0 +1,21 @@
+import numpy as np
+import xarray as xr
+
+
+def test_reset_index_drop_true_data_vars_len():
+    """
+    Regression test for GH5921.
+
+    This test ensures that creating a multi-index and then resetting it with
+    `drop=True` does not leave the Dataset in a corrupted state where
+    accessing the length of the data variables would fail.
+    """
+    ds = xr.Dataset(coords={"a": ("x", [1, 2, 3]), "b": ("x", ["a", "b", "c"])})
+    actual = ds.set_index(z=["a", "b"]).reset_index("z", drop=True)
+
+    # The bug causes `len(actual.data_vars)` to raise a `ValueError` because
+    # the internal `__len__` method returns a negative number. This test
+    # will fail with that `ValueError`.
+    # When the bug is fixed, `len(actual.data_vars)` will return a
+    # non-negative integer, and the assertion will pass.
+    assert len(actual.data_vars) >= 0

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(xarray/core/dataset\.py|xarray/core/indexes\.py)' -m pytest --no-header -rA  -p no:cacheprovider xarray/tests/test_reset_index.py
cat coverage.cover
git checkout 45c0a114e2b7b27b83c9618bc05b36afac82183c
git apply /root/pre_state.patch
