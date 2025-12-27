#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD d7c3045115693e887bcd03599b7ca4650ac5f2cb >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff d7c3045115693e887bcd03599b7ca4650ac5f2cb
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/sympy/core/tests/test_function_evalf.py b/sympy/core/tests/test_function_evalf.py
new file mode 100644
index 0000000000..7e3fc7eef9
--- /dev/null
+++ b/sympy/core/tests/test_function_evalf.py
@@ -0,0 +1,21 @@
+from sympy.core.function import Function
+from sympy.abc import x
+
+
+def test_evalf_on_nested_implemented_function():
+    """
+    Tests that evalf is called recursively on nested implemented functions.
+
+    This is a regression test for the issue where f(g(2)).evalf() would
+    return f(g(2)) instead of the evaluated result.
+    """
+    from sympy.utilities.lambdify import implemented_function
+    f = implemented_function('f', lambda x: x ** 2)
+    g = implemented_function('g', lambda x: 2 * x)
+
+    # f(g(2)) -> f(4) -> 16. The bug is that this doesn't evaluate.
+    assert f(g(2)).evalf() == 16.0
+
+    # Cleanup to avoid leaking the implementation to other tests
+    del f._imp_
+    del g._imp_

EOF_114329324912
PYTHONWARNINGS='ignore::UserWarning,ignore::SyntaxWarning' python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(sympy/core/function\.py)' bin/test -C --verbose sympy/core/tests/test_function_evalf.p
cat coverage.cover
git checkout d7c3045115693e887bcd03599b7ca4650ac5f2cb
git apply /root/pre_state.patch
