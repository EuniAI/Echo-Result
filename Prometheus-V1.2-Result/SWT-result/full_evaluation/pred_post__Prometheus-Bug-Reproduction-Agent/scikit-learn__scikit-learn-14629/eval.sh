#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 4aded39b5663d943f6a4809abacfa9cae3d7fb6a >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 4aded39b5663d943f6a4809abacfa9cae3d7fb6a
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -v --no-use-pep517 --no-build-isolation -e .
git apply -v - <<'EOF_114329324912'
diff --git a/sklearn/multioutput.py b/sklearn/multioutput.py
--- a/sklearn/multioutput.py
+++ b/sklearn/multioutput.py
@@ -325,6 +325,28 @@ class MultiOutputClassifier(MultiOutputEstimator, ClassifierMixin):
     def __init__(self, estimator, n_jobs=None):
         super().__init__(estimator, n_jobs)
 
+    def fit(self, X, Y, sample_weight=None):
+        """Fit the model to data matrix X and targets Y.
+
+        Parameters
+        ----------
+        X : {array-like, sparse matrix} of shape (n_samples, n_features)
+            The input data.
+        Y : array-like of shape (n_samples, n_classes)
+            The target values.
+        sample_weight : array-like of shape (n_samples,) or None
+            Sample weights. If None, then samples are equally weighted.
+            Only supported if the underlying classifier supports sample
+            weights.
+
+        Returns
+        -------
+        self : object
+        """
+        super().fit(X, Y, sample_weight)
+        self.classes_ = [estimator.classes_ for estimator in self.estimators_]
+        return self
+
     def predict_proba(self, X):
         """Probability estimates.
         Returns prediction probabilities for each class of each output.
@@ -420,7 +442,7 @@ def fit(self, X, Y):
             if self.order_ == 'random':
                 self.order_ = random_state.permutation(Y.shape[1])
         elif sorted(self.order_) != list(range(Y.shape[1])):
-                raise ValueError("invalid order")
+            raise ValueError("invalid order")
 
         self.estimators_ = [clone(self.base_estimator)
                             for _ in range(Y.shape[1])]

EOF_114329324912
git apply -v - <<'EOF_114329324912'
diff --git a/sklearn/model_selection/tests/test_cross_val_predict_multioutput.py b/sklearn/model_selection/tests/test_cross_val_predict_multioutput.py
new file mode 100644
index 0000000000..940d76cab2
--- /dev/null
+++ b/sklearn/model_selection/tests/test_cross_val_predict_multioutput.py
@@ -0,0 +1,31 @@
+import pytest
+import numpy as np
+
+from sklearn.datasets import make_multilabel_classification
+from sklearn.multioutput import MultiOutputClassifier
+from sklearn.discriminant_analysis import LinearDiscriminantAnalysis
+from sklearn.model_selection import cross_val_predict
+
+
+def test_cross_val_predict_multioutput_predict_proba():
+    """
+    Test cross_val_predict with method='predict_proba' on MultiOutputClassifier.
+
+    This is a non-regression test for a bug that caused an AttributeError
+    because cross_val_predict was trying to access `classes_` on the
+    MultiOutputClassifier meta-estimator instead of the sub-estimators.
+    See issue #14257.
+    """
+    X, Y = make_multilabel_classification(n_samples=100, n_classes=5,
+                                          random_state=0)
+
+    # The combination of MultiOutputClassifier and method='predict_proba'
+    # caused an AttributeError.
+    clf = MultiOutputClassifier(LinearDiscriminantAnalysis())
+    pred_proba = cross_val_predict(clf, X, Y, cv=3, method='predict_proba')
+
+    # The result should be a list of arrays, one for each of the 5 outputs.
+    # Each array should have shape (n_samples, n_classes_in_output), which is
+    # (100, 2) for each binary output.
+    assert len(pred_proba) == 5
+    assert pred_proba[0].shape == (100, 2)

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(sklearn/multioutput\.py)' -m pytest --no-header -rA  -p no:cacheprovider sklearn/model_selection/tests/test_cross_val_predict_multioutput.py
cat coverage.cover
git checkout 4aded39b5663d943f6a4809abacfa9cae3d7fb6a
git apply /root/pre_state.patch
