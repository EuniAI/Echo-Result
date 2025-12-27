#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 19cc80471739bcb67b7e8099246b391c355023ee >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 19cc80471739bcb67b7e8099246b391c355023ee
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .[test] --verbose
git apply -v - <<'EOF_114329324912'
diff --git a/astropy/io/ascii/tests/test_html_writer_formats.py b/astropy/io/ascii/tests/test_html_writer_formats.py
new file mode 100644
index 0000000000..9ae3ea6141
--- /dev/null
+++ b/astropy/io/ascii/tests/test_html_writer_formats.py
@@ -0,0 +1,21 @@
+from io import StringIO
+
+from astropy.table import Table
+
+
+def test_html_write_formats():
+    """
+    Test that the formats option is not ignored when writing to HTML.
+    Regression test for https://github.com/astropy/astropy/issues/13530.
+    """
+    # generate table from issue
+    t = Table([(1.23875234858e-24, 3.2348748432e-15), (2, 4)], names=("a", "b"))
+
+    with StringIO() as s:
+        # write HTML table with "a" column formatted to show 2 decimal places
+        t.write(s, format="html", formats={"a": lambda x: f"{x:.2e}"})
+        output = s.getvalue()
+
+    # The bug is that the format is ignored, so this fails.
+    # The output contains '<td>1.23875234858e-24</td>' instead.
+    assert "<td>1.24e-24</td>" in output

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(astropy/io/ascii/html\.py)' -m pytest --no-header -rA  -p no:cacheprovider astropy/io/ascii/tests/test_html_writer_formats.py
cat coverage.cover
git checkout 19cc80471739bcb67b7e8099246b391c355023ee
git apply /root/pre_state.patch
