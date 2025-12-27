#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD a2a1b0a11b993fe5f8fab64b6161e99243a6393c >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff a2a1b0a11b993fe5f8fab64b6161e99243a6393c
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/lib/matplotlib/category.py b/lib/matplotlib/category.py
--- a/lib/matplotlib/category.py
+++ b/lib/matplotlib/category.py
@@ -58,7 +58,7 @@ def convert(value, unit, axis):
             is_numlike = all(units.ConversionInterface.is_numlike(v)
                              and not isinstance(v, (str, bytes))
                              for v in values)
-        if is_numlike:
+        if values.size and is_numlike:
             _api.warn_deprecated(
                 "3.5", message="Support for passing numbers through unit "
                 "converters is deprecated since %(since)s and support will be "
@@ -230,7 +230,7 @@ def update(self, data):
                 convertible = self._str_is_convertible(val)
             if val not in self._mapping:
                 self._mapping[val] = next(self._counter)
-        if convertible:
+        if data.size and convertible:
             _log.info('Using categorical units to plot a list of strings '
                       'that are all parsable as floats or dates. If these '
                       'strings should be plotted as numbers, cast to the '

EOF_114329324912
git apply -v - <<'EOF_114329324912'
diff --git a/lib/matplotlib/tests/test_category_deprecation.py b/lib/matplotlib/tests/test_category_deprecation.py
new file mode 100644
index 0000000000..821d29e059
--- /dev/null
+++ b/lib/matplotlib/tests/test_category_deprecation.py
@@ -0,0 +1,21 @@
+import warnings
+import pytest
+import matplotlib.pyplot as plt
+from matplotlib import MatplotlibDeprecationWarning
+
+
+def test_empty_plot_with_category_units_no_warning():
+    """
+    Test that plotting empty data with category units does not raise a
+    deprecation warning. This reproduces a bug where a non-actionable
+    MatplotlibDeprecationWarning is raised.
+    """
+    fig, ax = plt.subplots()
+    ax.xaxis.update_units(["a", "b"])
+
+    with warnings.catch_warnings(record=True) as w:
+        # Filter for the specific warning which we don't expect to see.
+        warnings.simplefilter("always", MatplotlibDeprecationWarning)
+        ax.plot([], [])
+        # This will fail if a MatplotlibDeprecationWarning is raised.
+        assert len(w) == 0

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(lib/matplotlib/category\.py)' -m pytest --no-header -rA  -p no:cacheprovider lib/matplotlib/tests/test_category_deprecation.py
cat coverage.cover
git checkout a2a1b0a11b993fe5f8fab64b6161e99243a6393c
git apply /root/pre_state.patch
