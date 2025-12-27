#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 10de1a18a0efac0b19b611e40c928250dda688bf >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 10de1a18a0efac0b19b611e40c928250dda688bf
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/sympy/polys/matrices/normalforms.py b/sympy/polys/matrices/normalforms.py
--- a/sympy/polys/matrices/normalforms.py
+++ b/sympy/polys/matrices/normalforms.py
@@ -205,16 +205,19 @@ def _hermite_normal_form(A):
     if not A.domain.is_ZZ:
         raise DMDomainError('Matrix must be over domain ZZ.')
     # We work one row at a time, starting from the bottom row, and working our
-    # way up. The total number of rows we will consider is min(m, n), where
-    # A is an m x n matrix.
+    # way up.
     m, n = A.shape
-    rows = min(m, n)
     A = A.to_dense().rep.copy()
     # Our goal is to put pivot entries in the rightmost columns.
     # Invariant: Before processing each row, k should be the index of the
     # leftmost column in which we have so far put a pivot.
     k = n
-    for i in range(m - 1, m - 1 - rows, -1):
+    for i in range(m - 1, -1, -1):
+        if k == 0:
+            # This case can arise when n < m and we've already found n pivots.
+            # We don't need to consider any more rows, because this is already
+            # the maximum possible number of pivots.
+            break
         k -= 1
         # k now points to the column in which we want to put a pivot.
         # We want zeros in all entries to the left of the pivot column.

EOF_114329324912
git apply -v - <<'EOF_114329324912'
diff --git a/sympy/matrices/tests/test_hermite_normal_form_bug.py b/sympy/matrices/tests/test_hermite_normal_form_bug.py
new file mode 100644
index 0000000000..fa8f6670e9
--- /dev/null
+++ b/sympy/matrices/tests/test_hermite_normal_form_bug.py
@@ -0,0 +1,32 @@
+import pytest
+from sympy import Matrix
+from sympy.matrices.normalforms import hermite_normal_form
+import numpy as np
+
+def test_hermite_normal_form_rank_deficient_bug():
+    """
+    Tests for a bug where HNF incorrectly identifies a matrix as
+    rank-deficient, based on a user-provided example.
+
+    This test uses an interpretation of the user's `np.flip` that flips
+    along both axes, which is the default numpy behavior and leads to a
+    different input matrix that may trigger the bug. The assertion checks
+    for the correct output shape, as the bug is reported to remove a row
+    (i.e., change the shape).
+    """
+    # The user's expression starts with `np.flip(np.array(...))`.
+    # The default for np.flip on a 2D array is to reverse both axes.
+    # np.array([[5, 8, 12], [0, 0, 1]]) -> flipped -> np.array([[1, 0, 0], [12, 8, 5]])
+    init_matrix = Matrix([[1, 0, 0], [12, 8, 5]])
+
+    # The HNF is then calculated on the transpose of this matrix.
+    m = init_matrix.T  # This is Matrix([[1, 12], [0, 8], [0, 5]])
+
+    # This matrix is 3x2 and has rank 2. The HNF should also be 3x2.
+    # The bug is expected to cause a 3x1 matrix to be returned.
+    hnf_matrix = hermite_normal_form(m)
+
+    # Asserting the shape is the most direct test for the reported bug,
+    # which is that a row is "removed" from the final result, implying a
+    # column was dropped during the HNF calculation.
+    assert hnf_matrix.shape == (3, 2)

EOF_114329324912
PYTHONWARNINGS='ignore::UserWarning,ignore::SyntaxWarning' python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(sympy/polys/matrices/normalforms\.py)' bin/test -C --verbose sympy/matrices/tests/test_hermite_normal_form_bug.p
cat coverage.cover
git checkout 10de1a18a0efac0b19b611e40c928250dda688bf
git apply /root/pre_state.patch
