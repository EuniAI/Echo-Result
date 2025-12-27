#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD f7eea978097085a6781a0e92fc14ba7712a52d75 >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff f7eea978097085a6781a0e92fc14ba7712a52d75
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -v --no-use-pep517 --no-build-isolation -e .
git apply -v - <<'EOF_114329324912'
diff --git a/sklearn/impute/tests/test_iterative_imputer.py b/sklearn/impute/tests/test_iterative_imputer.py
new file mode 100644
index 0000000000..73daab14fe
--- /dev/null
+++ b/sklearn/impute/tests/test_iterative_imputer.py
@@ -0,0 +1,34 @@
+import pytest
+import numpy as np
+
+# make IterativeImputer available
+from sklearn.experimental import enable_iterative_imputer  # noqa
+from sklearn.impute import IterativeImputer
+from sklearn.utils._testing import assert_array_equal
+
+
+def test_iterative_imputer_constant_initial_strategy_fill_value():
+    """Test IterativeImputer with initial_strategy='constant' and fill_value.
+
+    When `initial_strategy` is set to `'constant'`, `IterativeImputer` should
+    be able to accept a `fill_value` parameter to specify the constant to
+    use for the initial imputation.
+
+    This test fails with a TypeError because `fill_value` is not a valid
+    parameter for `IterativeImputer`.
+    """
+    X = np.array([
+        [1, np.nan],
+        [3, 4.0]
+    ])
+    X_expected = np.array([
+        [1, 0],
+        [3, 4.0]
+    ])
+    # Use max_iter=0 to ensure only the initial imputation is performed.
+    # random_state is passed for reproducibility.
+    imputer = IterativeImputer(
+        initial_strategy="constant", fill_value=0, max_iter=0, random_state=0
+    )
+    X_imputed = imputer.fit_transform(X)
+    assert_array_equal(X_expected, X_imputed)

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(sklearn/impute/_iterative\.py)' -m pytest --no-header -rA  -p no:cacheprovider sklearn/impute/tests/test_iterative_imputer.py
cat coverage.cover
git checkout f7eea978097085a6781a0e92fc14ba7712a52d75
git apply /root/pre_state.patch
