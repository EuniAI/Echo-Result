#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD a41edc7bf5302f2ea327943c0c48c532b12009bc >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff a41edc7bf5302f2ea327943c0c48c532b12009bc
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/xarray/tests/test_merge_regressions.py b/xarray/tests/test_merge_regressions.py
new file mode 100644
index 00000000..a6b10175
--- /dev/null
+++ b/xarray/tests/test_merge_regressions.py
@@ -0,0 +1,17 @@
+import pytest
+import xarray as xr
+
+
+def test_merge_override_attrs_is_copy():
+    """
+    When merging with combine_attrs='override', the attributes should be
+    copied from the first object, not referenced.
+    Regression test for GH4565.
+    """
+    xds1 = xr.Dataset(attrs={"a": "b"})
+    xds2 = xr.Dataset(attrs={"a": "c"})
+
+    xds3 = xr.merge([xds1, xds2], combine_attrs="override")
+    xds3.attrs["a"] = "d"
+
+    assert xds1.attrs["a"] == "b"

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(xarray/core/merge\.py)' -m pytest --no-header -rA  -p no:cacheprovider xarray/tests/test_merge_regressions.py
cat coverage.cover
git checkout a41edc7bf5302f2ea327943c0c48c532b12009bc
git apply /root/pre_state.patch
