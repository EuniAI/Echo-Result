#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 2dfa7457f20ee187fbb09b5b6a1631da4458388c >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 2dfa7457f20ee187fbb09b5b6a1631da4458388c
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/sympy/matrices/tests/test_sparse_hstack_bug.py b/sympy/matrices/tests/test_sparse_hstack_bug.py
new file mode 100644
index 0000000000..646627e747
--- /dev/null
+++ b/sympy/matrices/tests/test_sparse_hstack_bug.py
@@ -0,0 +1,46 @@
+import collections
+import random
+import warnings
+
+from sympy import (
+    Abs, Add, E, Float, I, Integer, Max, Min, N, Poly, Pow, PurePoly, Rational,
+    S, Symbol, cos, exp, oo, pi, signsimp, simplify, sin, sqrt, symbols,
+    sympify, trigsimp, tan, sstr, diff)
+from sympy.matrices.matrices import (ShapeError, MatrixError,
+    NonSquareMatrixError, DeferredVector, _find_reasonable_pivot_naive,
+    _simplify)
+from sympy.matrices import (
+    GramSchmidt, ImmutableMatrix, ImmutableSparseMatrix, Matrix,
+    SparseMatrix, casoratian, diag, eye, hessian,
+    matrix_multiply_elementwise, ones, randMatrix, rot_axis1, rot_axis2,
+    rot_axis3, wronskian, zeros, MutableDenseMatrix, ImmutableDenseMatrix)
+from sympy.core.compatibility import long, iterable, range
+from sympy.core import Tuple
+from sympy.utilities.iterables import flatten, capture
+from sympy.utilities.pytest import raises, XFAIL, slow, skip
+from sympy.utilities.exceptions import SymPyDeprecationWarning
+from sympy.solvers import solve
+from sympy.assumptions import Q
+
+from sympy.abc import a, b, c, d, x, y, z
+
+def test_sparse_hstack_zero_row_matrices():
+    """
+    Test hstack with sparse matrices having zero rows.
+
+    This test checks for a regression where the shape of the resulting
+    matrix from hstack is incorrect when dealing with zero-row sparse
+    matrices. The number of columns should be the sum of the columns of
+    the input matrices. This reproduces a bug similar to the one reported
+    but for the SparseMatrix class.
+    """
+    M1 = SparseMatrix.zeros(0, 0)
+    M2 = SparseMatrix.zeros(0, 1)
+    M3 = SparseMatrix.zeros(0, 2)
+    M4 = SparseMatrix.zeros(0, 3)
+
+    # The correct shape should be (0, 6) by summing the columns (0+1+2+3).
+    # If the bug is present, the shape would likely be (0, 3), matching
+    # the columns of the last matrix, which would cause this assertion to fail.
+    result = SparseMatrix.hstack(M1, M2, M3, M4)
+    assert result.shape == (0, 6)

EOF_114329324912
PYTHONWARNINGS='ignore::UserWarning,ignore::SyntaxWarning' python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(sympy/matrices/sparse\.py)' bin/test -C --verbose sympy/matrices/tests/test_sparse_hstack_bug.p
cat coverage.cover
git checkout 2dfa7457f20ee187fbb09b5b6a1631da4458388c
git apply /root/pre_state.patch
