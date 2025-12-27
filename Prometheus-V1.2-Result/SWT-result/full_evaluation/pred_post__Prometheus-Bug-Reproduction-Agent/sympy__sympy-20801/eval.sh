#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD e11d3fed782146eebbffdc9ced0364b223b84b6c >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff e11d3fed782146eebbffdc9ced0364b223b84b6c
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/sympy/core/numbers.py b/sympy/core/numbers.py
--- a/sympy/core/numbers.py
+++ b/sympy/core/numbers.py
@@ -1386,8 +1386,6 @@ def __eq__(self, other):
             other = _sympify(other)
         except SympifyError:
             return NotImplemented
-        if not self:
-            return not other
         if isinstance(other, Boolean):
             return False
         if other.is_NumberSymbol:
@@ -1408,6 +1406,8 @@ def __eq__(self, other):
             # the mpf tuples
             ompf = other._as_mpf_val(self._prec)
             return bool(mlib.mpf_eq(self._mpf_, ompf))
+        if not self:
+            return not other
         return False    # Float != non-Number
 
     def __ne__(self, other):

EOF_114329324912
git apply -v - <<'EOF_114329324912'
diff --git a/sympy/core/tests/test_float_false_comparison.py b/sympy/core/tests/test_float_false_comparison.py
new file mode 100644
index 0000000000..59333a5db8
--- /dev/null
+++ b/sympy/core/tests/test_float_false_comparison.py
@@ -0,0 +1,14 @@
+from sympy import S, false
+
+def test_float_zero_comparison_with_false():
+    """
+    Tests for bug where S(0.0) == false returns True.
+
+    As reported in issue #20033, the comparison of a floating-point zero
+    with `false` is not symmetric. `S(0.0) == false` incorrectly returns
+    `True`, while the reverse comparison `false == S(0.0)` correctly
+    returns `False`. This test ensures the incorrect case is fixed.
+    """
+    # This assertion demonstrates the bug. It fails because `S(0.0) == false`
+    # currently evaluates to `True`. It should evaluate to `False`.
+    assert (S(0.0) == false) is False

EOF_114329324912
PYTHONWARNINGS='ignore::UserWarning,ignore::SyntaxWarning' python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(sympy/core/numbers\.py)' bin/test -C --verbose sympy/core/tests/test_float_false_comparison.p
cat coverage.cover
git checkout e11d3fed782146eebbffdc9ced0364b223b84b6c
git apply /root/pre_state.patch
