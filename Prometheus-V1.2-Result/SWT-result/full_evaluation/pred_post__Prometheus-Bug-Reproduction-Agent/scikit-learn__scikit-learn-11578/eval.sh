#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD dd69361a0d9c6ccde0d2353b00b86e0e7541a3e3 >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff dd69361a0d9c6ccde0d2353b00b86e0e7541a3e3
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -v --no-use-pep517 --no-build-isolation -e .
git apply -v - <<'EOF_114329324912'
diff --git a/sklearn/linear_model/logistic.py b/sklearn/linear_model/logistic.py
--- a/sklearn/linear_model/logistic.py
+++ b/sklearn/linear_model/logistic.py
@@ -922,7 +922,7 @@ def _log_reg_scoring_path(X, y, train, test, pos_class=None, Cs=10,
         check_input=False, max_squared_sum=max_squared_sum,
         sample_weight=sample_weight)
 
-    log_reg = LogisticRegression(fit_intercept=fit_intercept)
+    log_reg = LogisticRegression(multi_class=multi_class)
 
     # The score method of Logistic Regression has a classes_ attribute.
     if multi_class == 'ovr':

EOF_114329324912
git apply -v - <<'EOF_114329324912'
diff --git a/sklearn/linear_model/tests/test_logistic_cv.py b/sklearn/linear_model/tests/test_logistic_cv.py
new file mode 100644
index 0000000000..7cce9700c9
--- /dev/null
+++ b/sklearn/linear_model/tests/test_logistic_cv.py
@@ -0,0 +1,59 @@
+import numpy as np
+import pytest
+
+from sklearn import preprocessing, linear_model
+from sklearn.metrics import log_loss
+from sklearn.utils import extmath
+from sklearn.utils.testing import assert_almost_equal
+
+
+def test_logistic_cv_multinomial_scoring():
+    """
+    Test for bug #8720.
+
+    `LogisticRegressionCV(multi_class='multinomial')` with a probabilistic
+    scorer should use the multinomial (softmax) function, not the OvR
+    approach to calculate probabilities. This test checks that the score
+    returned by the internal scoring function `_log_reg_scoring_path`
+    matches the score calculated manually using the softmax function.
+    """
+    # Based on the minimal example from the issue description
+    np.random.seed(seed=1234)
+    samples = 200
+    features = 5
+    scorer = 'neg_log_loss'
+
+    X = np.random.random(size=(samples, features))
+    y = np.random.choice(['a', 'b', 'c'], size=samples)
+
+    test_size = int(samples / 10.0)
+    test = np.random.choice(range(samples), size=test_size, replace=False)
+    train = [idx for idx in range(samples) if idx not in test]
+    X_test, y_test = X[test], y[test]
+
+    # Get the score from the internal scoring path function, which is
+    # what LogisticRegressionCV uses.
+    coefs, _, scores, _ = linear_model.logistic._log_reg_scoring_path(
+        X, y, train, test, fit_intercept=True, scoring=scorer,
+        multi_class='multinomial')
+
+    # We only care about the first C value for this test
+    c_index = 0
+    score_from_path = scores[c_index]
+    coef_path = coefs[c_index]
+
+    # Manually calculate the score that *should* be returned, using the
+    # multinomial (softmax) approach.
+    classes = np.unique(y)
+    log_reg = linear_model.LogisticRegression(multi_class='multinomial')
+    log_reg.coef_ = coef_path[:, :-1]
+    log_reg.intercept_ = coef_path[:, -1]
+    log_reg.classes_ = classes
+
+    decision = log_reg.decision_function(X_test)
+    probas = extmath.softmax(decision)
+    correct_score = -log_loss(y_test, probas, labels=classes)
+
+    # This assertion will fail before the fix because score_from_path is
+    # calculated using the 'ovr' method instead of 'multinomial'.
+    assert_almost_equal(score_from_path, correct_score)

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(sklearn/linear_model/logistic\.py)' -m pytest --no-header -rA  -p no:cacheprovider sklearn/linear_model/tests/test_logistic_cv.py
cat coverage.cover
git checkout dd69361a0d9c6ccde0d2353b00b86e0e7541a3e3
git apply /root/pre_state.patch
