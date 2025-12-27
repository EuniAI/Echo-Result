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
diff --git a/astropy/io/fits/tests/test_card.py b/astropy/io/fits/tests/test_card.py
new file mode 100644
index 0000000000..c6f7e2e538
--- /dev/null
+++ b/astropy/io/fits/tests/test_card.py
@@ -0,0 +1,21 @@
+import pytest
+from astropy.io import fits
+
+
+def test_float_card_correctly_formatted_to_avoid_truncation():
+    """
+    Regression test for a bug where an unnecessarily long string
+    representation of a float value would cause the card's comment
+    to be truncated.
+    """
+    keyword = "HIERARCH ESO IFM CL RADIUS"
+    value = 0.009125
+    comment = "[m] radius arround actuator to avoid"
+
+    card = fits.Card(keyword, value, comment)
+
+    expected_image = (
+        "HIERARCH ESO IFM CL RADIUS = 0.009125 / [m] radius arround actuator to avoid  "
+    )
+
+    assert str(card) == expected_image

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(astropy/io/fits/card\.py)' -m pytest --no-header -rA  -p no:cacheprovider astropy/io/fits/tests/test_card.py
cat coverage.cover
git checkout a3f4ae6cd24d5ecdf49f213d77b3513dd509a06c
git apply /root/pre_state.patch
