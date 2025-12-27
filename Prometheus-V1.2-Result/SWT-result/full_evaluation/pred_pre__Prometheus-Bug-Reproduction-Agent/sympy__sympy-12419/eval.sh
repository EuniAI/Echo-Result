#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 479939f8c65c8c2908bbedc959549a257a7c0b0b >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 479939f8c65c8c2908bbedc959549a257a7c0b0b
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/sympy/concrete/tests/test_identity_sum.py b/sympy/concrete/tests/test_identity_sum.py
new file mode 100644
index 0000000000..d0a7b1e9d0
--- /dev/null
+++ b/sympy/concrete/tests/test_identity_sum.py
@@ -0,0 +1,21 @@
+from sympy import Symbol, Sum, Identity
+
+def test_identity_sum():
+    """
+    Test for summing elements of an Identity matrix.
+    The total sum of elements in an n x n identity matrix should be n.
+    This test reproduces a bug where the sum incorrectly evaluates to 0.
+    """
+    n = Symbol('n', integer=True, positive=True)
+    i, j = Symbol('i', integer=True), Symbol('j', integer=True)
+    
+    # Create an Identity matrix directly. Its elements are equivalent to KroneckerDelta(i, j).
+    identity_matrix = Identity(n)
+    
+    # The bug is in the evaluation of the nested sum.
+    # The inner sum Sum(identity_matrix[i, j], (i, 0, n-1)) correctly evaluates
+    # to 1 for any j in range. The outer sum should then sum this 1 'n' times.
+    total_sum = Sum(Sum(identity_matrix[i, j], (i, 0, n - 1)), (j, 0, n - 1)).doit()
+    
+    # This assertion will fail because the bug causes total_sum to be 0 instead of n.
+    assert total_sum == n

EOF_114329324912
PYTHONWARNINGS='ignore::UserWarning,ignore::SyntaxWarning' python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(sympy/matrices/expressions/matexpr\.py)' bin/test -C --verbose sympy/concrete/tests/test_identity_sum.p
cat coverage.cover
git checkout 479939f8c65c8c2908bbedc959549a257a7c0b0b
git apply /root/pre_state.patch
