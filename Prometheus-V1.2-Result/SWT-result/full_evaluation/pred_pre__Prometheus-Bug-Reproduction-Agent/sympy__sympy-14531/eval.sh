#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 205da797006360fc629110937e39a19c9561313e >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 205da797006360fc629110937e39a19c9561313e
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/sympy/printing/tests/test_str_issue_10231.py b/sympy/printing/tests/test_str_issue_10231.py
new file mode 100644
index 0000000000..d84ff94e4b
--- /dev/null
+++ b/sympy/printing/tests/test_str_issue_10231.py
@@ -0,0 +1,11 @@
+from sympy import Eq, S, symbols
+from sympy.printing.str import sstr
+
+
+def test_str_sympy_integers_in_subexpressions():
+    """
+    Test for issue where StrPrinter settings are not respected in subexpressions.
+    From https://github.com/sympy/sympy/issues/10231
+    """
+    x = symbols('x')
+    assert sstr(Eq(x, S(1)/2), sympy_integers=True) == 'Eq(x, S(1)/2)'

EOF_114329324912
PYTHONWARNINGS='ignore::UserWarning,ignore::SyntaxWarning' python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(sympy/printing/str\.py)' bin/test -C --verbose sympy/printing/tests/test_str_issue_10231.p
cat coverage.cover
git checkout 205da797006360fc629110937e39a19c9561313e
git apply /root/pre_state.patch
