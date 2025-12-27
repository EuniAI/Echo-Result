#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 7269fa3e33e8d02485a647da91a5a2a60a06af61 >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 7269fa3e33e8d02485a647da91a5a2a60a06af61
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .[test] --verbose
git apply -v - <<'EOF_114329324912'
diff --git a/astropy/io/ascii/tests/test_qdp_lowercase.py b/astropy/io/ascii/tests/test_qdp_lowercase.py
new file mode 100644
index 0000000000..26fb11ceaf
--- /dev/null
+++ b/astropy/io/ascii/tests/test_qdp_lowercase.py
@@ -0,0 +1,23 @@
+import numpy as np
+import pytest
+
+from astropy.table import Table
+from astropy.utils.exceptions import AstropyUserWarning
+
+
+def test_qdp_lowercase_command():
+    """
+    Test that QDP files with lowercase commands can be read.
+
+    Regression test for https://github.com/astropy/astropy/issues/14413.
+    """
+    qdp_data = "read serr 1 2\n1 0.5 1 0.5"
+
+    with pytest.warns(AstropyUserWarning, match="table_id not specified"):
+        t = Table.read(qdp_data, format="ascii.qdp")
+
+    # The command "read serr 1 2" indicates symmetric errors for columns 1 and 2.
+    # This should result in columns 'col1', 'col1_err', 'col2', 'col2_err'.
+    # The data '1 0.5 1 0.5' should be parsed into these columns.
+    # A minimal assertion is to check one of the parsed error values.
+    assert np.allclose(t["col2_err"], [0.5])

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(astropy/io/ascii/qdp\.py)' -m pytest --no-header -rA  -p no:cacheprovider astropy/io/ascii/tests/test_qdp_lowercase.py
cat coverage.cover
git checkout 7269fa3e33e8d02485a647da91a5a2a60a06af61
git apply /root/pre_state.patch
