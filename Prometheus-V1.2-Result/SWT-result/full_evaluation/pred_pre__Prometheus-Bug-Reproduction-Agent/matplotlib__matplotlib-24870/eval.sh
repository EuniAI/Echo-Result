#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 6091437be9776139d3672cde28a19cbe6c09dcd5 >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 6091437be9776139d3672cde28a19cbe6c09dcd5
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/lib/matplotlib/tests/test_contour_boolean.py b/lib/matplotlib/tests/test_contour_boolean.py
new file mode 100644
index 0000000000..89b6ae34f6
--- /dev/null
+++ b/lib/matplotlib/tests/test_contour_boolean.py
@@ -0,0 +1,14 @@
+import numpy as np
+from numpy.testing import assert_array_almost_equal
+from matplotlib import pyplot as plt
+
+
+def test_contour_boolean_autolevels():
+    """
+    Test that contour() with a boolean array defaults levels to [0.5].
+    """
+    ii, jj = np.ogrid[:100, :100]
+    im = (ii + jj) % 20 < 10
+    fig, ax = plt.subplots()
+    cs = ax.contour(im)
+    assert_array_almost_equal(cs.levels, [0.5])

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(lib/matplotlib/contour\.py|lib/matplotlib/tri/_tricontour\.py)' -m pytest --no-header -rA  -p no:cacheprovider lib/matplotlib/tests/test_contour_boolean.py
cat coverage.cover
git checkout 6091437be9776139d3672cde28a19cbe6c09dcd5
git apply /root/pre_state.patch
