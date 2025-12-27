#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD d1320814eda6549996190618a21eaf212cfd4d1e >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff d1320814eda6549996190618a21eaf212cfd4d1e
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/sympy/core/tests/test_rich_comparison.py b/sympy/core/tests/test_rich_comparison.py
new file mode 100644
index 0000000000..9ece0b8512
--- /dev/null
+++ b/sympy/core/tests/test_rich_comparison.py
@@ -0,0 +1,31 @@
+from sympy import S, Symbol
+from sympy.core.basic import Basic
+
+
+def test_rich_comparison_not_implemented():
+    """
+    Test that comparisons with unknown types return NotImplemented, allowing
+    the other type to handle the comparison.
+    """
+    class Foo:
+        def __init__(self, value):
+            self.value = value
+
+        def __eq__(self, other):
+            if isinstance(other, Basic):
+                return self.value == other
+            return NotImplemented
+
+        def __ne__(self, other):
+            eq = self.__eq__(other)
+            if eq is not NotImplemented:
+                return not eq
+            return NotImplemented
+
+    f = Foo(1)
+    s = S(1)
+
+    # s == f calls Basic.__eq__(s, f). The bug is that this returns False
+    # instead of NotImplemented. If it returned NotImplemented, Python would
+    # then try the reflected operation, f.__eq__(s), which would return True.
+    assert s == f

EOF_114329324912
PYTHONWARNINGS='ignore::UserWarning,ignore::SyntaxWarning' python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(sympy/utilities/enumerative\.py|sympy/physics/optics/medium\.py|sympy/geometry/entity\.py|sympy/polys/domains/pythonrational\.py|sympy/polys/agca/modules\.py|sympy/polys/monomials\.py|sympy/tensor/array/ndim_array\.py|sympy/polys/domains/quotientring\.py|sympy/core/numbers\.py|sympy/polys/domains/domain\.py|sympy/polys/domains/expressiondomain\.py|sympy/polys/rings\.py|sympy/core/exprtools\.py|sympy/physics/vector/frame\.py|sympy/polys/rootoftools\.py|sympy/core/basic\.py|sympy/polys/polytools\.py|sympy/physics/vector/vector\.py|sympy/physics/vector/dyadic\.py|sympy/polys/polyclasses\.py|sympy/polys/fields\.py)' bin/test -C --verbose sympy/core/tests/test_rich_comparison.p
cat coverage.cover
git checkout d1320814eda6549996190618a21eaf212cfd4d1e
git apply /root/pre_state.patch
