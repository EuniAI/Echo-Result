#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD c0a24c1dc957a3b565294213f435fefb2ec99714 >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff c0a24c1dc957a3b565294213f435fefb2ec99714
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .[test] --verbose
git apply -v - <<'EOF_114329324912'
diff --git a/astropy/io/fits/tests/test_vla_diff.py b/astropy/io/fits/tests/test_vla_diff.py
new file mode 100644
index 0000000000..0b6182a4a7
--- /dev/null
+++ b/astropy/io/fits/tests/test_vla_diff.py
@@ -0,0 +1,35 @@
+import numpy as np
+import pytest
+
+from astropy.io import fits
+from astropy.io.fits.column import Column
+from astropy.io.fits.diff import (
+    FITSDiff,
+    HDUDiff,
+    HeaderDiff,
+    ImageDataDiff,
+    TableDataDiff,
+)
+from astropy.io.fits.hdu import HDUList, ImageHDU, PrimaryHDU
+from astropy.io.fits.hdu.base import NonstandardExtHDU
+from astropy.io.fits.hdu.table import BinTableHDU
+from astropy.io.fits.header import Header
+from astropy.utils.misc import _NOT_OVERWRITING_MSG_MATCH
+
+from .conftest import FitsTestCase
+
+
+class TestDiff(FitsTestCase):
+    def test_vla_diff_identical_files(self):
+        """
+        Regression test for a bug where FITSDiff would report differences
+        between identical files containing variable-length array columns with
+        the 'Q' format descriptor.
+        """
+        col = fits.Column('a', format='QD', array=[[0], [0, 0]])
+        hdu = fits.BinTableHDU.from_columns([col])
+        filename = self.temp('diffbug.fits')
+        hdu.writeto(filename, overwrite=True)
+
+        diff = fits.FITSDiff(filename, filename)
+        assert diff.identical

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(astropy/io/fits/diff\.py)' -m pytest --no-header -rA  -p no:cacheprovider astropy/io/fits/tests/test_vla_diff.py
cat coverage.cover
git checkout c0a24c1dc957a3b565294213f435fefb2ec99714
git apply /root/pre_state.patch
