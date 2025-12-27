#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 5e17a90c19f7eecfa10c1ab872648ae7e2131323 >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 5e17a90c19f7eecfa10c1ab872648ae7e2131323
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/sympy/core/tests/test_mod.py b/sympy/core/tests/test_mod.py
new file mode 100644
index 0000000000..4651b2af66
--- /dev/null
+++ b/sympy/core/tests/test_mod.py
@@ -0,0 +1,9 @@
+from sympy import Mod, Symbol
+
+
+def test_mod_integer_coefficient_simplification():
+    """
+    Test for https://github.com/sympy/sympy/issues/15493
+    """
+    i = Symbol('i', integer=True)
+    assert Mod(3*i, 2) == Mod(i, 2)

EOF_114329324912
PYTHONWARNINGS='ignore::UserWarning,ignore::SyntaxWarning' python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(sympy/core/mod\.py)' bin/test -C --verbose sympy/core/tests/test_mod.p
cat coverage.cover
git checkout 5e17a90c19f7eecfa10c1ab872648ae7e2131323
git apply /root/pre_state.patch
