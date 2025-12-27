#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD a3475b3f9ac662cd425157dd3bdb93ad7111c090 >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff a3475b3f9ac662cd425157dd3bdb93ad7111c090
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/sympy/codegen/tests/test_ast_2.py b/sympy/codegen/tests/test_ast_2.py
new file mode 100644
index 0000000000..2a91862f3d
--- /dev/null
+++ b/sympy/codegen/tests/test_ast_2.py
@@ -0,0 +1,36 @@
+import math
+from sympy.core.containers import Tuple
+from sympy.core.numbers import nan, oo, Float, Integer
+from sympy.core.relational import Lt
+from sympy.core.symbol import symbols, Symbol
+from sympy.functions.elementary.trigonometric import sin
+from sympy.matrices.dense import Matrix
+from sympy.matrices.expressions.matexpr import MatrixSymbol
+from sympy.sets.fancysets import Range
+from sympy.tensor.indexed import Idx, IndexedBase
+from sympy.testing.pytest import raises
+
+
+from sympy.codegen.ast import (
+    Assignment, Attribute, aug_assign, CodeBlock, For, Type, Variable, Pointer, Declaration,
+    AddAugmentedAssignment, SubAugmentedAssignment, MulAugmentedAssignment,
+    DivAugmentedAssignment, ModAugmentedAssignment, value_const, pointer_const,
+    integer, real, complex_, int8, uint8, float16 as f16, float32 as f32,
+    float64 as f64, float80 as f80, float128 as f128, complex64 as c64, complex128 as c128,
+    While, Scope, String, Print, QuotedString, FunctionPrototype, FunctionDefinition, Return,
+    FunctionCall, untyped, IntBaseType, intc, Node, none, NoneToken, Token, Comment
+)
+
+x, y, z, t, x0, x1, x2, a, b = symbols("x, y, z, t, x0, x1, x2, a, b")
+n = symbols("n", integer=True)
+A = MatrixSymbol('A', 3, 1)
+mat = Matrix([1, 2, 3])
+B = IndexedBase('B')
+i = Idx("i", n)
+A22 = MatrixSymbol('A22',2,2)
+B22 = MatrixSymbol('B22',2,2)
+
+
+def test_String_argument_invariance():
+    st = String('foobar')
+    assert st.func(*st.args) == st

EOF_114329324912
PYTHONWARNINGS='ignore::UserWarning,ignore::SyntaxWarning' python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(sympy/codegen/ast\.py)' bin/test -C --verbose sympy/codegen/tests/test_ast_2.p
cat coverage.cover
git checkout a3475b3f9ac662cd425157dd3bdb93ad7111c090
git apply /root/pre_state.patch
