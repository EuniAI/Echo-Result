#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD f57fe3f4b3f2cab225749e1b3b38ae1bf80b62f0 >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff f57fe3f4b3f2cab225749e1b3b38ae1bf80b62f0
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/sympy/functions/elementary/hyperbolic.py b/sympy/functions/elementary/hyperbolic.py
--- a/sympy/functions/elementary/hyperbolic.py
+++ b/sympy/functions/elementary/hyperbolic.py
@@ -587,7 +587,7 @@ def eval(cls, arg):
                 x, m = _peeloff_ipi(arg)
                 if m:
                     cothm = coth(m)
-                    if cotm is S.ComplexInfinity:
+                    if cothm is S.ComplexInfinity:
                         return coth(x)
                     else: # cothm == 0
                         return tanh(x)

EOF_114329324912
git apply -v - <<'EOF_114329324912'
diff --git a/sympy/functions/elementary/tests/test_coth_eval_bug.py b/sympy/functions/elementary/tests/test_coth_eval_bug.py
new file mode 100644
index 0000000000..0774618d0d
--- /dev/null
+++ b/sympy/functions/elementary/tests/test_coth_eval_bug.py
@@ -0,0 +1,18 @@
+from sympy import symbols, Symbol, sinh, nan, oo, zoo, pi, asinh, acosh, log, sqrt, \
+    coth, I, cot, E, tanh, tan, cosh, cos, S, sin, Rational, atanh, acoth, \
+    Integer, O, exp, sech, sec, csch, asech, acsch, acos, asin, expand_mul
+
+from sympy.utilities.pytest import raises
+
+
+def test_coth_log_tan_subs():
+    """
+    Test for bug causing NameError in coth.eval.
+
+    The expression coth(log(tan(x))) fails on substitution with
+    integer values due to a NameError. This test ensures that the
+    substitution evaluates correctly.
+    """
+    x = Symbol('x')
+    e = coth(log(tan(x)))
+    assert e.subs(x, 2) == -sec(4)

EOF_114329324912
PYTHONWARNINGS='ignore::UserWarning,ignore::SyntaxWarning' python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(sympy/functions/elementary/hyperbolic\.py)' bin/test -C --verbose sympy/functions/elementary/tests/test_coth_eval_bug.p
cat coverage.cover
git checkout f57fe3f4b3f2cab225749e1b3b38ae1bf80b62f0
git apply /root/pre_state.patch
