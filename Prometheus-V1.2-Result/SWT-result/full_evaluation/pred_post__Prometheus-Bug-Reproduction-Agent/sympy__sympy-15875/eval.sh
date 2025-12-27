#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD b506169ad727ee39cb3d60c8b3ff5e315d443d8e >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff b506169ad727ee39cb3d60c8b3ff5e315d443d8e
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/sympy/core/add.py b/sympy/core/add.py
--- a/sympy/core/add.py
+++ b/sympy/core/add.py
@@ -554,7 +554,7 @@ def _eval_is_zero(self):
                 return
         if z == len(self.args):
             return True
-        if len(nz) == len(self.args):
+        if len(nz) == 0 or len(nz) == len(self.args):
             return None
         b = self.func(*nz)
         if b.is_zero:

EOF_114329324912
git apply -v - <<'EOF_114329324912'
diff --git a/sympy/sympy/core/tests/test_complex_arithmetic.py b/sympy/sympy/core/tests/test_complex_arithmetic.py
new file mode 100644
index 0000000000..31e89f79b3
--- /dev/null
+++ b/sympy/sympy/core/tests/test_complex_arithmetic.py
@@ -0,0 +1,13 @@
+from sympy import I
+
+def test_issue_15872():
+    """
+    Test for issue #15872.
+
+    is_zero was incorrectly returning False for a complex expression
+    that is equal to zero.
+    """
+    e = -2*I + (1 + I)**2
+    # simplify(e) is 0, so e.is_zero should not be False.
+    # It should be True, or None if it can't be determined.
+    assert e.is_zero is not False

EOF_114329324912
PYTHONWARNINGS='ignore::UserWarning,ignore::SyntaxWarning' python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(sympy/core/add\.py)' bin/test -C --verbose sympy/sympy/core/tests/test_complex_arithmetic.p
cat coverage.cover
git checkout b506169ad727ee39cb3d60c8b3ff5e315d443d8e
git apply /root/pre_state.patch
