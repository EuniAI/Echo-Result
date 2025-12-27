#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD a7b8b9e9e16d4e15fabda5ae615086c2e1c47d8a >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff a7b8b9e9e16d4e15fabda5ae615086c2e1c47d8a
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -v --no-use-pep517 --no-build-isolation -e .
git apply -v - <<'EOF_114329324912'
diff --git a/sklearn/linear_model/least_angle.py b/sklearn/linear_model/least_angle.py
--- a/sklearn/linear_model/least_angle.py
+++ b/sklearn/linear_model/least_angle.py
@@ -1479,7 +1479,7 @@ def __init__(self, criterion='aic', fit_intercept=True, verbose=False,
         self.eps = eps
         self.fit_path = True
 
-    def fit(self, X, y, copy_X=True):
+    def fit(self, X, y, copy_X=None):
         """Fit the model using X, y as training data.
 
         Parameters
@@ -1490,7 +1490,9 @@ def fit(self, X, y, copy_X=True):
         y : array-like, shape (n_samples,)
             target values. Will be cast to X's dtype if necessary
 
-        copy_X : boolean, optional, default True
+        copy_X : boolean, optional, default None
+            If provided, this parameter will override the choice
+            of copy_X made at instance creation.
             If ``True``, X will be copied; else, it may be overwritten.
 
         Returns
@@ -1498,10 +1500,12 @@ def fit(self, X, y, copy_X=True):
         self : object
             returns an instance of self.
         """
+        if copy_X is None:
+            copy_X = self.copy_X
         X, y = check_X_y(X, y, y_numeric=True)
 
         X, y, Xmean, ymean, Xstd = LinearModel._preprocess_data(
-            X, y, self.fit_intercept, self.normalize, self.copy_X)
+            X, y, self.fit_intercept, self.normalize, copy_X)
         max_iter = self.max_iter
 
         Gram = self.precompute

EOF_114329324912
git apply -v - <<'EOF_114329324912'
diff --git a/sklearn/linear_model/tests/test_lassolarsic_copy_x_bug.py b/sklearn/linear_model/tests/test_lassolarsic_copy_x_bug.py
new file mode 100644
index 0000000000..518f230a26
--- /dev/null
+++ b/sklearn/linear_model/tests/test_lassolarsic_copy_x_bug.py
@@ -0,0 +1,45 @@
+import pytest
+import numpy as np
+
+from sklearn import linear_model
+from sklearn.utils.testing import assert_array_equal
+from sklearn import datasets
+
+def test_lassolarsic_copy_x_is_overwritten():
+    """
+    Test that LassoLarsIC's fit method incorrectly overwrites constructor's copy_X.
+
+    The bug is that the `copy_X=True` default in the `fit` method signature
+    overrides the `copy_X` value provided to the constructor. This test
+    verifies that when `copy_X=False` is set in the constructor, the input
+    array `X` is NOT modified in-place by the underlying `lars_path`
+    function as it should be.
+
+    We engineer a dataset where the last column is most correlated with y.
+    A correct in-place fit would swap this last column to the first position in X.
+    The test asserts that the first column of X is NOT the original last column,
+    which will be true if the bug exists, causing the test to fail.
+    """
+    # Create a dataset where the last feature is the most correlated.
+    # This forces lars_path to swap the last column to the first position
+    # if it modifies the array in-place.
+    rng = np.random.RandomState(0)
+    X_train = rng.randn(10, 5)
+    y_train = 2 * X_train[:, -1]
+
+    # Keep a copy of the original last column to check against later
+    original_last_col = X_train[:, -1].copy()
+
+    # We expect lars_path to operate on X_train in-place because copy_X=False.
+    # fit_intercept=False is used to prevent in-place centering, simplifying
+    # the test to only check for the effect of lars_path's column swapping.
+    estimator = linear_model.LassoLarsIC(copy_X=False, fit_intercept=False)
+    estimator.fit(X_train, y_train)
+
+    # With the bug, `fit` calls `lars_path` with `copy_X=True`, so a copy
+    # is made inside `lars_path` and the original `X_train` is not modified.
+    # Therefore, the first column of X_train will not have been swapped with the last.
+    # This assertion will FAIL because the columns are not equal, thus
+    # demonstrating the bug. When the bug is fixed, the swap will occur,
+    # and the assertion will pass.
+    assert_array_equal(X_train[:, 0], original_last_col)

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(sklearn/linear_model/least_angle\.py)' -m pytest --no-header -rA  -p no:cacheprovider sklearn/linear_model/tests/test_lassolarsic_copy_x_bug.py
cat coverage.cover
git checkout a7b8b9e9e16d4e15fabda5ae615086c2e1c47d8a
git apply /root/pre_state.patch
