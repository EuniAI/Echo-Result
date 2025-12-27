#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 37b0e66c871e8fb032a9c7086b2a1d5419838154 >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 37b0e66c871e8fb032a9c7086b2a1d5419838154
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -v --no-use-pep517 --no-build-isolation -e .
git apply -v - <<'EOF_114329324912'
diff --git a/sklearn/linear_model/huber.py b/sklearn/linear_model/huber.py
--- a/sklearn/linear_model/huber.py
+++ b/sklearn/linear_model/huber.py
@@ -251,7 +251,8 @@ def fit(self, X, y, sample_weight=None):
         self : object
         """
         X, y = check_X_y(
-            X, y, copy=False, accept_sparse=['csr'], y_numeric=True)
+            X, y, copy=False, accept_sparse=['csr'], y_numeric=True,
+            dtype=[np.float64, np.float32])
         if sample_weight is not None:
             sample_weight = np.array(sample_weight)
             check_consistent_length(y, sample_weight)

EOF_114329324912
git apply -v - <<'EOF_114329324912'
diff --git a/sklearn/linear_model/tests/test_huber_regressor_boolean_input.py b/sklearn/linear_model/tests/test_huber_regressor_boolean_input.py
new file mode 100644
index 0000000000..99d719e35e
--- /dev/null
+++ b/sklearn/linear_model/tests/test_huber_regressor_boolean_input.py
@@ -0,0 +1,26 @@
+import numpy as np
+import pytest
+
+from sklearn.datasets import make_regression
+from sklearn.linear_model import HuberRegressor
+
+
+def test_huber_regressor_handles_boolean_input():
+    """
+    Test that HuberRegressor can be fitted on boolean data without raising a TypeError.
+    This is a non-regression test for the bug described in the issue, where
+    fitting with a boolean `X` array caused a TypeError.
+    """
+    # As described in the issue, generate data and a boolean version of it.
+    X, y, _ = make_regression(
+        n_samples=200, n_features=2, noise=4.0, coef=True, random_state=0
+    )
+    X_bool = X > 0
+
+    # The following line is expected to fail with a TypeError before the fix.
+    # After the fix, it should run without raising an exception.
+    huber = HuberRegressor().fit(X_bool, y)
+
+    # Minimal assertion: check that the model has been fitted by verifying
+    # the existence of the `coef_` attribute.
+    assert hasattr(huber, "coef_")

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(sklearn/linear_model/huber\.py)' -m pytest --no-header -rA  -p no:cacheprovider sklearn/linear_model/tests/test_huber_regressor_boolean_input.py
cat coverage.cover
git checkout 37b0e66c871e8fb032a9c7086b2a1d5419838154
git apply /root/pre_state.patch
