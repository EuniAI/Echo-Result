#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD cc183652bf6e1273e985e1c4b3cba79c896c1193 >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff cc183652bf6e1273e985e1c4b3cba79c896c1193
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/xarray/tests/test_zarr.py b/xarray/tests/test_zarr.py
new file mode 100644
index 00000000..fb35dab6
--- /dev/null
+++ b/xarray/tests/test_zarr.py
@@ -0,0 +1,24 @@
+import numpy as np
+import pytest
+import xarray as xr
+
+from xarray.tests import requires_zarr
+
+
+@requires_zarr
+def test_accessing_chunks_does_not_load_data(tmp_path):
+    """
+    Test that accessing the .chunks attribute does not load the entire
+    array into memory. Regression test for GH issue #6522.
+    """
+    ds = xr.Dataset({"foo": ("x", np.arange(10))})
+    store_path = tmp_path / "test.zarr"
+    ds.to_zarr(store_path)
+
+    with xr.open_dataset(store_path, engine="zarr") as actual:
+        assert not actual["foo"].variable._in_memory
+
+        # Accessing chunks should not load data from disk
+        _ = actual.chunks
+
+        assert not actual["foo"].variable._in_memory

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(xarray/core/common\.py)' -m pytest --no-header -rA  -p no:cacheprovider xarray/tests/test_zarr.py
cat coverage.cover
git checkout cc183652bf6e1273e985e1c4b3cba79c896c1193
git apply /root/pre_state.patch
