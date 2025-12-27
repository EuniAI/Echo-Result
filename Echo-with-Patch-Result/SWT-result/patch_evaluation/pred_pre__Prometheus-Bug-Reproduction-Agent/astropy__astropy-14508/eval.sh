#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD a3f4ae6cd24d5ecdf49f213d77b3513dd509a06c >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff a3f4ae6cd24d5ecdf49f213d77b3513dd509a06c
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .[test] --verbose
git apply -v - <<'EOF_114329324912'
diff --git a/astropy/io/fits/tests/test_card_float_representation.py b/astropy/io/fits/tests/test_card_float_representation.py
new file mode 100644
index 0000000000..cf74d9581b
--- /dev/null
+++ b/astropy/io/fits/tests/test_card_float_representation.py
@@ -0,0 +1,37 @@
+import pytest
+from astropy.io import fits
+from astropy.io.fits.card import Card
+from astropy.utils.exceptions import AstropyUserWarning
+
+
+class TestCard:
+    def test_float_representation_not_unnecessarily_long(self):
+        """
+        Regression test for a bug that caused floating point values to be
+        represented with unnecessarily long strings, causing comment truncation.
+
+        Specifically, creating a HIERARCH card with a float value that has a
+        short string representation should use that short representation and not
+        an unnecessarily long one that forces comment truncation.
+
+        See https://github.com/astropy/astropy/issues/14473
+        """
+        keyword = "HIERARCH ESO IFM CL RADIUS"
+        value = 0.009125
+        comment = "[m] radius arround actuator to avoid"
+
+        # The bug causes a VerifyWarning because the card becomes too long,
+        # but the core issue is the string representation, which is what is
+        # asserted here.
+        card = Card(keyword, value, comment)
+
+        # The incorrect representation of the float as 0.009124999999999999
+        # makes the card string too long, truncating the comment.
+        # The correct behavior is to use the shorter float representation '0.009125'
+        # and not truncate the comment. This expected string is what astropy
+        # generates when reading a valid FITS file with this card.
+        expected_card_str = (
+            "HIERARCH ESO IFM CL RADIUS = 0.009125 / [m] radius arround actuator to avoid    "
+        )
+
+        assert str(card) == expected_card_str

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(astropy/io/fits/card\.py)' -m pytest --no-header -rA  -p no:cacheprovider astropy/io/fits/tests/test_card_float_representation.py
cat coverage.cover
git checkout a3f4ae6cd24d5ecdf49f213d77b3513dd509a06c
git apply /root/pre_state.patch
