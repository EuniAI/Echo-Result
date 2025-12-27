#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 6a5ef557f80a8eb6a758ebe99c8bb477ca47459e >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 6a5ef557f80a8eb6a758ebe99c8bb477ca47459e
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/django/utils/html.py b/django/utils/html.py
--- a/django/utils/html.py
+++ b/django/utils/html.py
@@ -283,8 +283,9 @@ def trim_punctuation(lead, middle, trail):
             middle_unescaped = html.unescape(middle)
             stripped = middle_unescaped.rstrip(TRAILING_PUNCTUATION_CHARS)
             if middle_unescaped != stripped:
-                trail = middle[len(stripped):] + trail
-                middle = middle[:len(stripped) - len(middle_unescaped)]
+                punctuation_count = len(middle_unescaped) - len(stripped)
+                trail = middle[-punctuation_count:] + trail
+                middle = middle[:-punctuation_count]
                 trimmed_something = True
         return lead, middle, trail
 

EOF_114329324912
git apply -v - <<'EOF_114329324912'
diff --git a/tests/test_urlize_bug.py b/tests/test_urlize_bug.py
new file mode 100644
index 0000000000..438a0a881a
--- /dev/null
+++ b/tests/test_urlize_bug.py
@@ -0,0 +1,12 @@
+import unittest
+from django.utils.html import urlize
+
+class UrlizeEscapedStringTest(unittest.TestCase):
+    def test_urlize_handles_html_escaped_string_and_trailing_punctuation(self):
+        """
+        Test that urlize() correctly handles a URL with an HTML-escaped character
+        followed by trailing punctuation.
+        """
+        text = 'Search for google.com/?q=1&lt! and see.'
+        expected = 'Search for <a href="http://google.com/?q=1%3C">google.com/?q=1&lt</a>! and see.'
+        self.assertEqual(urlize(text), expected)

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/utils/html\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 test_urlize_bug
cat coverage.cover
git checkout 6a5ef557f80a8eb6a758ebe99c8bb477ca47459e
git apply /root/pre_state.patch
