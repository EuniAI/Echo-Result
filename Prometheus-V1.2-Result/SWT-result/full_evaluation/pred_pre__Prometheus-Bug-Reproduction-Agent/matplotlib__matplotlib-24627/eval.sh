#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 9d22ab09d52d279b125d8770967569de070913b2 >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 9d22ab09d52d279b125d8770967569de070913b2
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/lib/matplotlib/tests/test_artist_lifecycle.py b/lib/matplotlib/tests/test_artist_lifecycle.py
new file mode 100644
index 0000000000..82c641fcb8
--- /dev/null
+++ b/lib/matplotlib/tests/test_artist_lifecycle.py
@@ -0,0 +1,26 @@
+import matplotlib.pyplot as plt
+from matplotlib.figure import Figure
+
+
+def test_cla_unsets_artist_parents():
+    """
+    Check that clearing an axes unsets the .axes and .figure attributes on the
+    artists that are removed, matching the behavior of artist.remove().
+    """
+    fig, ax = plt.subplots()
+    line, = ax.plot([1, 2])
+    ax.cla()
+    assert line.axes is None
+    assert line.figure is None
+
+
+def test_clf_unsets_artist_parents():
+    """
+    Check that clearing a figure unsets the .axes and .figure attributes on
+    the artists that are removed, matching the behavior of artist.remove().
+    """
+    fig, ax = plt.subplots()
+    line, = ax.plot([1, 2])
+    fig.clf()
+    assert line.axes is None
+    assert line.figure is None

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(lib/matplotlib/axes/_base\.py)' -m pytest --no-header -rA  -p no:cacheprovider lib/matplotlib/tests/test_artist_lifecycle.py
cat coverage.cover
git checkout 9d22ab09d52d279b125d8770967569de070913b2
git apply /root/pre_state.patch
