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
