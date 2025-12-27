#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 1d3327b8e90a186df6972991963a5ae87053259d >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 1d3327b8e90a186df6972991963a5ae87053259d
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/sympy/simplify/tests/test_simplify_complex.py b/sympy/simplify/tests/test_simplify_complex.py
new file mode 100644
index 0000000000..1ae18509ac
--- /dev/null
+++ b/sympy/simplify/tests/test_simplify_complex.py
@@ -0,0 +1,16 @@
+from sympy import (
+    Add, Mul, S, Symbol, cos, cot, pi, I, sin, sqrt, tan, root, csc, sec,
+    powsimp, symbols, sinh, cosh, tanh, coth, sech, csch, Dummy, simplify)
+from sympy.simplify.fu import (
+    L, TR1, TR10, TR10i, TR11, TR12, TR12i, TR13, TR14, TR15, TR16,
+    TR111, TR2, TR2i, TR3, TR5, TR6, TR7, TR8, TR9, TRmorrie, _TR56 as T,
+    TRpower, hyper_as_trig, fu, process_common_addends, trig_split,
+    as_f_sign_1)
+from sympy.utilities.randtest import verify_numerically
+from sympy.core.compatibility import range
+from sympy.abc import a, b, c, x, y, z
+
+
+def test_simplify_complex_power():
+    """Test case for simplifying trig function with complex power."""
+    assert simplify(cos(x)**I) == cos(x)**I

EOF_114329324912
PYTHONWARNINGS='ignore::UserWarning,ignore::SyntaxWarning' python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(sympy/simplify/fu\.py)' bin/test -C --verbose sympy/simplify/tests/test_simplify_complex.p
cat coverage.cover
git checkout 1d3327b8e90a186df6972991963a5ae87053259d
git apply /root/pre_state.patch
