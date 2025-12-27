#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 25fbcce5b1a4c7e3956e6062930f4a44ce95a632 >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 25fbcce5b1a4c7e3956e6062930f4a44ce95a632
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/sympy/sets/tests/test_conditionset_subs.py b/sympy/sets/tests/test_conditionset_subs.py
new file mode 100644
index 0000000000..f8e3a67afe
--- /dev/null
+++ b/sympy/sets/tests/test_conditionset_subs.py
@@ -0,0 +1,29 @@
+import pytest
+from sympy.core.numbers import Rational
+from sympy.core.symbol import Symbol
+from sympy.functions.elementary.trigonometric import asin
+from sympy.sets.conditionset import ConditionSet
+from sympy.sets.fancysets import imageset
+from sympy.sets.sets import Interval
+from sympy import S, Lambda, pi, Contains
+from sympy.abc import x, y
+
+
+def test_subs_on_conditionset_with_imageset_base():
+    """
+    Test for issue where subs on a ConditionSet with an ImageSet base
+    incorrectly substitutes the bound variable.
+    """
+    n = Symbol('n')
+    base_set = imageset(Lambda(n, 2*n*pi + asin(y)), S.Integers)
+    c_set = ConditionSet(x, Contains(y, Interval(-1, 1)), base_set)
+
+    # This substitution is buggy. It seems to confuse the bound variable `x`
+    # with the variable `y` being substituted.
+    substituted = c_set.subs(y, Rational(1, 3))
+
+    # The condition Contains(1/3, Interval(-1, 1)) becomes True,
+    # so the ConditionSet should simplify to its base_set with `y` substituted.
+    expected = imageset(Lambda(n, 2*n*pi + asin(Rational(1, 3))), S.Integers)
+
+    assert substituted == expected

EOF_114329324912
PYTHONWARNINGS='ignore::UserWarning,ignore::SyntaxWarning' python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(sympy/sets/conditionset\.py)' bin/test -C --verbose sympy/sets/tests/test_conditionset_subs.p
cat coverage.cover
git checkout 25fbcce5b1a4c7e3956e6062930f4a44ce95a632
git apply /root/pre_state.patch
