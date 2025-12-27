#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 298ccb478e6bf092953bca67a3d29dc6c35f6752 >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 298ccb478e6bf092953bca67a3d29dc6c35f6752
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .[test] --verbose
git apply -v - <<'EOF_114329324912'
diff --git a/astropy/timeseries/core.py b/astropy/timeseries/core.py
--- a/astropy/timeseries/core.py
+++ b/astropy/timeseries/core.py
@@ -55,6 +55,13 @@ class BaseTimeSeries(QTable):
     _required_columns_relax = False
 
     def _check_required_columns(self):
+        def as_scalar_or_list_str(obj):
+            if not hasattr(obj, "__len__"):
+                return f"'{obj}'"
+            elif len(obj) == 1:
+                return f"'{obj[0]}'"
+            else:
+                return str(obj)
 
         if not self._required_columns_enabled:
             return
@@ -76,9 +83,10 @@ def _check_required_columns(self):
 
             elif self.colnames[:len(required_columns)] != required_columns:
 
-                raise ValueError("{} object is invalid - expected '{}' "
-                                 "as the first column{} but found '{}'"
-                                 .format(self.__class__.__name__, required_columns[0], plural, self.colnames[0]))
+                raise ValueError("{} object is invalid - expected {} "
+                                 "as the first column{} but found {}"
+                                 .format(self.__class__.__name__, as_scalar_or_list_str(required_columns),
+                                            plural, as_scalar_or_list_str(self.colnames[:len(required_columns)])))
 
             if (self._required_columns_relax
                     and self._required_columns == self.colnames[:len(self._required_columns)]):

EOF_114329324912
git apply -v - <<'EOF_114329324912'
diff --git a/astropy/timeseries/tests/test_core.py b/astropy/timeseries/tests/test_core.py
new file mode 100644
index 0000000000..164d7c5568
--- /dev/null
+++ b/astropy/timeseries/tests/test_core.py
@@ -0,0 +1,20 @@
+import pytest
+import numpy as np
+from astropy.time import Time
+from astropy.timeseries import TimeSeries
+
+
+def test_remove_required_column_error_message():
+    """
+    Test for a helpful error message when a required column is removed.
+
+    Regression test for a bug that caused a misleading ValueError when a
+    required column was removed from a TimeSeries. The error message should
+    clearly indicate which required column is missing.
+    """
+    time = Time(np.arange(100000, 100003), format='jd')
+    ts = TimeSeries(time=time, data={"flux": [99.9, 99.8, 99.7]})
+    ts._required_columns = ["time", "flux"]
+    with pytest.raises(ValueError) as exc:
+        ts.remove_column("flux")
+    assert exc.value.args[0] == "TimeSeries object is invalid - required column 'flux' is missing"

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(astropy/timeseries/core\.py)' -m pytest --no-header -rA  -p no:cacheprovider astropy/timeseries/tests/test_core.py
cat coverage.cover
git checkout 298ccb478e6bf092953bca67a3d29dc6c35f6752
git apply /root/pre_state.patch
