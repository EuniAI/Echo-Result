#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD c935e1d106743efd5bf0705fbeedbd18fadff4dc >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff c935e1d106743efd5bf0705fbeedbd18fadff4dc
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/sympy/functions/special/tests/test_polylog.py b/sympy/functions/special/tests/test_polylog.py
new file mode 100644
index 0000000000..1beba1d556
--- /dev/null
+++ b/sympy/functions/special/tests/test_polylog.py
@@ -0,0 +1,11 @@
+from sympy import expand_func, log, pi, polylog, Rational
+
+
+def test_polylog_evaluation():
+    """
+    Test the symbolic evaluation of polylog at specific points.
+
+    This test case is for issue #7132, which notes that polylog(2, 1/2)
+    does not evaluate to its known symbolic value.
+    """
+    assert expand_func(polylog(2, Rational(1, 2))) == pi**2/12 - log(2)**2/2

EOF_114329324912
PYTHONWARNINGS='ignore::UserWarning,ignore::SyntaxWarning' python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(sympy/functions/special/zeta_functions\.py)' bin/test -C --verbose sympy/functions/special/tests/test_polylog.p
cat coverage.cover
git checkout c935e1d106743efd5bf0705fbeedbd18fadff4dc
git apply /root/pre_state.patch
