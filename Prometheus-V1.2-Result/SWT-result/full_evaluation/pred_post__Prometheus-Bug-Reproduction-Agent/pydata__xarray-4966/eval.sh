#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 37522e991a32ee3c0ad1a5ff8afe8e3eb1885550 >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 37522e991a32ee3c0ad1a5ff8afe8e3eb1885550
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/xarray/coding/variables.py b/xarray/coding/variables.py
--- a/xarray/coding/variables.py
+++ b/xarray/coding/variables.py
@@ -316,6 +316,14 @@ def decode(self, variable, name=None):
                     if "_FillValue" in attrs:
                         new_fill = unsigned_dtype.type(attrs["_FillValue"])
                         attrs["_FillValue"] = new_fill
+            elif data.dtype.kind == "u":
+                if unsigned == "false":
+                    signed_dtype = np.dtype("i%s" % data.dtype.itemsize)
+                    transform = partial(np.asarray, dtype=signed_dtype)
+                    data = lazy_elemwise_func(data, transform, signed_dtype)
+                    if "_FillValue" in attrs:
+                        new_fill = signed_dtype.type(attrs["_FillValue"])
+                        attrs["_FillValue"] = new_fill
             else:
                 warnings.warn(
                     "variable %r has _Unsigned attribute but is not "

EOF_114329324912
git apply -v - <<'EOF_114329324912'
diff --git a/xarray/tests/test_coding_variables.py b/xarray/tests/test_coding_variables.py
new file mode 100644
index 00000000..5e65f0fe
--- /dev/null
+++ b/xarray/tests/test_coding_variables.py
@@ -0,0 +1,32 @@
+import numpy as np
+import pytest
+
+import xarray as xr
+from xarray.coding import variables
+from xarray.conventions import decode_cf_variable
+from xarray.testing import assert_identical
+
+
+def test_decode_signed_from_unsigned_opendap():
+    """
+    Test decoding of signed integer data stored as unsigned integers
+    with _Unsigned='false', a convention used by OPeNDAP.
+
+    This is to reproduce the issue where xarray does not correctly
+    interpret unsigned bytes as signed when `_Unsigned = 'false'` is set,
+    which is a pattern encountered with pydap.
+    """
+    original = xr.Variable(
+        ("x",),
+        np.array([128, 255, 0, 1, 127], dtype="u1"),
+        {"_Unsigned": "false"},
+    )
+    expected = xr.Variable(
+        ("x",),
+        np.array([-128, -1, 0, 1, 127], dtype="i1"),
+    )
+
+    coder = variables.UnsignedIntegerCoder()
+    decoded = coder.decode(original, name="test")
+
+    assert_identical(expected, decoded)

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(xarray/coding/variables\.py)' -m pytest --no-header -rA  -p no:cacheprovider xarray/tests/test_coding_variables.py
cat coverage.cover
git checkout 37522e991a32ee3c0ad1a5ff8afe8e3eb1885550
git apply /root/pre_state.patch
