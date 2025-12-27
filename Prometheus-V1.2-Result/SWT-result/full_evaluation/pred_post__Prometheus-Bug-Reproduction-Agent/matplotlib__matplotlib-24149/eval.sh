#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD af39f1edffcd828f05cfdd04f2e59506bb4a27bc >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff af39f1edffcd828f05cfdd04f2e59506bb4a27bc
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/lib/matplotlib/axes/_axes.py b/lib/matplotlib/axes/_axes.py
--- a/lib/matplotlib/axes/_axes.py
+++ b/lib/matplotlib/axes/_axes.py
@@ -2182,11 +2182,19 @@ def _convert_dx(dx, x0, xconv, convert):
                 x0 = cbook._safe_first_finite(x0)
             except (TypeError, IndexError, KeyError):
                 pass
+            except StopIteration:
+                # this means we found no finite element, fall back to first
+                # element unconditionally
+                x0 = cbook.safe_first_element(x0)
 
             try:
                 x = cbook._safe_first_finite(xconv)
             except (TypeError, IndexError, KeyError):
                 x = xconv
+            except StopIteration:
+                # this means we found no finite element, fall back to first
+                # element unconditionally
+                x = cbook.safe_first_element(xconv)
 
             delist = False
             if not np.iterable(dx):

EOF_114329324912
git apply -v - <<'EOF_114329324912'
diff --git a/lib/matplotlib/tests/test_bar.py b/lib/matplotlib/tests/test_bar.py
new file mode 100644
index 0000000000..f03805c9af
--- /dev/null
+++ b/lib/matplotlib/tests/test_bar.py
@@ -0,0 +1,17 @@
+import numpy as np
+import matplotlib.pyplot as plt
+
+
+def test_bar_all_nan():
+    """
+    Test that drawing a bar with nan-only data does not raise an error.
+
+    This is a regression test for issue #24125, where ax.bar would raise
+    a StopIteration error for all-NaN data on matplotlib 3.6.1.
+    The expected behavior is to create a bar, even if it's not visible.
+    """
+    fig, ax = plt.subplots()
+    # This call should not raise an exception.
+    container = ax.bar([np.nan], [np.nan])
+    # A BarContainer should be returned with one patch.
+    assert len(container.patches) == 1

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(lib/matplotlib/axes/_axes\.py)' -m pytest --no-header -rA  -p no:cacheprovider lib/matplotlib/tests/test_bar.py
cat coverage.cover
git checkout af39f1edffcd828f05cfdd04f2e59506bb4a27bc
git apply /root/pre_state.patch
