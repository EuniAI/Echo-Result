#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD b1cb676cf92dd1a48365b731979833375b188bf2 >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff b1cb676cf92dd1a48365b731979833375b188bf2
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/sympy/core/tests/test_rational_string_args.py b/sympy/core/tests/test_rational_string_args.py
new file mode 100644
index 0000000000..9419492273
--- /dev/null
+++ b/sympy/core/tests/test_rational_string_args.py
@@ -0,0 +1,11 @@
+from sympy.core.numbers import Rational, Integer
+from sympy.core.singleton import S
+from sympy.testing.pytest import raises
+
+
+def test_rational_string_args():
+    """
+    Test for a bug in the Rational constructor where string arguments
+    were not handled correctly, leading to a ValueError.
+    """
+    assert Rational('0.5', '100') == Rational(1, 200)

EOF_114329324912
PYTHONWARNINGS='ignore::UserWarning,ignore::SyntaxWarning' python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(sympy/core/numbers\.py)' bin/test -C --verbose sympy/core/tests/test_rational_string_args.p
cat coverage.cover
git checkout b1cb676cf92dd1a48365b731979833375b188bf2
git apply /root/pre_state.patch
