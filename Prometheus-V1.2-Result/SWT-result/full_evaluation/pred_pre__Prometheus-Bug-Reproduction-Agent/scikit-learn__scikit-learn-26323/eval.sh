#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 586f4318ffcdfbd9a1093f35ad43e81983740b66 >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 586f4318ffcdfbd9a1093f35ad43e81983740b66
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -v --no-use-pep517 --no-build-isolation -e .
git apply -v - <<'EOF_114329324912'
diff --git a/sklearn/compose/tests/test_column_transformer_set_output.py b/sklearn/compose/tests/test_column_transformer_set_output.py
new file mode 100644
index 0000000000..e937242d3e
--- /dev/null
+++ b/sklearn/compose/tests/test_column_transformer_set_output.py
@@ -0,0 +1,33 @@
+import pytest
+
+from sklearn.compose import make_column_selector, make_column_transformer
+from sklearn.feature_selection import VarianceThreshold
+
+
+def test_set_output_remainder_estimator():
+    """Check that set_output is configured on the remainder estimator.
+
+    Non-regression test for gh-26799.
+    """
+    pd = pytest.importorskip("pandas")
+    from pandas.testing import assert_frame_equal
+
+    df = pd.DataFrame({"a": [True, False, True], "b": [1, 2, 3]})
+
+    # The bug is that `set_output` is not called on the remainder, which
+    # means it does not output a DataFrame and messes up concatenation.
+    ct = (
+        make_column_transformer(
+            (VarianceThreshold(), make_column_selector(dtype_include=bool)),
+            remainder=VarianceThreshold(),
+            verbose_feature_names_out=False,
+        )
+        .set_output(transform="pandas")
+    )
+
+    out = ct.fit_transform(df)
+
+    # The expected output is the same as the input, because VarianceThreshold
+    # does not remove any columns. The dtypes should be preserved.
+    expected_df = pd.DataFrame({"a": [True, False, True], "b": [1, 2, 3]})
+    assert_frame_equal(out, expected_df)

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(sklearn/compose/_column_transformer\.py)' -m pytest --no-header -rA  -p no:cacheprovider sklearn/compose/tests/test_column_transformer_set_output.py
cat coverage.cover
git checkout 586f4318ffcdfbd9a1093f35ad43e81983740b66
git apply /root/pre_state.patch
