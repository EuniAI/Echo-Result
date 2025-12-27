#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD af8a6e592a1a15d92d77011856d5aa0ec4db4c6c >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff af8a6e592a1a15d92d77011856d5aa0ec4db4c6c
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -v --no-use-pep517 --no-build-isolation -e .
git apply -v - <<'EOF_114329324912'
diff --git a/sklearn/feature_extraction/tests/test_text_nfkd.py b/sklearn/feature_extraction/tests/test_text_nfkd.py
new file mode 100644
index 0000000000..d1266cb32f
--- /dev/null
+++ b/sklearn/feature_extraction/tests/test_text_nfkd.py
@@ -0,0 +1,21 @@
+# -*- coding: utf-8 -*-
+import pytest
+from sklearn.feature_extraction.text import strip_accents_unicode
+
+
+def test_strip_accents_unicode_nfkd():
+    """Check that strip_accents_unicode works on NFKD-normalized strings.
+
+    Non-regression test for:
+    https://github.com/scikit-learn/scikit-learn/issues/15089
+    """
+    # The following two strings are visually identical and should be stripped to
+    # the same character.
+    # s1 contains a single character, "LATIN SMALL LETTER N WITH TILDE"
+    s1 = chr(241)
+    # s2 contains two characters, "LATIN SMALL LETTER N" and "COMBINING TILDE"
+    s2 = chr(110) + chr(771)
+
+    # Both should be stripped to "n"
+    assert strip_accents_unicode(s1) == "n"
+    assert strip_accents_unicode(s2) == "n"

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(sklearn/feature_extraction/text\.py)' -m pytest --no-header -rA  -p no:cacheprovider sklearn/feature_extraction/tests/test_text_nfkd.py
cat coverage.cover
git checkout af8a6e592a1a15d92d77011856d5aa0ec4db4c6c
git apply /root/pre_state.patch
