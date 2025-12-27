#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 09786a173e7a0a488f46dd6000177c23e5d24eed >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 09786a173e7a0a488f46dd6000177c23e5d24eed
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/sympy/utilities/codegen.py b/sympy/utilities/codegen.py
--- a/sympy/utilities/codegen.py
+++ b/sympy/utilities/codegen.py
@@ -695,6 +695,11 @@ def routine(self, name, expr, argument_sequence=None, global_vars=None):
         arg_list = []
 
         # setup input argument list
+
+        # helper to get dimensions for data for array-like args
+        def dimensions(s):
+            return [(S.Zero, dim - 1) for dim in s.shape]
+
         array_symbols = {}
         for array in expressions.atoms(Indexed) | local_expressions.atoms(Indexed):
             array_symbols[array.base.label] = array
@@ -703,11 +708,8 @@ def routine(self, name, expr, argument_sequence=None, global_vars=None):
 
         for symbol in sorted(symbols, key=str):
             if symbol in array_symbols:
-                dims = []
                 array = array_symbols[symbol]
-                for dim in array.shape:
-                    dims.append((S.Zero, dim - 1))
-                metadata = {'dimensions': dims}
+                metadata = {'dimensions': dimensions(array)}
             else:
                 metadata = {}
 
@@ -739,7 +741,11 @@ def routine(self, name, expr, argument_sequence=None, global_vars=None):
                 try:
                     new_args.append(name_arg_dict[symbol])
                 except KeyError:
-                    new_args.append(InputArgument(symbol))
+                    if isinstance(symbol, (IndexedBase, MatrixSymbol)):
+                        metadata = {'dimensions': dimensions(symbol)}
+                    else:
+                        metadata = {}
+                    new_args.append(InputArgument(symbol, **metadata))
             arg_list = new_args
 
         return Routine(name, arg_list, return_val, local_vars, global_vars)

EOF_114329324912
git apply -v - <<'EOF_114329324912'
diff --git a/sympy/utilities/tests/test_autowrap_bug.py b/sympy/utilities/tests/test_autowrap_bug.py
new file mode 100644
index 0000000000..c70f56fc26
--- /dev/null
+++ b/sympy/utilities/tests/test_autowrap_bug.py
@@ -0,0 +1,63 @@
+import sympy
+import tempfile
+import os
+from sympy import symbols, Eq, Mod, MatrixSymbol
+from sympy.external import import_module
+from sympy.tensor import IndexedBase, Idx
+from sympy.utilities.autowrap import autowrap, ufuncify, CodeWrapError
+from sympy.utilities.pytest import skip
+
+numpy = import_module('numpy', min_module_version='1.6.1')
+Cython = import_module('Cython', min_module_version='0.15.1')
+f2py = import_module('numpy.f2py', __import__kwargs={'fromlist': ['f2py']})
+
+f2pyworks = False
+if f2py:
+    try:
+        autowrap(symbols('x'), 'f95', 'f2py')
+    except (CodeWrapError, ImportError, OSError):
+        f2pyworks = False
+    else:
+        f2pyworks = True
+
+a, b, c = symbols('a b c')
+n, m, d = symbols('n m d', integer=True)
+A, B, C = symbols('A B C', cls=IndexedBase)
+i = Idx('i', m)
+j = Idx('j', n)
+k = Idx('k', d)
+
+
+def has_module(module):
+    """
+    Return True if module exists, otherwise run skip().
+
+    module should be a string.
+    """
+    # To give a string of the module name to skip(), this function takes a
+    # string.  So we don't waste time running import_module() more than once,
+    # just map the three modules tested here in this dict.
+    modnames = {'numpy': numpy, 'Cython': Cython, 'f2py': f2py}
+
+    if modnames[module]:
+        if module == 'f2py' and not f2pyworks:
+            skip("Couldn't run f2py.")
+        return True
+    skip("Couldn't import %s." % module)
+
+
+def test_autowrap_unused_array_argument_cython():
+    """
+    Test for bug where array arguments that do not appear in the
+    expression are not handled correctly by the cython backend.
+    """
+    has_module('numpy')
+    has_module('Cython')
+
+    x = MatrixSymbol('x', 2, 1)
+    expr = 1.0
+    f = autowrap(expr, args=(x,), backend='cython')
+
+    # This call fails with a TypeError, but should return 1.0
+    # The array shape must match the MatrixSymbol dimensions.
+    assert f(numpy.array([[1.0], [2.0]])) == 1.0

EOF_114329324912
PYTHONWARNINGS='ignore::UserWarning,ignore::SyntaxWarning' python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(sympy/utilities/codegen\.py)' bin/test -C --verbose sympy/utilities/tests/test_autowrap_bug.p
cat coverage.cover
git checkout 09786a173e7a0a488f46dd6000177c23e5d24eed
git apply /root/pre_state.patch
