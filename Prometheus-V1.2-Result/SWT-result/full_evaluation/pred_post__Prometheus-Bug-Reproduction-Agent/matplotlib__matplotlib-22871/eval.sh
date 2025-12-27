#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD a7b7260bf06c20d408215d95ce20a1a01c12e5b1 >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff a7b7260bf06c20d408215d95ce20a1a01c12e5b1
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/lib/matplotlib/dates.py b/lib/matplotlib/dates.py
--- a/lib/matplotlib/dates.py
+++ b/lib/matplotlib/dates.py
@@ -796,8 +796,10 @@ def format_ticks(self, values):
         # mostly 0: years,  1: months,  2: days,
         # 3: hours, 4: minutes, 5: seconds, 6: microseconds
         for level in range(5, -1, -1):
-            if len(np.unique(tickdate[:, level])) > 1:
-                if level < 2:
+            unique = np.unique(tickdate[:, level])
+            if len(unique) > 1:
+                # if 1 is included in unique, the year is shown in ticks
+                if level < 2 and np.any(unique == 1):
                     show_offset = False
                 break
             elif level == 0:

EOF_114329324912
git apply -v - <<'EOF_114329324912'
diff --git a/lib/matplotlib/tests/test_concise_date_formatter.py b/lib/matplotlib/tests/test_concise_date_formatter.py
new file mode 100644
index 0000000000..d94b510766
--- /dev/null
+++ b/lib/matplotlib/tests/test_concise_date_formatter.py
@@ -0,0 +1,29 @@
+import matplotlib.pyplot as plt
+import matplotlib.dates as mdates
+from datetime import datetime, timedelta
+import pytest
+
+def test_concise_formatter_no_january():
+    """
+    Test that ConciseDateFormatter shows the year in the offset when the
+    plotted range is less than a year and does not include January.
+    """
+    # create time array
+    initial = datetime(2021, 2, 14, 0, 0, 0)
+    time_array = [initial + timedelta(days=x) for x in range(1, 200)]
+
+    # create data array
+    data = [-x**2/20000 for x in range(1, 200)]
+
+    # plot data
+    fig, ax = plt.subplots()
+    ax.plot(time_array, data)
+
+    locator = mdates.AutoDateLocator()
+    formatter = mdates.ConciseDateFormatter(locator)
+
+    ax.xaxis.set_major_locator(locator)
+    ax.xaxis.set_major_formatter(formatter)
+    fig.canvas.draw()
+
+    assert formatter.get_offset() == '2021'

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(lib/matplotlib/dates\.py)' -m pytest --no-header -rA  -p no:cacheprovider lib/matplotlib/tests/test_concise_date_formatter.py
cat coverage.cover
git checkout a7b7260bf06c20d408215d95ce20a1a01c12e5b1
git apply /root/pre_state.patch
