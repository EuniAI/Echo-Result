#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD a36caf5c74fe654cedc488e8a8a05fad388f8406 >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff a36caf5c74fe654cedc488e8a8a05fad388f8406
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/sympy/parsing/tests/test_relational_parsing.py b/sympy/parsing/tests/test_relational_parsing.py
new file mode 100644
index 0000000000..378894afa4
--- /dev/null
+++ b/sympy/parsing/tests/test_relational_parsing.py
@@ -0,0 +1,35 @@
+# -*- coding: utf-8 -*-
+
+
+import sys
+import builtins
+import types
+
+from sympy.assumptions import Q
+from sympy.core import Symbol, Function, Float, Rational, Integer, I, Mul, Pow, Eq
+from sympy.core.relational import Lt
+from sympy.functions import exp, factorial, factorial2, sin, Min, Max
+from sympy.logic import And
+from sympy.series import Limit
+from sympy.testing.pytest import raises, skip
+
+from sympy.parsing.sympy_parser import (
+    parse_expr, standard_transformations, rationalize, TokenError,
+    split_symbols, implicit_multiplication, convert_equals_signs,
+    convert_xor, function_exponentiation, lambda_notation, auto_symbol,
+    repeated_decimals, implicit_multiplication_application,
+    auto_number, factorial_notation, implicit_application,
+    _transformation, T
+    )
+
+
+def test_relational_evaluate_false():
+    """
+    Test that relational expressions are not evaluated when `evaluate=False`.
+
+    See Also
+    ========
+    Issue #22374
+    """
+    expr = parse_expr('1 < 2', evaluate=False)
+    assert expr == Lt(1, 2, evaluate=False)

EOF_114329324912
PYTHONWARNINGS='ignore::UserWarning,ignore::SyntaxWarning' python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(sympy/parsing/sympy_parser\.py)' bin/test -C --verbose sympy/parsing/tests/test_relational_parsing.p
cat coverage.cover
git checkout a36caf5c74fe654cedc488e8a8a05fad388f8406
git apply /root/pre_state.patch
