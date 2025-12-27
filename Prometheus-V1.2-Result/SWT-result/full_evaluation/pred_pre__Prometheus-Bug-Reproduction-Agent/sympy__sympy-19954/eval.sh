#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 6f54459aa0248bf1467ad12ee6333d8bc924a642 >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 6f54459aa0248bf1467ad12ee6333d8bc924a642
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/sympy/combinatorics/tests/test_sylow.py b/sympy/combinatorics/tests/test_sylow.py
new file mode 100644
index 0000000000..e179dacce9
--- /dev/null
+++ b/sympy/combinatorics/tests/test_sylow.py
@@ -0,0 +1,13 @@
+from sympy.combinatorics.named_groups import DihedralGroup
+from sympy.combinatorics.perm_groups import PermutationGroup
+from sympy.combinatorics.permutations import Permutation
+
+
+def test_sylow_subgroup_dihedral_indexerror():
+    """
+    Test reproducing IndexError for sylow_subgroup() with DihedralGroup.
+    https://github.com/sympy/sympy/issues/19882
+    """
+    G = DihedralGroup(18)
+    S2 = G.sylow_subgroup(p=2)
+    assert S2.order() == 4

EOF_114329324912
PYTHONWARNINGS='ignore::UserWarning,ignore::SyntaxWarning' python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(sympy/combinatorics/perm_groups\.py)' bin/test -C --verbose sympy/combinatorics/tests/test_sylow.p
cat coverage.cover
git checkout 6f54459aa0248bf1467ad12ee6333d8bc924a642
git apply /root/pre_state.patch
