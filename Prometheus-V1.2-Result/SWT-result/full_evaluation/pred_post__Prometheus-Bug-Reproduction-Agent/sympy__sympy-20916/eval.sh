#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 82298df6a51491bfaad0c6d1980e7e3ca808ae93 >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 82298df6a51491bfaad0c6d1980e7e3ca808ae93
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/sympy/printing/conventions.py b/sympy/printing/conventions.py
--- a/sympy/printing/conventions.py
+++ b/sympy/printing/conventions.py
@@ -7,7 +7,7 @@
 from collections.abc import Iterable
 from sympy import Derivative
 
-_name_with_digits_p = re.compile(r'^([a-zA-Z]+)([0-9]+)$')
+_name_with_digits_p = re.compile(r'^([^\W\d_]+)(\d+)$', re.U)
 
 
 def split_super_sub(text):
@@ -60,7 +60,7 @@ def split_super_sub(text):
         else:
             raise RuntimeError("This should never happen.")
 
-    # make a little exception when a name ends with digits, i.e. treat them
+    # Make a little exception when a name ends with digits, i.e. treat them
     # as a subscript too.
     m = _name_with_digits_p.match(name)
     if m:

EOF_114329324912
git apply -v - <<'EOF_114329324912'
diff --git a/sympy/printing/pretty/tests/test_pprint_bug.py b/sympy/printing/pretty/tests/test_pprint_bug.py
new file mode 100644
index 0000000000..c6087e6398
--- /dev/null
+++ b/sympy/printing/pretty/tests/test_pprint_bug.py
@@ -0,0 +1,38 @@
+# -*- coding: utf-8 -*-
+from sympy import Symbol, Matrix, symbols
+from sympy.printing.pretty import pprint
+import io
+import sys
+
+def test_pprint_w0_renders_as_w_subscript_0():
+    """
+    Regression test for a bug where 'w0' is incorrectly rendered as 'ω0'.
+
+    This test directly calls `pprint` to capture its output, ensuring that
+    the default settings (like line wrapping) which differ from other tests
+    are used. The bug report indicates that in a matrix context, 'w0' can be
+    incorrectly pretty-printed as the Greek letter omega 'ω' followed by a
+    digit '0', instead of the correct Latin letter 'w' with a subscript '₀'.
+
+    This test will fail if the bug is present and pass once it is fixed.
+    """
+    # Redirect stdout to capture the output of pprint
+    original_stdout = sys.stdout
+    captured_output = io.StringIO()
+    sys.stdout = captured_output
+
+    try:
+        # Construct the expression from the bug report
+        t0, t1, t2, w0 = symbols('t0, t1, t2, w0')
+        expr = Matrix([[-t0*w0, -t1*w0, -t2*w0]])
+
+        # Call pprint directly to ensure its default settings are used
+        pprint(expr)
+        output = captured_output.getvalue()
+    finally:
+        # Restore stdout
+        sys.stdout = original_stdout
+
+    # The bug causes 'w0' to be rendered as 'ω0'. The correct output is 'w₀'.
+    # This assertion checks for the presence of the correct string.
+    assert 'w₀' in output

EOF_114329324912
PYTHONWARNINGS='ignore::UserWarning,ignore::SyntaxWarning' python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(sympy/printing/conventions\.py)' bin/test -C --verbose sympy/printing/pretty/tests/test_pprint_bug.p
cat coverage.cover
git checkout 82298df6a51491bfaad0c6d1980e7e3ca808ae93
git apply /root/pre_state.patch
