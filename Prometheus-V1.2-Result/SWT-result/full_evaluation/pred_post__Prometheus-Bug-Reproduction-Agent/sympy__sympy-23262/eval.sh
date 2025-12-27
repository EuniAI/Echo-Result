#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD fdc707f73a65a429935c01532cd3970d3355eab6 >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff fdc707f73a65a429935c01532cd3970d3355eab6
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/sympy/utilities/lambdify.py b/sympy/utilities/lambdify.py
--- a/sympy/utilities/lambdify.py
+++ b/sympy/utilities/lambdify.py
@@ -956,9 +956,9 @@ def _recursive_to_string(doprint, arg):
         return doprint(arg)
     elif iterable(arg):
         if isinstance(arg, list):
-            left, right = "[]"
+            left, right = "[", "]"
         elif isinstance(arg, tuple):
-            left, right = "()"
+            left, right = "(", ",)"
         else:
             raise NotImplementedError("unhandled type: %s, %s" % (type(arg), arg))
         return left +', '.join(_recursive_to_string(doprint, e) for e in arg) + right

EOF_114329324912
git apply -v - <<'EOF_114329324912'
diff --git a/sympy/utilities/tests/test_lambdify_regression.py b/sympy/utilities/tests/test_lambdify_regression.py
new file mode 100644
index 0000000000..ed609a29b0
--- /dev/null
+++ b/sympy/utilities/tests/test_lambdify_regression.py
@@ -0,0 +1,14 @@
+import inspect
+from sympy import lambdify
+
+def test_lambdify_single_element_tuple():
+    """
+    Test for regression where lambdify returns an integer for a single
+    element tuple due to a printing error.
+    """
+    # This is the example from the issue description
+    f = lambdify([], tuple([1]))
+    source = inspect.getsource(f)
+    # The buggy version returns '(1)', which is an integer, not a tuple.
+    # The correct version should return '(1,)'
+    assert "return (1,)" in source

EOF_114329324912
PYTHONWARNINGS='ignore::UserWarning,ignore::SyntaxWarning' python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(sympy/utilities/lambdify\.py)' bin/test -C --verbose sympy/utilities/tests/test_lambdify_regression.p
cat coverage.cover
git checkout fdc707f73a65a429935c01532cd3970d3355eab6
git apply /root/pre_state.patch
