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
diff --git a/astropy/io/ascii/qdp.py b/astropy/io/ascii/qdp.py
--- a/astropy/io/ascii/qdp.py
+++ b/astropy/io/ascii/qdp.py
@@ -68,7 +68,7 @@ def _line_type(line, delimiter=None):
     _new_re = rf"NO({sep}NO)+"
     _data_re = rf"({_decimal_re}|NO|[-+]?nan)({sep}({_decimal_re}|NO|[-+]?nan))*)"
     _type_re = rf"^\s*((?P<command>{_command_re})|(?P<new>{_new_re})|(?P<data>{_data_re})?\s*(\!(?P<comment>.*))?\s*$"
-    _line_type_re = re.compile(_type_re)
+    _line_type_re = re.compile(_type_re, re.IGNORECASE)
     line = line.strip()
     if not line:
         return "comment"
@@ -306,7 +306,7 @@ def _get_tables_from_qdp_file(qdp_file, input_colnames=None, delimiter=None):
 
             values = []
             for v in line.split(delimiter):
-                if v == "NO":
+                if v.upper() == "NO":
                     values.append(np.ma.masked)
                 else:
                     # Understand if number is int or float

EOF_114329324912
git apply -v - <<'EOF_114329324912'
diff --git a/astropy/io/ascii/tests/test_qdp_lowercase_command_regression.py b/astropy/io/ascii/tests/test_qdp_lowercase_command_regression.py
new file mode 100644
index 0000000000..12198789ba
--- /dev/null
+++ b/astropy/io/ascii/tests/test_qdp_lowercase_command_regression.py
@@ -0,0 +1,27 @@
+import numpy as np
+import pytest
+
+from astropy.io import ascii
+from astropy.table import Table
+from astropy.utils.exceptions import AstropyUserWarning
+
+
+def test_read_qdp_lowercase_command():
+    """
+    Test that QDP files with lowercase commands can be read.
+
+    This is a regression test for the issue where commands were
+    assumed to be uppercase, causing a ValueError. The test handles
+    an expected warning about 'table_id' to ensure the underlying
+    ValueError is reached and reported.
+    """
+    qdp_file_content = """read serr 1 2
+1 0.5 1 0.5
+"""
+    with pytest.warns(AstropyUserWarning, match="table_id not specified"):
+        t = Table.read(qdp_file_content, format="ascii.qdp")
+
+    # These assertions will pass once the lowercase command is recognized
+    # and the table is parsed correctly.
+    assert np.allclose(t["col1"], [1.0])
+    assert np.allclose(t["col1_err"], [0.5])

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(astropy/io/ascii/qdp\.py)' -m pytest --no-header -rA  -p no:cacheprovider astropy/io/ascii/tests/test_qdp_lowercase_command_regression.py
cat coverage.cover
git checkout 7269fa3e33e8d02485a647da91a5a2a60a06af61
git apply /root/pre_state.patch
