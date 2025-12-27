#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD a85a0747c54bac75e9c3b2fe436b105ea029d6cf >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff a85a0747c54bac75e9c3b2fe436b105ea029d6cf
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .[test] --verbose
git apply -v - <<'EOF_114329324912'
diff --git a/astropy/io/fits/tests/test_fromstring_bytes.py b/astropy/io/fits/tests/test_fromstring_bytes.py
new file mode 100644
index 0000000000..d617f27d90
--- /dev/null
+++ b/astropy/io/fits/tests/test_fromstring_bytes.py
@@ -0,0 +1,35 @@
+# -*- coding: utf-8 -*-
+# Licensed under a 3-clause BSD style license - see PYFITS.rst
+
+import unittest
+
+import pytest
+from astropy.io import fits
+
+
+# This is a mock of the test case class used in astropy
+class FitsTestCase(unittest.TestCase):
+    pass
+
+
+class TestHeaderFunctions(FitsTestCase):
+    def test_fromstring_with_bytes(self):
+        """
+        Tests that Header.fromstring and Card.fromstring accept bytes as input
+        as was the case in Python 2.
+        """
+        # Test Card.fromstring
+        card_string = "TEST    = 'VALUE' / A test card"
+        card_bytes = card_string.encode('ascii')
+        card = fits.Card.fromstring(card_bytes)
+        assert card.value == 'VALUE'
+
+        # Test Header.fromstring
+        header_string = """SIMPLE  =                    T
+BITPIX  =                    8
+NAXIS   =                    0
+END
+"""
+        header_bytes = header_string.encode('ascii')
+        header = fits.Header.fromstring(header_bytes, sep='\n')
+        assert header['SIMPLE'] is True

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(astropy/io/fits/card\.py|astropy/io/fits/header\.py)' -m pytest --no-header -rA  -p no:cacheprovider astropy/io/fits/tests/test_fromstring_bytes.py
cat coverage.cover
git checkout a85a0747c54bac75e9c3b2fe436b105ea029d6cf
git apply /root/pre_state.patch
