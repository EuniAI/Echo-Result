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
diff --git a/astropy/table/tests/test_regression.py b/astropy/table/tests/test_regression.py
new file mode 100644
index 0000000000..0c4315775c
--- /dev/null
+++ b/astropy/table/tests/test_regression.py
@@ -0,0 +1,29 @@
+import pytest
+from io import StringIO
+from astropy.table import Table
+from astropy.utils.compat.optional_deps import HAS_BS4
+
+if HAS_BS4:
+    from bs4 import BeautifulSoup
+
+
+@pytest.mark.skipif('not HAS_BS4')
+def test_html_write_formats():
+    """
+    Test that the formats option is not ignored when writing to HTML.
+    This is a regression test for https://github.com/astropy/astropy/issues/13532
+    """
+    # generate table from issue description
+    t = Table([[1.23875234858e-24, 3.2348748432e-15], [2, 4]], names=('a', 'b'))
+
+    # print HTML table with "a" column formatted to show 2 decimal places
+    with StringIO() as sp:
+        t.write(sp, format="html", formats={"a": lambda x: f"{x:.2e}"})
+        html_output = sp.getvalue()
+
+    soup = BeautifulSoup(html_output, 'html.parser')
+    # The first `td` element corresponds to the first value of column 'a'
+    first_td = soup.find('td')
+
+    # Check that the format was applied
+    assert first_td.text == '1.24e-24'

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(astropy/io/ascii/html\.py)' -m pytest --no-header -rA  -p no:cacheprovider astropy/table/tests/test_regression.py
cat coverage.cover
git checkout 19cc80471739bcb67b7e8099246b391c355023ee
git apply /root/pre_state.patch
