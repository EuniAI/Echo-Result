#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD bdb49c4abfb35554a3c8ce761696ffff3bb837fe >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff bdb49c4abfb35554a3c8ce761696ffff3bb837fe
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/sympy/utilities/tests/test_partitions_list.py b/sympy/utilities/tests/test_partitions_list.py
new file mode 100644
index 0000000000..9d2a27f1a7
--- /dev/null
+++ b/sympy/utilities/tests/test_partitions_list.py
@@ -0,0 +1,10 @@
+from sympy.utilities.iterables import partitions
+
+
+def test_partitions_list():
+    """
+    Tests that the partitions() iterator does not reuse the output dictionaries.
+    This was a bug that caused list(partitions(n)) to return a list of
+    identical dicts.
+    """
+    assert list(partitions(4)) == [{4: 1}, {1: 1, 3: 1}, {2: 2}, {1: 2, 2: 1}, {1: 4}]

EOF_114329324912
PYTHONWARNINGS='ignore::UserWarning,ignore::SyntaxWarning' python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(sympy/utilities/iterables\.py)' bin/test -C --verbose sympy/utilities/tests/test_partitions_list.p
cat coverage.cover
git checkout bdb49c4abfb35554a3c8ce761696ffff3bb837fe
git apply /root/pre_state.patch
