#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 66ba515e671638971bd11a34cff12c107a437e0b >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 66ba515e671638971bd11a34cff12c107a437e0b
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/lib/matplotlib/tests/test_pickle_aligned_labels.py b/lib/matplotlib/tests/test_pickle_aligned_labels.py
new file mode 100644
index 0000000000..24a76fab94
--- /dev/null
+++ b/lib/matplotlib/tests/test_pickle_aligned_labels.py
@@ -0,0 +1,25 @@
+import pickle
+import matplotlib.pyplot as plt
+
+
+def test_pickle_aligned_labels():
+    """
+    Test that pickling a figure with aligned labels works.
+
+    Regression test for https://github.com/matplotlib/matplotlib/issues/25429
+    """
+    fig = plt.figure()
+    ax1 = fig.add_subplot(211)
+    ax2 = fig.add_subplot(212)
+    time = [0, 1, 2, 3, 4]
+    speed = [40000, 4300, 4500, 4700, 4800]
+    acc = [10, 11, 12, 13, 14]
+    ax1.plot(time, speed)
+    ax1.set_ylabel('speed')
+    ax2.plot(time, acc)
+    ax2.set_ylabel('acc')
+
+    fig.align_labels()
+
+    # This should not raise "TypeError: cannot pickle 'weakref.ReferenceType'"
+    pickle.dumps(fig)

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(lib/matplotlib/cbook\.py)' -m pytest --no-header -rA  -p no:cacheprovider lib/matplotlib/tests/test_pickle_aligned_labels.py
cat coverage.cover
git checkout 66ba515e671638971bd11a34cff12c107a437e0b
git apply /root/pre_state.patch
