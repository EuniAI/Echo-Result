#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD c6753448b5c34f95e250105d76709fe4d349ca1f >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff c6753448b5c34f95e250105d76709fe4d349ca1f
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/sympy/physics/vector/vector.py b/sympy/physics/vector/vector.py
--- a/sympy/physics/vector/vector.py
+++ b/sympy/physics/vector/vector.py
@@ -57,6 +57,8 @@ def __hash__(self):
 
     def __add__(self, other):
         """The add operator for Vector. """
+        if other == 0:
+            return self
         other = _check_vector(other)
         return Vector(self.args + other.args)
 

EOF_114329324912
git apply -v - <<'EOF_114329324912'
diff --git a/sympy/physics/vector/tests/test_vector_bug.py b/sympy/physics/vector/tests/test_vector_bug.py
new file mode 100644
index 0000000000..93e74cb5be
--- /dev/null
+++ b/sympy/physics/vector/tests/test_vector_bug.py
@@ -0,0 +1,9 @@
+from sympy import symbols
+from sympy.physics.vector import ReferenceFrame, Vector
+
+def test_vector_add_0_error():
+    """Test for issue https://github.com/sympy/sympy/pull/9548"""
+    N = ReferenceFrame('N')
+    # This was raising a TypeError, because `0 * N.x` resulted in `0`
+    # instead of a zero vector.
+    assert sum([N.x, (0 * N.x)]) == N.x

EOF_114329324912
PYTHONWARNINGS='ignore::UserWarning,ignore::SyntaxWarning' python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(sympy/physics/vector/vector\.py)' bin/test -C --verbose sympy/physics/vector/tests/test_vector_bug.p
cat coverage.cover
git checkout c6753448b5c34f95e250105d76709fe4d349ca1f
git apply /root/pre_state.patch
