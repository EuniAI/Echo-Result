#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD aefdd023dc4f73c441953ed51f5f05a076f0862f >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff aefdd023dc4f73c441953ed51f5f05a076f0862f
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/sympy/simplify/simplify.py b/sympy/simplify/simplify.py
--- a/sympy/simplify/simplify.py
+++ b/sympy/simplify/simplify.py
@@ -251,7 +251,7 @@ def posify(eq):
             eq[i] = e.subs(reps)
         return f(eq), {r: s for s, r in reps.items()}
 
-    reps = {s: Dummy(s.name, positive=True)
+    reps = {s: Dummy(s.name, positive=True, **s.assumptions0)
                  for s in eq.free_symbols if s.is_positive is None}
     eq = eq.subs(reps)
     return eq, {r: s for s, r in reps.items()}

EOF_114329324912
git apply -v - <<'EOF_114329324912'
diff --git a/sympy/core/tests/test_posify.py b/sympy/core/tests/test_posify.py
new file mode 100644
index 0000000000..d111afa19c
--- /dev/null
+++ b/sympy/core/tests/test_posify.py
@@ -0,0 +1,13 @@
+from sympy import (
+    Symbol,
+    posify,
+)
+
+
+def test_posify_finite():
+    """
+    Tests that posify preserves the 'finite' assumption.
+    """
+    x = Symbol('x', finite=True)
+    xp, _ = posify(x)
+    assert xp.is_finite is True

EOF_114329324912
PYTHONWARNINGS='ignore::UserWarning,ignore::SyntaxWarning' python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(sympy/simplify/simplify\.py)' bin/test -C --verbose sympy/core/tests/test_posify.p
cat coverage.cover
git checkout aefdd023dc4f73c441953ed51f5f05a076f0862f
git apply /root/pre_state.patch
