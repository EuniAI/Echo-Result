#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD b4f1aa3540fe68d078d76e78ba59d022dd6df39f >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff b4f1aa3540fe68d078d76e78ba59d022dd6df39f
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/sympy/solvers/tests/test_solveset_transcendental.py b/sympy/solvers/tests/test_solveset_transcendental.py
new file mode 100644
index 0000000000..4ee63d57d7
--- /dev/null
+++ b/sympy/solvers/tests/test_solveset_transcendental.py
@@ -0,0 +1,25 @@
+from sympy.core.relational import Eq
+from sympy.core.singleton import S
+from sympy.core.symbol import Symbol
+from sympy.functions.elementary.trigonometric import cos, sin
+from sympy.sets.conditionset import ConditionSet
+
+
+def test_as_set_on_transcendental_eq_raises_notimplementederror():
+    """
+    This test reproduces a bug where as_set() on a transcendental equation
+    raises NotImplementedError instead of returning a ConditionSet.
+
+    The test asserts the fixed behavior. On a version with the bug, the
+    test will fail with an unhandled NotImplementedError before the
+    assertion is reached.
+    """
+    # From the provided context file, `n` is defined as a real symbol.
+    n = Symbol('n', real=True)
+    eq = Eq(n*cos(n) - 3*sin(n), 0)
+
+    # The original bug report states that eq.as_set() raises NotImplementedError.
+    # eq.as_set() on a single-variable equation calls solveset.
+    # Since n is a real symbol, the domain for solveset should be S.Reals.
+    # The desired behavior is for this call to return a ConditionSet.
+    assert eq.as_set() == ConditionSet(n, eq, S.Reals)

EOF_114329324912
PYTHONWARNINGS='ignore::UserWarning,ignore::SyntaxWarning' python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(sympy/core/relational\.py)' bin/test -C --verbose sympy/solvers/tests/test_solveset_transcendental.p
cat coverage.cover
git checkout b4f1aa3540fe68d078d76e78ba59d022dd6df39f
git apply /root/pre_state.patch
