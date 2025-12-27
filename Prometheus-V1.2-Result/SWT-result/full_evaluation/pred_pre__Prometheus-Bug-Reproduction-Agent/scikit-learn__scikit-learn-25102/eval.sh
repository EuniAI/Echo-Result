#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD f9a1cf072da9d7375d6c2163f68a6038b13b310f >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff f9a1cf072da9d7375d6c2163f68a6038b13b310f
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -v --no-use-pep517 --no-build-isolation -e .
git apply -v - <<'EOF_114329324912'
diff --git a/sklearn/feature_selection/tests/test_univariate_selection.py b/sklearn/feature_selection/tests/test_univariate_selection.py
new file mode 100644
index 0000000000..347b6efb1e
--- /dev/null
+++ b/sklearn/feature_selection/tests/test_univariate_selection.py
@@ -0,0 +1,32 @@
+import pytest
+import numpy as np
+import pandas as pd
+
+from sklearn.datasets import load_iris
+from sklearn.feature_selection import SelectKBest, chi2
+
+
+def test_select_k_best_preserves_dtype_pandas_output():
+    """Check that SelectKBest preserves dtypes when outputting pandas.
+
+    Non-regression test for gh-24908.
+    """
+    pd = pytest.importorskip("pandas")
+
+    X, y = load_iris(return_X_y=True, as_frame=True)
+    X = X.astype(
+        {
+            "petal width (cm)": np.float16,
+            "petal length (cm)": np.float16,
+        }
+    )
+    X["cat"] = y.astype("category")
+
+    selector = SelectKBest(chi2, k=2)
+    selector.set_output(transform="pandas")
+    X_out = selector.fit_transform(X, y)
+
+    # When the bug is fixed, the dtypes of the output DataFrame should match
+    # the dtypes of the selected columns in the input DataFrame.
+    expected_dtypes = X[selector.get_feature_names_out()].dtypes
+    pd.testing.assert_series_equal(X_out.dtypes, expected_dtypes)

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(sklearn/base\.py|sklearn/feature_selection/_base\.py)' -m pytest --no-header -rA  -p no:cacheprovider sklearn/feature_selection/tests/test_univariate_selection.py
cat coverage.cover
git checkout f9a1cf072da9d7375d6c2163f68a6038b13b310f
git apply /root/pre_state.patch
