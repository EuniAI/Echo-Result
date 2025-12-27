#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 6fd65310fa3167b9626c38a5487e171ca407d988 >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 6fd65310fa3167b9626c38a5487e171ca407d988
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/sympy/core/tests/test_even_implies_finite.py b/sympy/core/tests/test_even_implies_finite.py
new file mode 100644
index 0000000000..8f8ddc1811
--- /dev/null
+++ b/sympy/core/tests/test_even_implies_finite.py
@@ -0,0 +1,15 @@
+from sympy import I, sqrt, log, exp, sin, asin, factorial, Mod, pi
+from sympy.core import Symbol, S, Rational, Integer, Dummy, Wild, Pow
+from sympy.core.facts import InconsistentAssumptions
+from sympy import simplify
+from sympy.core.compatibility import range
+
+from sympy.utilities.pytest import raises, XFAIL
+
+
+def test_even_implies_finite():
+    """
+    Test that a Symbol that is even is also finite.
+    """
+    m = Symbol('m', even=True)
+    assert m.is_finite is True

EOF_114329324912
PYTHONWARNINGS='ignore::UserWarning,ignore::SyntaxWarning' python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(sympy/tensor/indexed\.py|sympy/assumptions/ask_generated\.py|sympy/core/assumptions\.py|sympy/printing/tree\.py|sympy/core/power\.py|sympy/assumptions/ask\.py)' bin/test -C --verbose sympy/core/tests/test_even_implies_finite.p
cat coverage.cover
git checkout 6fd65310fa3167b9626c38a5487e171ca407d988
git apply /root/pre_state.patch
