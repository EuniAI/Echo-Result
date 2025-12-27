#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 97fc1154992f64cfb2f86321155a7404efeb2d8a >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 97fc1154992f64cfb2f86321155a7404efeb2d8a
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/lib/mpl_toolkits/tests/test_axes3d.py b/lib/mpl_toolkits/tests/test_axes3d.py
new file mode 100644
index 0000000000..7063c643a3
--- /dev/null
+++ b/lib/mpl_toolkits/tests/test_axes3d.py
@@ -0,0 +1,19 @@
+import matplotlib.pyplot as plt
+import pytest
+from mpl_toolkits.mplot3d import Axes3D
+
+
+def test_set_visible_3d():
+    """
+    Tests that set_visible(False) makes a 3D axes invisible.
+
+    Regression test for a bug where ``ax.set_visible(False)`` was not
+    respected for 3D axes.
+    """
+    fig = plt.figure()
+    ax = fig.add_subplot(projection='3d')
+    ax.set_visible(False)
+    fig.canvas.draw()
+    # A point in the middle of the figure.
+    x, y = fig.bbox.width / 2, fig.bbox.height / 2
+    assert fig.canvas.inaxes((x, y)) is None

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(lib/mpl_toolkits/mplot3d/axes3d\.py)' -m pytest --no-header -rA  -p no:cacheprovider lib/mpl_toolkits/tests/test_axes3d.py
cat coverage.cover
git checkout 97fc1154992f64cfb2f86321155a7404efeb2d8a
git apply /root/pre_state.patch
