#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD f0f133943d3e4f1e2e665291fe1c8f658a84cc09 >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff f0f133943d3e4f1e2e665291fe1c8f658a84cc09
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/lib/matplotlib/tests/test_stackplot.py b/lib/matplotlib/tests/test_stackplot.py
new file mode 100644
index 0000000000..ce4ef7e2a8
--- /dev/null
+++ b/lib/matplotlib/tests/test_stackplot.py
@@ -0,0 +1,23 @@
+import matplotlib.pyplot as plt
+import numpy as np
+import pytest
+
+
+def test_twinx_stackplot_datalim():
+    """
+    Test that dataLims of an Axes with a stackplot are not changed to inf
+    when plotting on a twinned Axes.
+    """
+    fig, ax1 = plt.subplots()
+
+    df1_index = ['16 May', '17 May']
+    df1_values = [-22.717708333333402, 26.584999999999937]
+    df2_values = [-0.08501399999999998, -2.9833019999999966]
+
+    ax1.stackplot(df1_index, df1_values)
+
+    ax2 = ax1.twinx()
+    ax2.plot(df1_index, df2_values)
+
+    # ax1's dataLim should not be changed to inf.
+    assert np.all(np.isfinite(ax1.dataLim.intervaly))

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(lib/matplotlib/axes/_base\.py)' -m pytest --no-header -rA  -p no:cacheprovider lib/matplotlib/tests/test_stackplot.py
cat coverage.cover
git checkout f0f133943d3e4f1e2e665291fe1c8f658a84cc09
git apply /root/pre_state.patch
