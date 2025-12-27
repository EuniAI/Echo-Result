#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 701441853569d370506514083b995d11f9a130bd >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 701441853569d370506514083b995d11f9a130bd
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/sympy/printing/tests/test_mathml2.py b/sympy/printing/tests/test_mathml2.py
new file mode 100644
index 0000000000..94890d1489
--- /dev/null
+++ b/sympy/printing/tests/test_mathml2.py
@@ -0,0 +1,19 @@
+from sympy import diff, Integral, Limit, sin, Symbol, Integer, Rational, cos, \
+    tan, asin, acos, atan, sinh, cosh, tanh, asinh, acosh, atanh, E, I, oo, \
+    pi, GoldenRatio, EulerGamma, Sum, Eq, Ne, Ge, Lt, Float, Matrix, Basic, S, \
+    MatrixSymbol
+from sympy.stats.rv import RandomSymbol
+from sympy.printing.mathml import mathml, MathMLContentPrinter, MathMLPresentationPrinter, \
+    MathMLPrinter
+
+from sympy.utilities.pytest import raises
+
+x = Symbol('x')
+y = Symbol('y')
+mp = MathMLContentPrinter()
+mpp = MathMLPresentationPrinter()
+
+
+def test_issue_15733():
+    x2 = Symbol('x2')
+    assert mathml(x2, printer='presentation') == '<mi>x2</mi>'

EOF_114329324912
PYTHONWARNINGS='ignore::UserWarning,ignore::SyntaxWarning' python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(sympy/printing/mathml\.py)' bin/test -C --verbose sympy/printing/tests/test_mathml2.p
cat coverage.cover
git checkout 701441853569d370506514083b995d11f9a130bd
git apply /root/pre_state.patch
