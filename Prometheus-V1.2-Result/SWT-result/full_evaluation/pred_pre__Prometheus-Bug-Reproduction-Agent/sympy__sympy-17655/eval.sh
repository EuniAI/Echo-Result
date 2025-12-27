#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD f5e965947af2410ded92cfad987aaf45262ea434 >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff f5e965947af2410ded92cfad987aaf45262ea434
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/sympy/geometry/tests/test_point_arithmetic.py b/sympy/geometry/tests/test_point_arithmetic.py
new file mode 100644
index 0000000000..8a41277a13
--- /dev/null
+++ b/sympy/geometry/tests/test_point_arithmetic.py
@@ -0,0 +1,17 @@
+from sympy import S
+from sympy.geometry import Point
+
+
+def test_point_multiplication_in_sum():
+    """Test for issue where Point + Number * Point fails."""
+    point1 = Point(0, 0)
+    point2 = Point(1, 1)
+    num = S(2.0)
+
+    # This works fine
+    working_expr = point1 + point2 * num
+
+    # This raises an exception but should be equivalent
+    failing_expr = point1 + num * point2
+
+    assert failing_expr == working_expr

EOF_114329324912
PYTHONWARNINGS='ignore::UserWarning,ignore::SyntaxWarning' python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(sympy/geometry/point\.py)' bin/test -C --verbose sympy/geometry/tests/test_point_arithmetic.p
cat coverage.cover
git checkout f5e965947af2410ded92cfad987aaf45262ea434
git apply /root/pre_state.patch
