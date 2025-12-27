#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD cdb66059a2feb44ee49021874605ba90801f9986 >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff cdb66059a2feb44ee49021874605ba90801f9986
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .[test] --verbose
git apply -v - <<'EOF_114329324912'
diff --git a/astropy/io/fits/connect.py b/astropy/io/fits/connect.py
--- a/astropy/io/fits/connect.py
+++ b/astropy/io/fits/connect.py
@@ -65,10 +65,9 @@ def is_fits(origin, filepath, fileobj, *args, **kwargs):
         fileobj.seek(pos)
         return sig == FITS_SIGNATURE
     elif filepath is not None:
-        if filepath.lower().endswith(
+        return filepath.lower().endswith(
             (".fits", ".fits.gz", ".fit", ".fit.gz", ".fts", ".fts.gz")
-        ):
-            return True
+        )
     return isinstance(args[0], (HDUList, TableHDU, BinTableHDU, GroupsHDU))
 
 

EOF_114329324912
git apply -v - <<'EOF_114329324912'
diff --git a/astropy/io/registry/tests/test_regression.py b/astropy/io/registry/tests/test_regression.py
new file mode 100644
index 0000000000..2df366e336
--- /dev/null
+++ b/astropy/io/registry/tests/test_regression.py
@@ -0,0 +1,19 @@
+# Licensed under a 3-clause BSD style license - see LICENSE.rst
+"""
+Regression test for https://github.com/astropy/astropy/issues/14319
+"""
+
+import pytest
+from astropy.io.registry import identify_format
+from astropy.table import Table
+
+
+def test_identify_format_index_error_on_write():
+    """
+    Test that identify_format does not raise an IndexError on write.
+
+    The FITS identifier was incorrectly trying to access args[0]
+    when no args were passed.
+    """
+    formats = identify_format("write", Table, "bububu.ecsv", None, [], {})
+    assert "ascii.ecsv" in formats

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(astropy/io/fits/connect\.py)' -m pytest --no-header -rA  -p no:cacheprovider astropy/io/registry/tests/test_regression.py
cat coverage.cover
git checkout cdb66059a2feb44ee49021874605ba90801f9986
git apply /root/pre_state.patch
