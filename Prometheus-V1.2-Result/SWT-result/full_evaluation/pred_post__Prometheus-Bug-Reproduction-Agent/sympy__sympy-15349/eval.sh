#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 768da1c6f6ec907524b8ebbf6bf818c92b56101b >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 768da1c6f6ec907524b8ebbf6bf818c92b56101b
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/sympy/algebras/quaternion.py b/sympy/algebras/quaternion.py
--- a/sympy/algebras/quaternion.py
+++ b/sympy/algebras/quaternion.py
@@ -529,7 +529,7 @@ def to_rotation_matrix(self, v=None):
 
         m10 = 2*s*(q.b*q.c + q.d*q.a)
         m11 = 1 - 2*s*(q.b**2 + q.d**2)
-        m12 = 2*s*(q.c*q.d + q.b*q.a)
+        m12 = 2*s*(q.c*q.d - q.b*q.a)
 
         m20 = 2*s*(q.b*q.d - q.c*q.a)
         m21 = 2*s*(q.c*q.d + q.b*q.a)

EOF_114329324912
git apply -v - <<'EOF_114329324912'
diff --git a/sympy/algebras/tests/test_rotation.py b/sympy/algebras/tests/test_rotation.py
new file mode 100644
index 0000000000..df1e0a45f8
--- /dev/null
+++ b/sympy/algebras/tests/test_rotation.py
@@ -0,0 +1,19 @@
+from sympy.algebras.quaternion import Quaternion
+from sympy import symbols, re, im, Add, Mul, I, Abs
+from sympy import cos, sin, sqrt, conjugate, exp, log, acos, E, pi
+from sympy.utilities.pytest import raises
+from sympy import Matrix
+from sympy import diff, integrate, trigsimp
+from sympy import S, Rational
+
+def test_to_rotation_matrix_x_axis():
+    """Test for issue with x-axis rotation in to_rotation_matrix."""
+    x = symbols('x')
+    q = Quaternion(cos(x/2), sin(x/2), 0, 0)
+    # This is the corrected matrix. The original implementation returned a matrix
+    # with sin(x) in position (1, 2) instead of -sin(x).
+    expected_matrix = Matrix([
+        [1,      0,       0],
+        [0, cos(x), -sin(x)],
+        [0, sin(x),  cos(x)]])
+    assert trigsimp(q.to_rotation_matrix()) == expected_matrix

EOF_114329324912
PYTHONWARNINGS='ignore::UserWarning,ignore::SyntaxWarning' python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(sympy/algebras/quaternion\.py)' bin/test -C --verbose sympy/algebras/tests/test_rotation.p
cat coverage.cover
git checkout 768da1c6f6ec907524b8ebbf6bf818c92b56101b
git apply /root/pre_state.patch
