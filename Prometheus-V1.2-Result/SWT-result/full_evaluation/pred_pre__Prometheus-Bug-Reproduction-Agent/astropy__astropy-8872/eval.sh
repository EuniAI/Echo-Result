#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD b750a0e6ee76fb6b8a099a4d16ec51977be46bf6 >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff b750a0e6ee76fb6b8a099a4d16ec51977be46bf6
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .[test] --verbose
git apply -v - <<'EOF_114329324912'
diff --git a/astropy/units/tests/test_regression.py b/astropy/units/tests/test_regression.py
new file mode 100644
index 0000000000..ace4446d76
--- /dev/null
+++ b/astropy/units/tests/test_regression.py
@@ -0,0 +1,13 @@
+import pytest
+import numpy as np
+from astropy import units as u
+
+
+def test_float16_dtype_preservation():
+    """
+    Test that float16 quantities are not upgraded to float64.
+
+    Regression test for https://github.com/astropy/astropy/issues/6732
+    """
+    quantity = np.float16(1) * u.km
+    assert quantity.dtype == np.float16

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(astropy/units/quantity\.py)' -m pytest --no-header -rA  -p no:cacheprovider astropy/units/tests/test_regression.py
cat coverage.cover
git checkout b750a0e6ee76fb6b8a099a4d16ec51977be46bf6
git apply /root/pre_state.patch
