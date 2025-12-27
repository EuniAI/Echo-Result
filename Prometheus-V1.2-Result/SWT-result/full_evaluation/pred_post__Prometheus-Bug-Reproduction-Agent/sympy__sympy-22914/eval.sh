#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD c4e836cdf73fc6aa7bab6a86719a0f08861ffb1d >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff c4e836cdf73fc6aa7bab6a86719a0f08861ffb1d
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/sympy/printing/pycode.py b/sympy/printing/pycode.py
--- a/sympy/printing/pycode.py
+++ b/sympy/printing/pycode.py
@@ -18,6 +18,8 @@
 
 _known_functions = {
     'Abs': 'abs',
+    'Min': 'min',
+    'Max': 'max',
 }
 _known_functions_math = {
     'acos': 'acos',

EOF_114329324912
git apply -v - <<'EOF_114329324912'
diff --git a/sympy/printing/tests/test_pycode_2.py b/sympy/printing/tests/test_pycode_2.py
new file mode 100644
index 0000000000..93890d6bb4
--- /dev/null
+++ b/sympy/printing/tests/test_pycode_2.py
@@ -0,0 +1,30 @@
+from sympy.codegen import Assignment
+from sympy.codegen.ast import none
+from sympy.codegen.cfunctions import expm1, log1p
+from sympy.codegen.scipy_nodes import cosm1
+from sympy.codegen.matrix_nodes import MatrixSolve
+from sympy.core import Expr, Mod, symbols, Eq, Le, Gt, zoo, oo, Rational, Pow
+from sympy.core.numbers import pi
+from sympy.core.singleton import S
+from sympy.functions import acos, KroneckerDelta, Piecewise, sign, sqrt, Min, Max
+from sympy.logic import And, Or
+from sympy.matrices import SparseMatrix, MatrixSymbol, Identity
+from sympy.printing.pycode import (
+    MpmathPrinter, PythonCodePrinter, pycode, SymPyPrinter
+)
+from sympy.printing.numpy import NumPyPrinter, SciPyPrinter
+from sympy.testing.pytest import raises, skip
+from sympy.tensor import IndexedBase
+from sympy.external import import_module
+from sympy.functions.special.gamma_functions import loggamma
+from sympy.parsing.latex import parse_latex
+
+
+x, y, z = symbols('x y z')
+p = IndexedBase("p")
+
+
+def test_pycode_min_max():
+    a, b = symbols('a b')
+    assert pycode(Min(a, b)) == 'min(a, b)'
+    assert pycode(Max(a, b)) == 'max(a, b)'

EOF_114329324912
PYTHONWARNINGS='ignore::UserWarning,ignore::SyntaxWarning' python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(sympy/printing/pycode\.py)' bin/test -C --verbose sympy/printing/tests/test_pycode_2.p
cat coverage.cover
git checkout c4e836cdf73fc6aa7bab6a86719a0f08861ffb1d
git apply /root/pre_state.patch
