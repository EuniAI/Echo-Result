#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD d49a6f13af2f22228d430ac64ac2b518937800d0 >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff d49a6f13af2f22228d430ac64ac2b518937800d0
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -v --no-use-pep517 --no-build-isolation -e .
git apply -v - <<'EOF_114329324912'
diff --git a/sklearn/cluster/tests/test_optics_min_samples.py b/sklearn/cluster/tests/test_optics_min_samples.py
new file mode 100644
index 0000000000..a1c667a700
--- /dev/null
+++ b/sklearn/cluster/tests/test_optics_min_samples.py
@@ -0,0 +1,20 @@
+import numpy as np
+import pytest
+
+from sklearn.cluster.optics_ import OPTICS
+from sklearn.datasets import make_blobs
+
+
+def test_optics_min_samples_float():
+    """Test OPTICS with float min_samples.
+
+    When min_samples is a float, it is converted to an absolute number of
+    samples. This test ensures that it is converted to an integer and not
+    passed as a float to NearestNeighbors, which would raise a TypeError.
+    Non-regression test for issue #15101.
+    """
+    X, _ = make_blobs(n_samples=100, random_state=0)
+    # The following call should not raise a TypeError.
+    # The test passes if fit completes successfully.
+    clust = OPTICS(min_samples=0.1, metric='minkowski')
+    clust.fit(X)

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(sklearn/cluster/optics_\.py)' -m pytest --no-header -rA  -p no:cacheprovider sklearn/cluster/tests/test_optics_min_samples.py
cat coverage.cover
git checkout d49a6f13af2f22228d430ac64ac2b518937800d0
git apply /root/pre_state.patch
