#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD d360ffa7c5896a91ae498b3fb9cf464464ce8f34 >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff d360ffa7c5896a91ae498b3fb9cf464464ce8f34
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -v --no-use-pep517 --no-build-isolation -e .
git apply -v - <<'EOF_114329324912'
diff --git a/sklearn/decomposition/tests/test_sparse_coder.py b/sklearn/decomposition/tests/test_sparse_coder.py
new file mode 100644
index 0000000000..4ce6fc9372
--- /dev/null
+++ b/sklearn/decomposition/tests/test_sparse_coder.py
@@ -0,0 +1,40 @@
+import pytest
+
+import numpy as np
+import itertools
+
+from sklearn.exceptions import ConvergenceWarning
+
+from sklearn.utils import check_array
+
+from sklearn.utils.testing import assert_array_almost_equal
+from sklearn.utils.testing import assert_array_equal
+from sklearn.utils.testing import assert_equal
+from sklearn.utils.testing import assert_less
+from sklearn.utils.testing import assert_raises
+from sklearn.utils.testing import ignore_warnings
+from sklearn.utils.testing import TempMemmap
+
+from sklearn.decomposition import DictionaryLearning
+from sklearn.decomposition import MiniBatchDictionaryLearning
+from sklearn.decomposition import SparseCoder
+from sklearn.decomposition import dict_learning
+from sklearn.decomposition import dict_learning_online
+from sklearn.decomposition import sparse_encode
+
+
+rng_global = np.random.RandomState(0)
+n_samples, n_features = 10, 8
+X = rng_global.randn(n_samples, n_features)
+
+
+def test_sparse_coder_lasso_cd_max_iter():
+    n_components = 12
+    rng = np.random.RandomState(0)
+    V = rng.randn(n_components, n_features)
+    # This will raise a TypeError because max_iter is not a valid argument.
+    # When the bug is fixed, this should work without errors.
+    coder = SparseCoder(dictionary=V, transform_algorithm='lasso_cd',
+                        transform_alpha=0.001, max_iter=1)
+    with ignore_warnings(category=ConvergenceWarning):
+        coder.transform(X)

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(examples/decomposition/plot_sparse_coding\.py|sklearn/decomposition/dict_learning\.py)' -m pytest --no-header -rA  -p no:cacheprovider sklearn/decomposition/tests/test_sparse_coder.py
cat coverage.cover
git checkout d360ffa7c5896a91ae498b3fb9cf464464ce8f34
git apply /root/pre_state.patch
