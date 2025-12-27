#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 3d997697fdd166eff428ea9fd35734b6a8ba113e >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 3d997697fdd166eff428ea9fd35734b6a8ba113e
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -v --no-use-pep517 --no-build-isolation -e .
git apply -v - <<'EOF_114329324912'
diff --git a/sklearn/utils/_show_versions.py b/sklearn/utils/_show_versions.py
--- a/sklearn/utils/_show_versions.py
+++ b/sklearn/utils/_show_versions.py
@@ -48,6 +48,7 @@ def _get_deps_info():
         "Cython",
         "pandas",
         "matplotlib",
+        "joblib",
     ]
 
     def get_version(module):

EOF_114329324912
git apply -v - <<'EOF_114329324912'
diff --git a/sklearn/utils/tests/test_show_versions_joblib.py b/sklearn/utils/tests/test_show_versions_joblib.py
new file mode 100644
index 0000000000..d17c72c78f
--- /dev/null
+++ b/sklearn/utils/tests/test_show_versions_joblib.py
@@ -0,0 +1,7 @@
+from sklearn.utils._show_versions import _get_deps_info
+
+
+def test_get_deps_info_for_joblib():
+    """Test that _get_deps_info includes joblib."""
+    deps_info = _get_deps_info()
+    assert 'joblib' in deps_info

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(sklearn/utils/_show_versions\.py)' -m pytest --no-header -rA  -p no:cacheprovider sklearn/utils/tests/test_show_versions_joblib.py
cat coverage.cover
git checkout 3d997697fdd166eff428ea9fd35734b6a8ba113e
git apply /root/pre_state.patch
