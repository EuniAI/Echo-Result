#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 3eacf948e0f95ef957862568d87ce082f378e186 >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 3eacf948e0f95ef957862568d87ce082f378e186
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -v --no-use-pep517 --no-build-isolation -e .
git apply -v - <<'EOF_114329324912'
diff --git a/sklearn/cluster/tests/test_kmeans_n_jobs_consistency.py b/sklearn/cluster/tests/test_kmeans_n_jobs_consistency.py
new file mode 100644
index 0000000000..fdaa43581d
--- /dev/null
+++ b/sklearn/cluster/tests/test_kmeans_n_jobs_consistency.py
@@ -0,0 +1,31 @@
+import pytest
+import numpy as np
+
+from sklearn.cluster import KMeans
+from sklearn.datasets.samples_generator import make_blobs
+from sklearn.utils.testing import assert_almost_equal
+from sklearn.utils.testing import if_safe_multiprocessing_with_blas
+
+
+@if_safe_multiprocessing_with_blas
+def test_kmeans_n_jobs_consistency():
+    """Test that KMeans gives consistent results for n_jobs=1 and n_jobs > 1.
+
+    This is a non-regression test for a bug where the inertia would differ.
+    See: https://github.com/scikit-learn/scikit-learn/issues/9850
+    """
+    # Generate data from the bug report
+    X, _ = make_blobs(n_samples=10000, centers=10, n_features=2, random_state=2)
+
+    # Run KMeans with n_jobs=1
+    kmeans_1_job = KMeans(n_clusters=10, random_state=2, n_jobs=1)
+    kmeans_1_job.fit(X)
+    inertia_1_job = kmeans_1_job.inertia_
+
+    # Run KMeans with n_jobs=2
+    kmeans_2_jobs = KMeans(n_clusters=10, random_state=2, n_jobs=2)
+    kmeans_2_jobs.fit(X)
+    inertia_2_jobs = kmeans_2_jobs.inertia_
+
+    # The inertias should be almost equal
+    assert_almost_equal(inertia_1_job, inertia_2_jobs)

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(sklearn/cluster/k_means_\.py)' -m pytest --no-header -rA  -p no:cacheprovider sklearn/cluster/tests/test_kmeans_n_jobs_consistency.py
cat coverage.cover
git checkout 3eacf948e0f95ef957862568d87ce082f378e186
git apply /root/pre_state.patch
