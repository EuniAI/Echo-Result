#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD aa9780761ad8c3c0f68beeef3a0ce5caac9e100b >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff aa9780761ad8c3c0f68beeef3a0ce5caac9e100b
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/sympy/combinatorics/tests/test_permutation_subclassing.py b/sympy/combinatorics/tests/test_permutation_subclassing.py
new file mode 100644
index 0000000000..d85f79a940
--- /dev/null
+++ b/sympy/combinatorics/tests/test_permutation_subclassing.py
@@ -0,0 +1,14 @@
+from sympy.combinatorics.permutations import Permutation
+
+def test_permutation_subclassing():
+    """
+    Tests that subclassing Permutation works as expected.
+    """
+    class MyPermutation(Permutation):
+        """A simple subclass of Permutation."""
+        pass
+
+    # Instantiating with cycles triggers the bug, as it uses the internal
+    # `_af_new` method which doesn't respect the subclass type.
+    p = MyPermutation(1, 0, 2)
+    assert isinstance(p, MyPermutation)

EOF_114329324912
PYTHONWARNINGS='ignore::UserWarning,ignore::SyntaxWarning' python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(sympy/combinatorics/permutations\.py)' bin/test -C --verbose sympy/combinatorics/tests/test_permutation_subclassing.p
cat coverage.cover
git checkout aa9780761ad8c3c0f68beeef3a0ce5caac9e100b
git apply /root/pre_state.patch
