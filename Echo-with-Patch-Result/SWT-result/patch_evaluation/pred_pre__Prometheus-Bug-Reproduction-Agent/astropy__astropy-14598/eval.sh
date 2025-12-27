#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 80c3854a5f4f4a6ab86c03d9db7854767fcd83c1 >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 80c3854a5f4f4a6ab86c03d9db7854767fcd83c1
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .[test] --verbose
git apply -v - <<'EOF_114329324912'
diff --git a/astropy/io/fits/tests/test_long_string_card.py b/astropy/io/fits/tests/test_long_string_card.py
new file mode 100644
index 0000000000..9b2fc1e9dc
--- /dev/null
+++ b/astropy/io/fits/tests/test_long_string_card.py
@@ -0,0 +1,23 @@
+import pytest
+from astropy.io import fits
+
+
+def test_double_single_quote_in_long_string_card():
+    """
+    Regression test for a bug in parsing long string values containing a
+    double single-quote (empty string).
+
+    When a Card with a long string value ending in '' is converted to its
+    string representation (using CONTINUE cards) and then parsed back, the
+    '' was incorrectly converted to a single '.
+
+    Regression test for https://github.com/astropy/astropy/issues/13242
+    """
+    # The length of the string is chosen to be one of the minimal cases
+    # that failed in the bug report, which forces the use of CONTINUE cards.
+    n = 65
+    original_value = "x" * n + "''"
+    card = fits.Card("CONFIG", original_value)
+    card_from_string = fits.Card.fromstring(str(card))
+
+    assert card_from_string.value == original_value

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(astropy/io/fits/card\.py)' -m pytest --no-header -rA  -p no:cacheprovider astropy/io/fits/tests/test_long_string_card.py
cat coverage.cover
git checkout 80c3854a5f4f4a6ab86c03d9db7854767fcd83c1
git apply /root/pre_state.patch
