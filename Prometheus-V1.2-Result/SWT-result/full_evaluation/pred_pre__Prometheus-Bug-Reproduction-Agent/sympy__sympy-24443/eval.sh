#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 809c53c077485ca48a206cee78340389cb83b7f1 >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 809c53c077485ca48a206cee78340389cb83b7f1
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/sympy/combinatorics/tests/test_homomorphisms_2.py b/sympy/combinatorics/tests/test_homomorphisms_2.py
new file mode 100644
index 0000000000..23832986ef
--- /dev/null
+++ b/sympy/combinatorics/tests/test_homomorphisms_2.py
@@ -0,0 +1,16 @@
+from sympy.combinatorics import Permutation
+from sympy.combinatorics.perm_groups import PermutationGroup
+from sympy.combinatorics.homomorphisms import homomorphism, group_isomorphism, is_isomorphic
+from sympy.combinatorics.free_groups import free_group
+from sympy.combinatorics.fp_groups import FpGroup
+from sympy.combinatorics.named_groups import AlternatingGroup, DihedralGroup, CyclicGroup
+from sympy.testing.pytest import raises
+
+def test_homomorphism_identity_on_permutation_group():
+    """
+    Tests that the identity homomorphism on a permutation group
+    is correctly created. This was raising a ValueError.
+    """
+    D3 = DihedralGroup(3)
+    T = homomorphism(D3, D3, D3.generators, D3.generators)
+    assert T.is_isomorphism()

EOF_114329324912
PYTHONWARNINGS='ignore::UserWarning,ignore::SyntaxWarning' python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(sympy/combinatorics/homomorphisms\.py)' bin/test -C --verbose sympy/combinatorics/tests/test_homomorphisms_2.p
cat coverage.cover
git checkout 809c53c077485ca48a206cee78340389cb83b7f1
git apply /root/pre_state.patch
