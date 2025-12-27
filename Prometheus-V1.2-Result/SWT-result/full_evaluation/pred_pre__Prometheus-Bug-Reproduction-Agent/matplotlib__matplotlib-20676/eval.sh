#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 6786f437df54ca7780a047203cbcfaa1db8dc542 >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 6786f437df54ca7780a047203cbcfaa1db8dc542
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/lib/matplotlib/tests/test_span_selector.py b/lib/matplotlib/tests/test_span_selector.py
new file mode 100644
index 0000000000..253db2fea0
--- /dev/null
+++ b/lib/matplotlib/tests/test_span_selector.py
@@ -0,0 +1,22 @@
+import pytest
+import matplotlib.pyplot as plt
+import matplotlib.widgets as widgets
+from numpy.testing import assert_allclose
+
+
+def test_span_selector_interactive_limits():
+    """
+    Check that creating an interactive SpanSelector does not change the axes
+    limits, specifically that it does not force them to include 0.
+    """
+    fig, ax = plt.subplots()
+    ax.plot([10, 20], [10, 20])
+    initial_xlim = ax.get_xlim()
+
+    # The onselect function can be a no-op lambda.
+    # The bug is triggered upon instantiation of the SpanSelector.
+    widgets.SpanSelector(ax, lambda min, max: None, "horizontal",
+                         interactive=True)
+
+    final_xlim = ax.get_xlim()
+    assert_allclose(final_xlim, initial_xlim)

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(lib/matplotlib/widgets\.py)' -m pytest --no-header -rA  -p no:cacheprovider lib/matplotlib/tests/test_span_selector.py
cat coverage.cover
git checkout 6786f437df54ca7780a047203cbcfaa1db8dc542
git apply /root/pre_state.patch
