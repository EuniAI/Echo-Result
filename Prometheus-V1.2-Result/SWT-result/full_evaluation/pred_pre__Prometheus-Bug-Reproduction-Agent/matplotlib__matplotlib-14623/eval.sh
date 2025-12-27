#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD d65c9ca20ddf81ef91199e6d819f9d3506ef477c >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff d65c9ca20ddf81ef91199e6d819f9d3506ef477c
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/lib/matplotlib/tests/test_log_scale_inversion.py b/lib/matplotlib/tests/test_log_scale_inversion.py
new file mode 100644
index 0000000000..225560aa04
--- /dev/null
+++ b/lib/matplotlib/tests/test_log_scale_inversion.py
@@ -0,0 +1,21 @@
+import numpy as np
+import matplotlib.pyplot as plt
+import pytest
+
+
+def test_log_scale_inverted_ylim():
+    """
+    Test that setting inverted limits on a log scale axis inverts the axis.
+
+    For log scales, ``set_ylim(bottom, top)`` with ``bottom > top`` should result
+    in an inverted axis, but starting in v3.1.0 it does not.
+    """
+    fig, ax = plt.subplots()
+    y = np.linspace(1000e2, 1, 100)
+    x = np.exp(-np.linspace(0, 1, y.size))
+
+    ax.plot(x, y)
+    ax.set_yscale('log')
+    ax.set_ylim(y.max(), y.min())
+
+    assert ax.yaxis_inverted()

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(lib/mpl_toolkits/mplot3d/axes3d\.py|lib/matplotlib/axes/_base\.py|lib/matplotlib/ticker\.py)' -m pytest --no-header -rA  -p no:cacheprovider lib/matplotlib/tests/test_log_scale_inversion.py
cat coverage.cover
git checkout d65c9ca20ddf81ef91199e6d819f9d3506ef477c
git apply /root/pre_state.patch
