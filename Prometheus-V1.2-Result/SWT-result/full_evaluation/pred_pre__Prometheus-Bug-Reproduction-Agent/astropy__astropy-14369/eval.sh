#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD fa4e8d1cd279acf9b24560813c8652494ccd5922 >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff fa4e8d1cd279acf9b24560813c8652494ccd5922
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .[test] --verbose
git apply -v - <<'EOF_114329324912'
diff --git a/astropy/io/ascii/tests/test_cds_composite_units_parsing.py b/astropy/io/ascii/tests/test_cds_composite_units_parsing.py
new file mode 100644
index 0000000000..f4327f649e
--- /dev/null
+++ b/astropy/io/ascii/tests/test_cds_composite_units_parsing.py
@@ -0,0 +1,38 @@
+import pytest
+from astropy.io import ascii
+from astropy import units as u
+
+
+def test_cds_composite_units_parsing():
+    """
+    Test for incorrect parsing of composite units from a CDS/MRT file.
+    The issue is that units like '10+3J/m/s/kpc2' are misread,
+    particularly the order of division.
+    """
+    mrt_data = """Title:
+Authors:
+Table:
+================================================================================
+Byte-by-byte Description of file: tab.txt
+--------------------------------------------------------------------------------
+   Bytes Format Units          		Label      Explanations
+--------------------------------------------------------------------------------
+   1- 10 A10    ---            		ID         ID
+  12- 21 F10.5  10+3J/m/s/kpc2    	SBCONT     Cont surface brightness
+  23- 32 F10.5  10-7J/s/kpc2 		SBLINE     Line surface brightness
+--------------------------------------------------------------------------------
+ID0001     70.99200   38.51040
+ID0001     13.05120   28.19240
+ID0001     3.83610    10.98370
+ID0001     1.99101    6.78822
+ID0001     1.31142    5.01932
+"""
+    dat = ascii.read(mrt_data, format="cds")
+
+    # According to the bug report, the unit for SBCONT is incorrectly parsed as
+    # '1e+3 J s / (kpc2 m)'. We assert against the correctly formed unit.
+    # The expected unit is constructed programmatically to be independent of
+    # the potentially buggy string parser.
+    expected_unit = 1e3 * u.J / (u.m * u.s * u.kpc**2)
+
+    assert dat["SBCONT"].unit == expected_unit

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(astropy/units/format/cds_parsetab\.py|astropy/units/format/cds\.py)' -m pytest --no-header -rA  -p no:cacheprovider astropy/io/ascii/tests/test_cds_composite_units_parsing.py
cat coverage.cover
git checkout fa4e8d1cd279acf9b24560813c8652494ccd5922
git apply /root/pre_state.patch
