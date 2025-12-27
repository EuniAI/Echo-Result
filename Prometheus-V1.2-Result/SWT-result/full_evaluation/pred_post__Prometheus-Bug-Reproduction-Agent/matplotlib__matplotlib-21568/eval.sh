#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD f0632c0fc7339f68e992ed63ae4cfac76cd41aad >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff f0632c0fc7339f68e992ed63ae4cfac76cd41aad
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/lib/matplotlib/dates.py b/lib/matplotlib/dates.py
--- a/lib/matplotlib/dates.py
+++ b/lib/matplotlib/dates.py
@@ -595,8 +595,11 @@ def _wrap_in_tex(text):
     p = r'([a-zA-Z]+)'
     ret_text = re.sub(p, r'}$\1$\\mathdefault{', text)
 
-    # Braces ensure dashes are not spaced like binary operators.
-    ret_text = '$\\mathdefault{'+ret_text.replace('-', '{-}')+'}$'
+    # Braces ensure symbols are not spaced like binary operators.
+    ret_text = ret_text.replace('-', '{-}').replace(':', '{:}')
+    # To not concatenate space between numbers.
+    ret_text = ret_text.replace(' ', r'\;')
+    ret_text = '$\\mathdefault{' + ret_text + '}$'
     ret_text = ret_text.replace('$\\mathdefault{}$', '')
     return ret_text
 

EOF_114329324912
git apply -v - <<'EOF_114329324912'
diff --git a/lib/matplotlib/tests/test_datetime_usetex.py b/lib/matplotlib/tests/test_datetime_usetex.py
new file mode 100644
index 0000000000..bfa9d6689f
--- /dev/null
+++ b/lib/matplotlib/tests/test_datetime_usetex.py
@@ -0,0 +1,41 @@
+import matplotlib as mpl
+import matplotlib.pyplot as plt
+import numpy as np
+import pandas as pd
+import pytest
+
+
+@pytest.mark.skipif(not mpl.checkdep_usetex(True), reason="LaTeX is not installed")
+def test_datetime_axis_usetex_spacing():
+    """
+    Test to reproduce unclear spacing on datetime axis with usetex=True.
+
+    This test asserts that the date formatter selects a compact format
+    for the tick labels (e.g., HH:MM), as it did in older Matplotlib
+    versions, instead of a long format (e.g., HH:MM:SS) that causes
+    labels to overlap when using LaTeX.
+    """
+    mpl.rcParams["text.usetex"] = True
+
+    np.random.seed(1)
+
+    dates = pd.date_range(
+        "2020-01-01 00:00:00", end="2020-01-01 00:10:00", periods=100
+    ).to_pydatetime()
+    data = np.random.rand(100)
+
+    fig, ax = plt.subplots(constrained_layout=True)
+    ax.plot(dates, data)
+    fig.canvas.draw()
+
+    # The buggy formatter produces labels with seconds (e.g., "00:02:30"),
+    # which have two colons. The correct, more compact format (e.g., "00:02")
+    # has only one.
+    actual_labels = [tick.get_text() for tick in ax.get_xticklabels()]
+    has_seconds_in_label = any(label.count(':') == 2 for label in actual_labels)
+
+    # This assertion fails now because the buggy formatter includes seconds.
+    # It will pass when the formatter is fixed to choose a more compact format.
+    assert not has_seconds_in_label, \
+        "Tick labels should use a compact format (e.g., HH:MM) to avoid overlap, " \
+        "but a format with seconds (HH:MM:SS) was found."

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(lib/matplotlib/dates\.py)' -m pytest --no-header -rA  -p no:cacheprovider lib/matplotlib/tests/test_datetime_usetex.py
cat coverage.cover
git checkout f0632c0fc7339f68e992ed63ae4cfac76cd41aad
git apply /root/pre_state.patch
