#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD d9b18c518d64d0ebe8e35a98c2fb519938b9b151 >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff d9b18c518d64d0ebe8e35a98c2fb519938b9b151
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/sympy/polys/tests/test_itermonomials.py b/sympy/polys/tests/test_itermonomials.py
new file mode 100644
index 0000000000..27a0aee21c
--- /dev/null
+++ b/sympy/polys/tests/test_itermonomials.py
@@ -0,0 +1,25 @@
+from sympy.polys.monomials import itermonomials
+from sympy.core import symbols
+
+
+def test_itermonomials_min_degrees():
+    """
+    Test based on the issue report that `itermonomials` with `min_degrees`
+    fails to return all monomials of the given degree.
+    """
+    x1, x2, x3 = symbols('x1, x2, x3')
+    states = [x1, x2, x3]
+    max_degrees = 3
+    min_degrees = 3
+
+    monomials = set(itermonomials(states, max_degrees, min_degrees=min_degrees))
+
+    expected = {
+        x1**3, x2**3, x3**3,
+        x1**2*x2, x1*x2**2,
+        x1**2*x3, x1*x3**2,
+        x2**2*x3, x2*x3**2,
+        x1*x2*x3,
+    }
+
+    assert monomials == expected

EOF_114329324912
PYTHONWARNINGS='ignore::UserWarning,ignore::SyntaxWarning' python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(sympy/polys/monomials\.py)' bin/test -C --verbose sympy/polys/tests/test_itermonomials.p
cat coverage.cover
git checkout d9b18c518d64d0ebe8e35a98c2fb519938b9b151
git apply /root/pre_state.patch
