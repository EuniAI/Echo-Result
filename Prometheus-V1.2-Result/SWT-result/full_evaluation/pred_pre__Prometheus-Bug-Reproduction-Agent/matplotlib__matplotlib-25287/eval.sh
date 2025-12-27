#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD f8ffce6d44127d4ea7d6491262ab30046b03294b >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff f8ffce6d44127d4ea7d6491262ab30046b03294b
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/lib/matplotlib/tests/test_axes_offset_text.py b/lib/matplotlib/tests/test_axes_offset_text.py
new file mode 100644
index 0000000000..64f9f1942c
--- /dev/null
+++ b/lib/matplotlib/tests/test_axes_offset_text.py
@@ -0,0 +1,14 @@
+import matplotlib as mpl
+import matplotlib.pyplot as plt
+
+
+def test_offset_text_labelcolor_from_rcparam():
+    """
+    Test that the offset text color is determined by `ytick.labelcolor`
+    from rcParams, not `ytick.color`.
+    """
+    with mpl.rc_context({'ytick.labelcolor': 'red', 'ytick.color': 'blue'}):
+        fig, ax = plt.subplots()
+        ax.plot([1.01e9, 1.02e9, 1.03e9])
+        fig.canvas.draw()
+        assert ax.yaxis.get_offset_text().get_color() == 'red'

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(lib/matplotlib/axis\.py)' -m pytest --no-header -rA  -p no:cacheprovider lib/matplotlib/tests/test_axes_offset_text.py
cat coverage.cover
git checkout f8ffce6d44127d4ea7d6491262ab30046b03294b
git apply /root/pre_state.patch
