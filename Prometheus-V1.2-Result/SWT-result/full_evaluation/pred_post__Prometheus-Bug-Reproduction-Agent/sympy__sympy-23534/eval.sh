#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 832c24fec1046eaa544a4cab4c69e3af3e651759 >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 832c24fec1046eaa544a4cab4c69e3af3e651759
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/sympy/core/symbol.py b/sympy/core/symbol.py
--- a/sympy/core/symbol.py
+++ b/sympy/core/symbol.py
@@ -791,7 +791,7 @@ def literal(s):
         return tuple(result)
     else:
         for name in names:
-            result.append(symbols(name, **args))
+            result.append(symbols(name, cls=cls, **args))
 
         return type(names)(result)
 

EOF_114329324912
git apply -v - <<'EOF_114329324912'
diff --git a/sympy/core/tests/test_symbol_cls.py b/sympy/core/tests/test_symbol_cls.py
new file mode 100644
index 0000000000..be5ed95ae2
--- /dev/null
+++ b/sympy/core/tests/test_symbol_cls.py
@@ -0,0 +1,11 @@
+from sympy.core.symbol import symbols
+from sympy.core.function import Function, UndefinedFunction
+
+
+def test_symbols_cls_function_with_tuple():
+    """
+    Test for bug where symbols with cls=Function and tuple input creates
+    Symbols instead of Functions.
+    """
+    q, u = symbols(('q:2', 'u:2'), cls=Function)
+    assert isinstance(q[0], UndefinedFunction)

EOF_114329324912
PYTHONWARNINGS='ignore::UserWarning,ignore::SyntaxWarning' python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(sympy/core/symbol\.py)' bin/test -C --verbose sympy/core/tests/test_symbol_cls.p
cat coverage.cover
git checkout 832c24fec1046eaa544a4cab4c69e3af3e651759
git apply /root/pre_state.patch
