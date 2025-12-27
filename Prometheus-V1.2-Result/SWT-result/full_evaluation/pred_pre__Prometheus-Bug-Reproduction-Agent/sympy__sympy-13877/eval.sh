#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 1659712001810f5fc563a443949f8e3bb38af4bd >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 1659712001810f5fc563a443949f8e3bb38af4bd
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/sympy/matrices/tests/test_determinant.py b/sympy/matrices/tests/test_determinant.py
new file mode 100644
index 0000000000..94e3f72045
--- /dev/null
+++ b/sympy/matrices/tests/test_determinant.py
@@ -0,0 +1,16 @@
+from sympy import (
+    Matrix,
+    det,
+)
+from sympy.abc import a
+
+
+def test_issue_14721():
+    """
+    Test from issue 14721
+    https://github.com/sympy/sympy/issues/14721
+    """
+    # The test is for n=6, which gives a traceback.
+    # For n > 2 the det is 0.
+    M = Matrix([[i + a*j for i in range(6)] for j in range(6)])
+    assert M.det() == 0

EOF_114329324912
PYTHONWARNINGS='ignore::UserWarning,ignore::SyntaxWarning' python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(sympy/matrices/matrices\.py|sympy/utilities/randtest\.py)' bin/test -C --verbose sympy/matrices/tests/test_determinant.p
cat coverage.cover
git checkout 1659712001810f5fc563a443949f8e3bb38af4bd
git apply /root/pre_state.patch
