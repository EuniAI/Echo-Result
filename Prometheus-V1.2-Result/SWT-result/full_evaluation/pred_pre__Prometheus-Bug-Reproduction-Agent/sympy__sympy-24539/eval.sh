#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 193e3825645d93c73e31cdceb6d742cc6919624d >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 193e3825645d93c73e31cdceb6d742cc6919624d
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/sympy/polys/tests/test_poly_element_as_expr.py b/sympy/polys/tests/test_poly_element_as_expr.py
new file mode 100644
index 0000000000..2994c1e926
--- /dev/null
+++ b/sympy/polys/tests/test_poly_element_as_expr.py
@@ -0,0 +1,23 @@
+from sympy.polys.rings import ring
+from sympy.polys.domains import ZZ
+from sympy.core import symbols
+
+
+def test_PolyElement_as_expr_new_symbols():
+    """
+    Tests that PolyElement.as_expr() correctly uses the provided symbols.
+
+    The bug described in the issue is that `as_expr` ignores the symbols
+    passed to it, instead using the symbols from the ring definition.
+    """
+    R, x, y, z = ring("x,y,z", ZZ)
+    f = 3*x**2*y - x*y*z + 7*z**3 + 1
+
+    U, V, W = symbols("u,v,w")
+
+    # The expected expression should use the new symbols U, V, W
+    expected_expr = 3*U**2*V - U*V*W + 7*W**3 + 1
+
+    # This assertion will fail if the bug is present, as f.as_expr(U, V, W)
+    # will incorrectly return an expression in terms of x, y, z.
+    assert f.as_expr(U, V, W) == expected_expr

EOF_114329324912
PYTHONWARNINGS='ignore::UserWarning,ignore::SyntaxWarning' python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(sympy/polys/rings\.py)' bin/test -C --verbose sympy/polys/tests/test_poly_element_as_expr.p
cat coverage.cover
git checkout 193e3825645d93c73e31cdceb6d742cc6919624d
git apply /root/pre_state.patch
