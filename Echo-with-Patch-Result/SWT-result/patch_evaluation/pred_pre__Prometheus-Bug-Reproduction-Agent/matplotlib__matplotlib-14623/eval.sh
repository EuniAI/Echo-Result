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
diff --git a/tests/test_inverted_log_axis_limits.py b/tests/test_inverted_log_axis_limits.py
new file mode 100644
index 0000000000..a84b38ca3a
--- /dev/null
+++ b/tests/test_inverted_log_axis_limits.py
@@ -0,0 +1,22 @@
+import numpy as np
+import matplotlib.pyplot as plt
+import pytest
+
+
+def test_inverted_log_axis_limits():
+    """
+    Test that inverting a log-scaled axis using set_ylim works.
+
+    This is a regression test for a bug that prevented inverting a log-scaled
+    axis by setting the limits in reverse order.
+    """
+    y = np.linspace(1000e2, 1, 100)
+    x = np.exp(-np.linspace(0, 1, y.size))
+
+    fig, ax = plt.subplots()
+    ax.plot(x, y)
+    ax.set_yscale('log')
+    ax.set_ylim(y.max(), y.min())
+
+    ylim = ax.get_ylim()
+    assert ylim[0] > ylim[1]

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(lib/mpl_toolkits/mplot3d/axes3d\.py|lib/matplotlib/ticker\.py|lib/matplotlib/axes/_base\.py)' -m pytest --no-header -rA  -p no:cacheprovider tests/test_inverted_log_axis_limits.py
cat coverage.cover
git checkout d65c9ca20ddf81ef91199e6d819f9d3506ef477c
git apply /root/pre_state.patch
