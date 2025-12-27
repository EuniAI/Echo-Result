#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 2c867b8f822eb7a684f0d5c4359e4426e1c9cfe0 >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 2c867b8f822eb7a684f0d5c4359e4426e1c9cfe0
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -v --no-use-pep517 --no-build-isolation -e .
git apply -v - <<'EOF_114329324912'
diff --git a/sklearn/utils/_set_output.py b/sklearn/utils/_set_output.py
--- a/sklearn/utils/_set_output.py
+++ b/sklearn/utils/_set_output.py
@@ -34,7 +34,7 @@ def _wrap_in_pandas_container(
         `range(n_features)`.
 
     index : array-like, default=None
-        Index for data.
+        Index for data. `index` is ignored if `data_to_wrap` is already a DataFrame.
 
     Returns
     -------
@@ -55,8 +55,6 @@ def _wrap_in_pandas_container(
     if isinstance(data_to_wrap, pd.DataFrame):
         if columns is not None:
             data_to_wrap.columns = columns
-        if index is not None:
-            data_to_wrap.index = index
         return data_to_wrap
 
     return pd.DataFrame(data_to_wrap, index=index, columns=columns)

EOF_114329324912
git apply -v - <<'EOF_114329324912'
diff --git a/sklearn/tests/test_feature_union_pandas_aggregation.py b/sklearn/tests/test_feature_union_pandas_aggregation.py
new file mode 100644
index 0000000000..0bf16280b3
--- /dev/null
+++ b/sklearn/tests/test_feature_union_pandas_aggregation.py
@@ -0,0 +1,48 @@
+import pytest
+import pandas as pd
+import numpy as np
+
+from sklearn.base import BaseEstimator, TransformerMixin
+from sklearn.pipeline import make_union
+from sklearn import set_config
+from sklearn.utils._testing import assert_array_equal
+
+
+class MyTransformer(BaseEstimator, TransformerMixin):
+    def fit(self, X: pd.DataFrame, y: pd.Series | None = None, **kwargs):
+        return self
+
+    def transform(self, X: pd.DataFrame, y: pd.Series | None = None) -> pd.DataFrame:
+        return X.groupby(X["date"])["value"].sum()
+
+
+def test_feature_union_with_pandas_output_aggregation():
+    """
+    Regression test for a bug in FeatureUnion when a transformer aggregates
+    data and `transform_output` is set to "pandas".
+
+    The error occurs because scikit-learn tries to align the index of the
+    aggregated (shorter) output with the index of the original (longer)
+    input, leading to a ValueError. When fixed, the transform should
+    succeed and return a DataFrame with the correct aggregated shape.
+    """
+    pd = pytest.importorskip("pandas")
+
+    # Recreate the data from the bug report
+    index = pd.date_range(start="2020-01-01", end="2020-01-05", inclusive="left", freq="H")
+    data = pd.DataFrame(index=index, data=[10] * len(index), columns=["value"])
+    data["date"] = index.date
+
+    union = make_union(MyTransformer())
+
+    # Configure the output to pandas, which triggers the bug
+    set_config(transform_output="pandas")
+
+    # This call raises a ValueError because the aggregated output's length (4)
+    # does not match the input's length (96).
+    # When fixed, this should return a pandas DataFrame.
+    transformed_data = union.fit_transform(data)
+
+    # This assertion will fail until the bug is fixed. Once fixed, it will
+    # verify that the output has the correct shape after aggregation.
+    assert transformed_data.shape == (4, 1)

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(sklearn/utils/_set_output\.py)' -m pytest --no-header -rA  -p no:cacheprovider sklearn/tests/test_feature_union_pandas_aggregation.py
cat coverage.cover
git checkout 2c867b8f822eb7a684f0d5c4359e4426e1c9cfe0
git apply /root/pre_state.patch
