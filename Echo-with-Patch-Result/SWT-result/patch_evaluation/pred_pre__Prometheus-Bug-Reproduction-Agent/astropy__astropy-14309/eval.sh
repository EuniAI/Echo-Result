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
diff --git a/astropy/io/registry/tests/test_identify_format_regression.py b/astropy/io/registry/tests/test_identify_format_regression.py
new file mode 100644
index 0000000000..6e503529ec
--- /dev/null
+++ b/astropy/io/registry/tests/test_identify_format_regression.py
@@ -0,0 +1,19 @@
+import pytest
+from astropy.io.registry import identify_format
+from astropy.table import Table
+
+
+def test_identify_format_empty_args_regression():
+    """
+    Regression test for IndexError in identify_format when the identifier
+    (e.g., is_fits) is called with empty args.
+
+    When the filepath does not have a FITS extension, the is_fits identifier
+    proceeds to check the args, but did not check if args was empty before
+    accessing the first element.
+
+    See https://github.com/astropy/astropy/issues/14147
+    """
+    # This call should not raise an IndexError. The return value is not
+    # important for this test, only that it does not crash.
+    identify_format("write", Table, "not_a_fits_file.txt", None, [], {})

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(astropy/io/fits/connect\.py)' -m pytest --no-header -rA  -p no:cacheprovider astropy/io/registry/tests/test_identify_format_regression.py
cat coverage.cover
git checkout cdb66059a2feb44ee49021874605ba90801f9986
git apply /root/pre_state.patch
