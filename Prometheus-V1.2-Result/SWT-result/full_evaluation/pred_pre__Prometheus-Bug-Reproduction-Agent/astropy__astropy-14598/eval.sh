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
diff --git a/astropy/io/fits/tests/test_regression.py b/astropy/io/fits/tests/test_regression.py
new file mode 100644
index 0000000000..575e36d04c
--- /dev/null
+++ b/astropy/io/fits/tests/test_regression.py
@@ -0,0 +1,17 @@
+import pytest
+from astropy.io import fits
+
+
+@pytest.mark.parametrize("n", [65, 67, 68, 69])
+def test_long_string_with_double_single_quote(n):
+    """
+    Regression test for issue where a double single-quote in a long string
+    is not preserved when converting a Card to a string and back.
+
+    This issue occurs at specific string lengths where the double single-quote
+    interacts incorrectly with the long string continuation logic.
+    """
+    value = "x" * n + "''"
+    card1 = fits.Card("CONFIG", value)
+    card2 = fits.Card.fromstring(str(card1))
+    assert card2.value == card1.value

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(astropy/io/fits/card\.py)' -m pytest --no-header -rA  -p no:cacheprovider astropy/io/fits/tests/test_regression.py
cat coverage.cover
git checkout 80c3854a5f4f4a6ab86c03d9db7854767fcd83c1
git apply /root/pre_state.patch
