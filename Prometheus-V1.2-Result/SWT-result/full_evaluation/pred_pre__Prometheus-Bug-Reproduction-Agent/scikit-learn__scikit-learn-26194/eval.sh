#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD e886ce4e1444c61b865e7839c9cff5464ee20ace >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff e886ce4e1444c61b865e7839c9cff5464ee20ace
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -v --no-use-pep517 --no-build-isolation -e .
git apply -v - <<'EOF_114329324912'
diff --git a/sklearn/metrics/tests/test_roc_curve_gh_26121.py b/sklearn/metrics/tests/test_roc_curve_gh_26121.py
new file mode 100644
index 0000000000..40dab21eb8
--- /dev/null
+++ b/sklearn/metrics/tests/test_roc_curve_gh_26121.py
@@ -0,0 +1,53 @@
+import re
+import pytest
+import numpy as np
+import warnings
+from scipy.sparse import csr_matrix
+from scipy import stats
+
+from sklearn import datasets
+from sklearn import svm
+
+from sklearn.utils.extmath import softmax
+from sklearn.datasets import make_multilabel_classification
+from sklearn.random_projection import _sparse_random_matrix
+from sklearn.utils.validation import check_array, check_consistent_length
+from sklearn.utils.validation import check_random_state
+
+from sklearn.utils._testing import assert_allclose
+from sklearn.utils._testing import assert_almost_equal
+from sklearn.utils._testing import assert_array_equal
+from sklearn.utils._testing import assert_array_almost_equal
+
+from sklearn.metrics import accuracy_score
+from sklearn.metrics import auc
+from sklearn.metrics import average_precision_score
+from sklearn.metrics import coverage_error
+from sklearn.metrics import det_curve
+from sklearn.metrics import label_ranking_average_precision_score
+from sklearn.metrics import precision_recall_curve
+from sklearn.metrics import label_ranking_loss
+from sklearn.metrics import roc_auc_score
+from sklearn.metrics import roc_curve
+from sklearn.metrics._ranking import _ndcg_sample_scores, _dcg_sample_scores
+from sklearn.metrics import ndcg_score, dcg_score
+from sklearn.metrics import top_k_accuracy_score
+
+from sklearn.exceptions import UndefinedMetricWarning
+from sklearn.model_selection import train_test_split
+from sklearn.linear_model import LogisticRegression
+from sklearn.preprocessing import label_binarize
+
+
+def test_roc_curve_with_probability_estimates():
+    """Check that roc_curve thresholds are <= 1 for probability estimates.
+
+    When y_score consists of probability estimates, the thresholds should not
+    exceed 1.
+    Non-regression test for gh-26121.
+    """
+    rng = np.random.RandomState(42)
+    y_true = rng.randint(0, 2, size=10)
+    y_score = rng.rand(10)
+    _, _, thresholds = roc_curve(y_true, y_score)
+    assert np.all(thresholds <= 1)

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(sklearn/metrics/_ranking\.py)' -m pytest --no-header -rA  -p no:cacheprovider sklearn/metrics/tests/test_roc_curve_gh_26121.py
cat coverage.cover
git checkout e886ce4e1444c61b865e7839c9cff5464ee20ace
git apply /root/pre_state.patch
