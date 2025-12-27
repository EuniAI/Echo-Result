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
diff --git a/astropy/timeseries/tests/test_issue_13033.py b/astropy/timeseries/tests/test_issue_13033.py
new file mode 100644
index 0000000000..853313b154
--- /dev/null
+++ b/astropy/timeseries/tests/test_issue_13033.py
@@ -0,0 +1,17 @@
+import pytest
+import numpy as np
+
+from astropy.time import Time
+from astropy.timeseries import TimeSeries
+
+
+def test_remove_required_column_exception():
+    """
+    Test for a helpful exception when removing a required column.
+    Regression test for https://github.com/astropy/astropy/issues/13033
+    """
+    time = Time(np.arange(100000, 100003), format='jd')
+    ts = TimeSeries(time=time, data={"flux": [99.9, 99.8, 99.7]})
+    ts._required_columns = ["time", "flux"]
+    with pytest.raises(ValueError, match=r"missing required columns?: \['flux'\]"):
+        ts.remove_column("flux")

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(astropy/timeseries/core\.py)' -m pytest --no-header -rA  -p no:cacheprovider astropy/timeseries/tests/test_issue_13033.py
cat coverage.cover
git checkout 298ccb478e6bf092953bca67a3d29dc6c35f6752
git apply /root/pre_state.patch
