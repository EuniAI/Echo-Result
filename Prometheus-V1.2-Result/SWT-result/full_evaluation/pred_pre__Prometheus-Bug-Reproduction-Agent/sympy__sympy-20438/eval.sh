#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 33b47e4bd60e2302e42616141e76285038b724d6 >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 33b47e4bd60e2302e42616141e76285038b724d6
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/sympy/simplify/tests/test_simplify_sets.py b/sympy/simplify/tests/test_simplify_sets.py
new file mode 100644
index 0000000000..220f807255
--- /dev/null
+++ b/sympy/simplify/tests/test_simplify_sets.py
@@ -0,0 +1,16 @@
+from sympy.sets import FiniteSet, ProductSet
+from sympy.core.relational import Eq
+from sympy.simplify.simplify import simplify
+
+
+def test_simplify_productset_finiteset_equality():
+    """
+    Test that simplifying an equality between a ProductSet and a
+    logically equivalent FiniteSet works, and does not raise an exception.
+    """
+    a = FiniteSet(1, 2)
+    b = ProductSet(a, a)
+    c = FiniteSet((1, 1), (1, 2), (2, 1), (2, 2))
+    # This should simplify to True, but it raises an AttributeError
+    # because Complement has no `equals` method.
+    assert simplify(Eq(b, c)) is True

EOF_114329324912
PYTHONWARNINGS='ignore::UserWarning,ignore::SyntaxWarning' python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(sympy/sets/handlers/issubset\.py|sympy/sets/handlers/comparison\.py|sympy/core/relational\.py)' bin/test -C --verbose sympy/simplify/tests/test_simplify_sets.p
cat coverage.cover
git checkout 33b47e4bd60e2302e42616141e76285038b724d6
git apply /root/pre_state.patch
