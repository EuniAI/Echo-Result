#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 110997fe18b9f7d5ba7d22f624d156a29bf40759 >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 110997fe18b9f7d5ba7d22f624d156a29bf40759
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/sympy/sets/tests/test_issue_19513.py b/sympy/sets/tests/test_issue_19513.py
new file mode 100644
index 0000000000..d5adbd0d62
--- /dev/null
+++ b/sympy/sets/tests/test_issue_19513.py
@@ -0,0 +1,25 @@
+import pytest
+from sympy import (
+    S,
+    Symbol,
+    imageset,
+    Lambda,
+    I,
+    Reals,
+    Integers,
+    FiniteSet,
+    Intersection
+)
+
+def test_issue_19513_regression():
+    """
+    Regression test for a bug in is_subset(Reals) introduced
+    while fixing issue #19513, where an incorrect membership
+    test result was given for an intersection with Reals.
+    """
+    n = Symbol('n')
+    S1 = imageset(Lambda(n, n + (n - 1)*(n + 1)*I), S.Integers)
+
+    # This was incorrectly evaluating to True.
+    # The intersection with Reals should be {-1, 1}, so 2 is not an element.
+    assert (2 in S1.intersect(S.Reals)) is False

EOF_114329324912
PYTHONWARNINGS='ignore::UserWarning,ignore::SyntaxWarning' python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(sympy/sets/handlers/intersection\.py)' bin/test -C --verbose sympy/sets/tests/test_issue_19513.p
cat coverage.cover
git checkout 110997fe18b9f7d5ba7d22f624d156a29bf40759
git apply /root/pre_state.patch
