#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 97523985b39ecde369d83352d7c3baf403b60a22 >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 97523985b39ecde369d83352d7c3baf403b60a22
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -v --no-use-pep517 --no-build-isolation -e .
git apply -v - <<'EOF_114329324912'
diff --git a/sklearn/metrics/cluster/supervised.py b/sklearn/metrics/cluster/supervised.py
--- a/sklearn/metrics/cluster/supervised.py
+++ b/sklearn/metrics/cluster/supervised.py
@@ -852,11 +852,12 @@ def fowlkes_mallows_score(labels_true, labels_pred, sparse=False):
     labels_true, labels_pred = check_clusterings(labels_true, labels_pred)
     n_samples, = labels_true.shape
 
-    c = contingency_matrix(labels_true, labels_pred, sparse=True)
+    c = contingency_matrix(labels_true, labels_pred,
+                           sparse=True).astype(np.int64)
     tk = np.dot(c.data, c.data) - n_samples
     pk = np.sum(np.asarray(c.sum(axis=0)).ravel() ** 2) - n_samples
     qk = np.sum(np.asarray(c.sum(axis=1)).ravel() ** 2) - n_samples
-    return tk / np.sqrt(pk * qk) if tk != 0. else 0.
+    return np.sqrt(tk / pk) * np.sqrt(tk / qk) if tk != 0. else 0.
 
 
 def entropy(labels):

EOF_114329324912
git apply -v - <<'EOF_114329324912'
diff --git a/sklearn/metrics/cluster/tests/test_fowlkes_mallows_score_overflow.py b/sklearn/metrics/cluster/tests/test_fowlkes_mallows_score_overflow.py
new file mode 100644
index 0000000000..6dd7a94ccb
--- /dev/null
+++ b/sklearn/metrics/cluster/tests/test_fowlkes_mallows_score_overflow.py
@@ -0,0 +1,25 @@
+import numpy as np
+
+from sklearn.metrics.cluster.supervised import fowlkes_mallows_score
+from sklearn.utils.testing import assert_almost_equal
+
+
+def test_fowlkes_mallows_score_overflow():
+    """Test for overflow in fowlkes_mallows_score with large clusters."""
+    # When the number of samples in clusters is large, the intermediate
+    # values `pk` and `qk` in the fowlkes_mallows_score calculation can
+    # become very large. Their product can overflow standard integer types,
+    # leading to incorrect results (e.g., NaN).
+    #
+    # We create two large clusters to ensure the product `pk * qk` overflows
+    # even 64-bit integers.
+    n_samples_per_cluster = 80000
+    labels = np.array([0] * n_samples_per_cluster + [1] * n_samples_per_cluster,
+                      dtype=np.int32)
+
+    # For a perfect clustering, the score should be 1.0.
+    # The buggy version calculates a large `pk` and `qk`, their product
+    # overflows, resulting in a negative number under the square root,
+    # and a final score of NaN.
+    score = fowlkes_mallows_score(labels, labels)
+    assert_almost_equal(score, 1.0)

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(sklearn/metrics/cluster/supervised\.py)' -m pytest --no-header -rA  -p no:cacheprovider sklearn/metrics/cluster/tests/test_fowlkes_mallows_score_overflow.py
cat coverage.cover
git checkout 97523985b39ecde369d83352d7c3baf403b60a22
git apply /root/pre_state.patch
