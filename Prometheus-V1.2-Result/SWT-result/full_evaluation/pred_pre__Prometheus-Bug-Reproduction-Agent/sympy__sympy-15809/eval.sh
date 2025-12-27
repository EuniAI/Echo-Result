#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 28d913d3cead6c5646307ffa6540b21d65059dfd >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 28d913d3cead6c5646307ffa6540b21d65059dfd
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/sympy/functions/elementary/tests/test_empty_min_max.py b/sympy/functions/elementary/tests/test_empty_min_max.py
new file mode 100644
index 0000000000..c56b074353
--- /dev/null
+++ b/sympy/functions/elementary/tests/test_empty_min_max.py
@@ -0,0 +1,10 @@
+from sympy.core.numbers import oo
+from sympy.functions.elementary.miscellaneous import Min, Max
+
+
+def test_empty_min_max():
+    """
+    Test that Min() and Max() on an empty set return oo and -oo, respectively.
+    """
+    assert Min() == oo
+    assert Max() == -oo

EOF_114329324912
PYTHONWARNINGS='ignore::UserWarning,ignore::SyntaxWarning' python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(sympy/functions/elementary/miscellaneous\.py)' bin/test -C --verbose sympy/functions/elementary/tests/test_empty_min_max.p
cat coverage.cover
git checkout 28d913d3cead6c5646307ffa6540b21d65059dfd
git apply /root/pre_state.patch
