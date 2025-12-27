#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD b8fe457a02cc24b3470ff678d0099c350b7fef43 >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff b8fe457a02cc24b3470ff678d0099c350b7fef43
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/sympy/printing/tests/test_pycode_bug.py b/sympy/printing/tests/test_pycode_bug.py
new file mode 100644
index 0000000000..d009078682
--- /dev/null
+++ b/sympy/printing/tests/test_pycode_bug.py
@@ -0,0 +1,25 @@
+# -*- coding: utf-8 -*-
+from __future__ import absolute_import
+
+from sympy.codegen import Assignment
+from sympy.codegen.ast import none
+from sympy.core import Expr, Mod, symbols, Eq, Le, Gt, zoo, oo, Rational
+from sympy.core.numbers import pi
+from sympy.functions import acos, Piecewise, sign
+from sympy.logic import And, Or
+from sympy.matrices import SparseMatrix, MatrixSymbol
+from sympy.printing.pycode import (
+    MpmathPrinter, NumPyPrinter, PythonCodePrinter, pycode, SciPyPrinter
+)
+from sympy.utilities.pytest import raises
+from sympy import IndexedBase
+
+x, y, z = symbols('x y z')
+
+
+def test_pycode_indexed():
+    """
+    Test for printing Indexed objects.
+    """
+    p = IndexedBase("p")
+    assert pycode(p[0]) == 'p[0]'

EOF_114329324912
PYTHONWARNINGS='ignore::UserWarning,ignore::SyntaxWarning' python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(sympy/printing/pycode\.py)' bin/test -C --verbose sympy/printing/tests/test_pycode_bug.p
cat coverage.cover
git checkout b8fe457a02cc24b3470ff678d0099c350b7fef43
git apply /root/pre_state.patch
