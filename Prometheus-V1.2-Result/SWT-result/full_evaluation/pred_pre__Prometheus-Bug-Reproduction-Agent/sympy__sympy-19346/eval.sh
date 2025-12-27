#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 94fb720696f5f5d12bad8bc813699fd696afd2fb >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 94fb720696f5f5d12bad8bc813699fd696afd2fb
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/sympy/printing/tests/test_srepr_containers.py b/sympy/printing/tests/test_srepr_containers.py
new file mode 100644
index 0000000000..b28a0c6036
--- /dev/null
+++ b/sympy/printing/tests/test_srepr_containers.py
@@ -0,0 +1,36 @@
+from sympy import symbols, Symbol
+from sympy.core.compatibility import exec_
+from sympy.printing import srepr
+from typing import Any, Dict
+
+# Setup based on the context from sympy/printing/tests/test_repr.py
+x, y = symbols('x,y')
+
+ENV: Dict[str, Any] = {}
+exec_("from sympy import *", ENV)
+
+
+def sT(expr, string, import_stmt=None):
+    """
+    sT := sreprTest
+
+    Tests that srepr delivers the expected string and that
+    the condition eval(srepr(expr))==expr holds.
+    """
+    if import_stmt is None:
+        ENV2 = ENV
+    else:
+        ENV2 = ENV.copy()
+        exec_(import_stmt, ENV2)
+
+    assert srepr(expr) == string
+    assert eval(string, ENV2) == expr
+
+
+def test_srepr_set_dict():
+    """
+    Tests that srepr prints set and dict containers correctly.
+    """
+    # srepr for sets should be canonical, we assume elements are sorted.
+    sT({x, y}, "{Symbol('x'), Symbol('y')}")
+    sT({x: y}, "{Symbol('x'): Symbol('y')}")

EOF_114329324912
PYTHONWARNINGS='ignore::UserWarning,ignore::SyntaxWarning' python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(sympy/printing/repr\.py)' bin/test -C --verbose sympy/printing/tests/test_srepr_containers.p
cat coverage.cover
git checkout 94fb720696f5f5d12bad8bc813699fd696afd2fb
git apply /root/pre_state.patch
