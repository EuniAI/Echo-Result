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
diff --git a/sklearn/linear_model/logistic.py b/sklearn/linear_model/logistic.py
--- a/sklearn/linear_model/logistic.py
+++ b/sklearn/linear_model/logistic.py
@@ -2170,7 +2170,7 @@ def fit(self, X, y, sample_weight=None):
                 # Take the best scores across every fold and the average of
                 # all coefficients corresponding to the best scores.
                 best_indices = np.argmax(scores, axis=1)
-                if self.multi_class == 'ovr':
+                if multi_class == 'ovr':
                     w = np.mean([coefs_paths[i, best_indices[i], :]
                                  for i in range(len(folds))], axis=0)
                 else:
@@ -2180,8 +2180,11 @@ def fit(self, X, y, sample_weight=None):
                 best_indices_C = best_indices % len(self.Cs_)
                 self.C_.append(np.mean(self.Cs_[best_indices_C]))
 
-                best_indices_l1 = best_indices // len(self.Cs_)
-                self.l1_ratio_.append(np.mean(l1_ratios_[best_indices_l1]))
+                if self.penalty == 'elasticnet':
+                    best_indices_l1 = best_indices // len(self.Cs_)
+                    self.l1_ratio_.append(np.mean(l1_ratios_[best_indices_l1]))
+                else:
+                    self.l1_ratio_.append(None)
 
             if multi_class == 'multinomial':
                 self.C_ = np.tile(self.C_, n_classes)

EOF_114329324912
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
