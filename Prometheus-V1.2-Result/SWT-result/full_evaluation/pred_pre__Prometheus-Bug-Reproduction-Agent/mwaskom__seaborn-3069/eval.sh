#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 54cab15bdacfaa05a88fbc5502a5b322d99f148e >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 54cab15bdacfaa05a88fbc5502a5b322d99f148e
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .[dev]
git apply -v - <<'EOF_114329324912'
diff --git a/tests/_core/test_nominal_scale_margins.py b/tests/_core/test_nominal_scale_margins.py
new file mode 100644
index 00000000..59d185db
--- /dev/null
+++ b/tests/_core/test_nominal_scale_margins.py
@@ -0,0 +1,54 @@
+import re
+
+import numpy as np
+import pandas as pd
+import matplotlib as mpl
+
+import pytest
+from numpy.testing import assert_array_equal
+from pandas.testing import assert_series_equal
+
+from seaborn._core.scales import (
+    Nominal,
+    Continuous,
+    Temporal,
+    PseudoAxis,
+)
+from seaborn._core.properties import (
+    IntervalProperty,
+    ObjectProperty,
+    Coordinate,
+    Alpha,
+    Color,
+    Fill,
+)
+from seaborn.palettes import color_palette
+from seaborn.external.version import Version
+
+
+class TestNominal:
+
+    @pytest.fixture
+    def x(self):
+        return pd.Series(["a", "c", "b", "c"], name="x")
+
+    @pytest.fixture
+    def y(self):
+        return pd.Series([1, -1.5, 3, -1.5], name="y")
+
+    def test_nominal_scale_margins_and_inversion(self, x):
+        """
+        Test that Nominal scales behave like categorical scales in terms of
+        margins and axis inversion.
+        """
+        # Test x-axis margins
+        ax_x = mpl.figure.Figure().subplots()
+        s_x = Nominal()._setup(x, Coordinate(), ax_x.xaxis)
+        ax_x.plot(s_x(x))
+        assert ax_x.get_xlim() == (-0.5, 2.5)
+
+        # Test y-axis inversion
+        ax_y = mpl.figure.Figure().subplots()
+        s_y = Nominal()._setup(x, Coordinate(), ax_y.yaxis)
+        ax_y.plot(s_y(x))
+        assert ax_y.get_ylim() == (2.5, -0.5)

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(seaborn/_core/plot\.py)' -m pytest --no-header -rA tests/_core/test_nominal_scale_margins.py
cat coverage.cover
git checkout 54cab15bdacfaa05a88fbc5502a5b322d99f148e
git apply /root/pre_state.patch
