#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD a5743ed36fbd3fbc8e351bdab16561fbfca7dfa1 >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff a5743ed36fbd3fbc8e351bdab16561fbfca7dfa1
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -v --no-use-pep517 --no-build-isolation -e .
git apply -v - <<'EOF_114329324912'
diff --git a/sklearn/linear_model/tests/test_logistic_regression_cv.py b/sklearn/linear_model/tests/test_logistic_regression_cv.py
new file mode 100644
index 0000000000..b9a5f8ff7e
--- /dev/null
+++ b/sklearn/linear_model/tests/test_logistic_regression_cv.py
@@ -0,0 +1,32 @@
+import numpy as np
+import pytest
+
+from sklearn.linear_model import LogisticRegressionCV
+from sklearn.utils.testing import assert_array_almost_equal
+
+
+def test_logistic_cv_refit_false_binary():
+    """Test that LogisticRegressionCV(refit=False) does not fail on binary
+    classification problems.
+
+    Non-regression test for #14244.
+    """
+    np.random.seed(29)
+    X = np.random.normal(size=(1000, 3))
+    beta = np.random.normal(size=3)
+    intercept = np.random.normal(size=None)
+    y = np.sign(intercept + X @ beta)
+
+    clf = LogisticRegressionCV(
+        cv=5,
+        solver='saga',
+        tol=1e-2,
+        refit=False
+    )
+    # This should not raise an IndexError
+    clf.fit(X, y)
+
+    # When refit=False, coef_ is the average of the coefficients across
+    # the CV folds. For a binary classification problem, its shape should
+    # be (1, n_features). This assertion will fail if fit() crashes.
+    assert clf.coef_.shape == (1, X.shape[1])

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(sklearn/linear_model/logistic\.py)' -m pytest --no-header -rA  -p no:cacheprovider sklearn/linear_model/tests/test_logistic_regression_cv.py
cat coverage.cover
git checkout a5743ed36fbd3fbc8e351bdab16561fbfca7dfa1
git apply /root/pre_state.patch
