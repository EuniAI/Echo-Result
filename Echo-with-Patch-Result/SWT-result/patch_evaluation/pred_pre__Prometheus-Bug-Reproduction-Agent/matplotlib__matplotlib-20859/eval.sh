#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 64619e53e9d0ed417daba287ac0d3a06943a54d5 >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 64619e53e9d0ed417daba287ac0d3a06943a54d5
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/lib/matplotlib/tests/test_subfigure.py b/lib/matplotlib/tests/test_subfigure.py
new file mode 100644
index 0000000000..209d2feb87
--- /dev/null
+++ b/lib/matplotlib/tests/test_subfigure.py
@@ -0,0 +1,19 @@
+import matplotlib.pyplot as plt
+import pytest
+
+
+def test_subfigure_legend():
+    """
+    Test adding a legend to a subfigure.
+
+    This test reproduces a bug where calling `legend()` on a `SubFigure`
+    instance raises a TypeError. The fix is to allow `FigureBase` objects
+    (which `SubFigure` is a subclass of) to be parents of Legends.
+    """
+    subfig = plt.figure().subfigures()
+    ax = subfig.subplots()
+    ax.plot([0, 1, 2], [0, 1, 2], label="test")
+    # This should not raise a TypeError after the fix.
+    subfig.legend()
+    # A single assertion to check that the legend was created.
+    assert len(subfig.legends) == 1

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(lib/matplotlib/legend\.py)' -m pytest --no-header -rA  -p no:cacheprovider lib/matplotlib/tests/test_subfigure.py
cat coverage.cover
git checkout 64619e53e9d0ed417daba287ac0d3a06943a54d5
git apply /root/pre_state.patch
