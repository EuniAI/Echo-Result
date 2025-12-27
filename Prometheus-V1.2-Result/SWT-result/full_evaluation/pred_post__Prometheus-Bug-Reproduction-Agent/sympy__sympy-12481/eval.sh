#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD c807dfe7569692cad24f02a08477b70c1679a4dd >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff c807dfe7569692cad24f02a08477b70c1679a4dd
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/sympy/combinatorics/permutations.py b/sympy/combinatorics/permutations.py
--- a/sympy/combinatorics/permutations.py
+++ b/sympy/combinatorics/permutations.py
@@ -895,12 +895,8 @@ def __new__(cls, *args, **kwargs):
         # counting starts from 1.
 
         temp = flatten(args)
-        if has_dups(temp):
-            if is_cycle:
-                raise ValueError('there were repeated elements; to resolve '
-                'cycles use Cycle%s.' % ''.join([str(tuple(c)) for c in args]))
-            else:
-                raise ValueError('there were repeated elements.')
+        if has_dups(temp) and not is_cycle:
+            raise ValueError('there were repeated elements.')
         temp = set(temp)
 
         if not is_cycle and \

EOF_114329324912
git apply -v - <<'EOF_114329324912'
diff --git a/sympy/combinatorics/tests/test_permutations_constructor.py b/sympy/combinatorics/tests/test_permutations_constructor.py
new file mode 100644
index 0000000000..958630badf
--- /dev/null
+++ b/sympy/combinatorics/tests/test_permutations_constructor.py
@@ -0,0 +1,19 @@
+from itertools import permutations
+
+from sympy.core.compatibility import range
+from sympy.core.symbol import Symbol
+from sympy.combinatorics.permutations import (Permutation, _af_parity,
+    _af_rmul, _af_rmuln, Cycle)
+from sympy.utilities.pytest import raises
+
+rmul = Permutation.rmul
+a = Symbol('a', integer=True)
+
+
+def test_constructor_non_disjoint_cycles():
+    """
+    Tests that non-disjoint cycles are applied in order
+    from left to right as per the issue description.
+    """
+    p = Permutation([[0, 1], [0, 1]])
+    assert p.is_Identity

EOF_114329324912
PYTHONWARNINGS='ignore::UserWarning,ignore::SyntaxWarning' python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(sympy/combinatorics/permutations\.py)' bin/test -C --verbose sympy/combinatorics/tests/test_permutations_constructor.p
cat coverage.cover
git checkout c807dfe7569692cad24f02a08477b70c1679a4dd
git apply /root/pre_state.patch
