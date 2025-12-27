#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 67e3c956083d0128a621f65ee86a7dacd4f9f19f >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 67e3c956083d0128a621f65ee86a7dacd4f9f19f
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/sympy/matrices/tests/test_matrices_col_insert.py b/sympy/matrices/tests/test_matrices_col_insert.py
new file mode 100644
index 0000000000..e098505d52
--- /dev/null
+++ b/sympy/matrices/tests/test_matrices_col_insert.py
@@ -0,0 +1,18 @@
+from sympy.matrices import Matrix, eye, ones
+
+def test_col_insert_bug():
+    """
+    Test reproducing a bug in col_insert where the right-hand side of the
+    matrix is incorrectly shifted after insertion.
+    """
+    M = eye(6)
+    V = 2 * ones(6, 2)
+    result = M.col_insert(3, V)
+    expected = Matrix([
+        [1, 0, 0, 2, 2, 0, 0, 0],
+        [0, 1, 0, 2, 2, 0, 0, 0],
+        [0, 0, 1, 2, 2, 0, 0, 0],
+        [0, 0, 0, 2, 2, 1, 0, 0],
+        [0, 0, 0, 2, 2, 0, 1, 0],
+        [0, 0, 0, 2, 2, 0, 0, 1]])
+    assert result == expected

EOF_114329324912
PYTHONWARNINGS='ignore::UserWarning,ignore::SyntaxWarning' python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(sympy/matrices/common\.py)' bin/test -C --verbose sympy/matrices/tests/test_matrices_col_insert.p
cat coverage.cover
git checkout 67e3c956083d0128a621f65ee86a7dacd4f9f19f
git apply /root/pre_state.patch
