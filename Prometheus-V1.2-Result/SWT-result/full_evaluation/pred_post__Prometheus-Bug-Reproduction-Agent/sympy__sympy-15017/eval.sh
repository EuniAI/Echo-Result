#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 6810dee426943c1a2fe85b5002dd0d4cf2246a05 >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 6810dee426943c1a2fe85b5002dd0d4cf2246a05
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/sympy/tensor/array/dense_ndim_array.py b/sympy/tensor/array/dense_ndim_array.py
--- a/sympy/tensor/array/dense_ndim_array.py
+++ b/sympy/tensor/array/dense_ndim_array.py
@@ -149,7 +149,7 @@ def _new(cls, iterable, shape, **kwargs):
         self._shape = shape
         self._array = list(flat_list)
         self._rank = len(shape)
-        self._loop_size = functools.reduce(lambda x,y: x*y, shape) if shape else 0
+        self._loop_size = functools.reduce(lambda x,y: x*y, shape, 1)
         return self
 
     def __setitem__(self, index, value):

EOF_114329324912
git apply -v - <<'EOF_114329324912'
diff --git a/sympy/tensor/array/tests/test_ndim_array.py b/sympy/tensor/array/tests/test_ndim_array.py
new file mode 100644
index 0000000000..a46a6cc981
--- /dev/null
+++ b/sympy/tensor/array/tests/test_ndim_array.py
@@ -0,0 +1,11 @@
+from sympy import Array
+
+def test_len_of_rank_zero_array():
+    """
+    Tests that `len` of a rank-0 array is 1.
+    
+    This was returning 0, which is inconsistent with the number of elements
+    and with the behavior of libraries like numpy.
+    """
+    rank_zero_array = Array(3)
+    assert len(rank_zero_array) == 1

EOF_114329324912
PYTHONWARNINGS='ignore::UserWarning,ignore::SyntaxWarning' python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(sympy/tensor/array/dense_ndim_array\.py)' bin/test -C --verbose sympy/tensor/array/tests/test_ndim_array.p
cat coverage.cover
git checkout 6810dee426943c1a2fe85b5002dd0d4cf2246a05
git apply /root/pre_state.patch
