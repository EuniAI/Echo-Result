#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 7c4e2ac83f7b4306296ff9b7b51aaf016e5ad614 >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 7c4e2ac83f7b4306296ff9b7b51aaf016e5ad614
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/xarray/tests/test_setitem.py b/xarray/tests/test_setitem.py
new file mode 100644
index 00000000..b6dfadc9
--- /dev/null
+++ b/xarray/tests/test_setitem.py
@@ -0,0 +1,21 @@
+import numpy as np
+import pytest
+import xarray as xr
+
+
+def test_setitem_object_with_values_property():
+    """
+    Test that assigning an object with a `.values` property to a
+    DataArray of dtype=object does not coerce the type.
+    Regression test for GH1902.
+    """
+
+    class HasValues:
+        values = 5
+
+    bad_indexed = xr.DataArray([None])
+    obj_with_values = HasValues()
+
+    bad_indexed.loc[{"dim_0": 0}] = obj_with_values
+
+    assert bad_indexed.values[0] is obj_with_values

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(xarray/core/variable\.py)' -m pytest --no-header -rA  -p no:cacheprovider xarray/tests/test_setitem.py
cat coverage.cover
git checkout 7c4e2ac83f7b4306296ff9b7b51aaf016e5ad614
git apply /root/pre_state.patch
