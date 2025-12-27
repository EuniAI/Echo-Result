#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 88664e6e0b781d0a8b5347896af74b555e92891e >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 88664e6e0b781d0a8b5347896af74b555e92891e
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/sympy/sets/contains.py b/sympy/sets/contains.py
--- a/sympy/sets/contains.py
+++ b/sympy/sets/contains.py
@@ -45,4 +45,4 @@ def binary_symbols(self):
             isinstance(i, (Eq, Ne))])
 
     def as_set(self):
-        raise NotImplementedError()
+        return self.args[1]

EOF_114329324912
git apply -v - <<'EOF_114329324912'
diff --git a/sympy/functions/elementary/tests/test_issue_14965.py b/sympy/functions/elementary/tests/test_issue_14965.py
new file mode 100644
index 0000000000..84fca4de92
--- /dev/null
+++ b/sympy/functions/elementary/tests/test_issue_14965.py
@@ -0,0 +1,20 @@
+from sympy import Piecewise, Contains, Symbol, Reals
+
+def test_issue_14965():
+    """
+    Test based on issue #14965, where Contains in a Piecewise condition
+    causes a failure because Contains.as_set() returns a Contains object.
+
+    The instantiation of Piecewise may pass due to lazy evaluation, but
+    any operation that requires converting the condition to a set will fail.
+    The as_expr_set_pairs() method is such an operation and is used here
+    to trigger the bug.
+    """
+    x = Symbol('x')
+    p = Piecewise((6, Contains(x, Reals)), (7, True))
+
+    # This call fails because it requires converting the `Contains` condition
+    # to a set. It calls `as_set()` on the `Contains` object, which
+    # incorrectly returns another `Contains` object instead of a `Set`.
+    # The method then fails when trying to perform set operations.
+    p.as_expr_set_pairs()

EOF_114329324912
PYTHONWARNINGS='ignore::UserWarning,ignore::SyntaxWarning' python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(sympy/sets/contains\.py)' bin/test -C --verbose sympy/functions/elementary/tests/test_issue_14965.p
cat coverage.cover
git checkout 88664e6e0b781d0a8b5347896af74b555e92891e
git apply /root/pre_state.patch
