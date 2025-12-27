#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 3f8c8c2377cb8e0daaf8073e8d03ac7d87580813 >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 3f8c8c2377cb8e0daaf8073e8d03ac7d87580813
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/sympy/utilities/tests/test_lambdify_mod.py b/sympy/utilities/tests/test_lambdify_mod.py
new file mode 100644
index 0000000000..1cd92d3429
--- /dev/null
+++ b/sympy/utilities/tests/test_lambdify_mod.py
@@ -0,0 +1,17 @@
+import pytest
+from sympy import Mod, lambdify, symbols
+
+def test_lambdify_mod_with_empty_modules():
+    """
+    Test for bug in lambdify that incorrectly handles multipliers with Mod.
+
+    When lambdifying an expression like `c * Mod(a, b)` with `modules=[]`,
+    the multiplier `c` was incorrectly moved into the first argument of `Mod`,
+    resulting in `Mod(c * a, b)`. This test checks for the correct behavior.
+    """
+    x, y = symbols('x y')
+    expr = -Mod(x, y)
+    g = lambdify([x, y], expr, modules=[])
+    # The buggy code returns (-3 % 7) which is 4.
+    # The correct result is -(3 % 7) which is -3.
+    assert g(3, 7) == -3

EOF_114329324912
PYTHONWARNINGS='ignore::UserWarning,ignore::SyntaxWarning' python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(sympy/printing/codeprinter\.py|sympy/printing/precedence\.py)' bin/test -C --verbose sympy/utilities/tests/test_lambdify_mod.p
cat coverage.cover
git checkout 3f8c8c2377cb8e0daaf8073e8d03ac7d87580813
git apply /root/pre_state.patch
