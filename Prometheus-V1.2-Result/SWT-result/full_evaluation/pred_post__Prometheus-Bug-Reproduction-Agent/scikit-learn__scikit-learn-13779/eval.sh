#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD b34751b7ed02b2cfcc36037fb729d4360480a299 >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff b34751b7ed02b2cfcc36037fb729d4360480a299
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -v --no-use-pep517 --no-build-isolation -e .
git apply -v - <<'EOF_114329324912'
diff --git a/sklearn/ensemble/voting.py b/sklearn/ensemble/voting.py
--- a/sklearn/ensemble/voting.py
+++ b/sklearn/ensemble/voting.py
@@ -78,6 +78,8 @@ def fit(self, X, y, sample_weight=None):
 
         if sample_weight is not None:
             for name, step in self.estimators:
+                if step is None:
+                    continue
                 if not has_fit_parameter(step, 'sample_weight'):
                     raise ValueError('Underlying estimator \'%s\' does not'
                                      ' support sample weights.' % name)

EOF_114329324912
git apply -v - <<'EOF_114329324912'
diff --git a/sklearn/ensemble/tests/test_voting_none_estimator.py b/sklearn/ensemble/tests/test_voting_none_estimator.py
new file mode 100644
index 0000000000..85439cea67
--- /dev/null
+++ b/sklearn/ensemble/tests/test_voting_none_estimator.py
@@ -0,0 +1,42 @@
+import pytest
+import numpy as np
+
+from sklearn.utils.testing import assert_almost_equal, assert_array_equal
+from sklearn.utils.testing import assert_array_almost_equal
+from sklearn.utils.testing import assert_equal
+from sklearn.utils.testing import assert_raise_message
+from sklearn.exceptions import NotFittedError
+from sklearn.linear_model import LogisticRegression
+from sklearn.naive_bayes import GaussianNB
+from sklearn.ensemble import RandomForestClassifier
+from sklearn.ensemble import VotingClassifier, VotingRegressor
+from sklearn.model_selection import GridSearchCV
+from sklearn import datasets
+from sklearn.model_selection import cross_val_score, train_test_split
+from sklearn.datasets import make_multilabel_classification
+from sklearn.svm import SVC
+from sklearn.multiclass import OneVsRestClassifier
+from sklearn.neighbors import KNeighborsClassifier
+from sklearn.base import BaseEstimator, ClassifierMixin
+from sklearn.dummy import DummyRegressor
+
+
+# Load datasets
+iris = datasets.load_iris()
+X, y = iris.data[:, 1:3], iris.target
+
+
+def test_fit_with_sample_weight_and_none_estimator():
+    """Check that fit with sample_weight works with an estimator set to None."""
+    X, y = datasets.load_iris(return_X_y=True)
+    voter = VotingClassifier(
+        estimators=[('lr', LogisticRegression()),
+                    ('rf', RandomForestClassifier())]
+    )
+    voter.set_params(lr=None)
+    # This call fails with "AttributeError: 'NoneType' object has no
+    # attribute 'fit'" when the bug is present.
+    voter.fit(X, y, sample_weight=np.ones(y.shape))
+
+    # When the bug is fixed, `fit` will succeed and this assertion will pass.
+    assert len(voter.estimators_) == 1

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(sklearn/ensemble/voting\.py)' -m pytest --no-header -rA  -p no:cacheprovider sklearn/ensemble/tests/test_voting_none_estimator.py
cat coverage.cover
git checkout b34751b7ed02b2cfcc36037fb729d4360480a299
git apply /root/pre_state.patch
