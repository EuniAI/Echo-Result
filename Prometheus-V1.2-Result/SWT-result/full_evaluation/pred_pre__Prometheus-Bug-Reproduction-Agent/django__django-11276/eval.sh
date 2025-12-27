#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 28d5262fa3315690395f04e3619ed554dbaf725b >> /root/pre_state.patch
sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen
export LANG=en_US.UTF-8
export LANGUAGE=en_US:en
export LC_ALL=en_US.UTF-8
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 28d5262fa3315690395f04e3619ed554dbaf725b
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/tests/utils_tests/test_html2.py b/tests/utils_tests/test_html2.py
new file mode 100644
index 0000000000..311b0ff304
--- /dev/null
+++ b/tests/utils_tests/test_html2.py
@@ -0,0 +1,28 @@
+import os
+from datetime import datetime
+
+from django.test import SimpleTestCase
+from django.utils.functional import lazystr
+from django.utils.html import (
+    conditional_escape, escape, escapejs, format_html, html_safe, json_script,
+    linebreaks, smart_urlquote, strip_spaces_between_tags, strip_tags, urlize,
+)
+from django.utils.safestring import mark_safe
+
+
+class TestUtilsHtml(SimpleTestCase):
+
+    def check_output(self, function, value, output=None):
+        """
+        function(value) equals output. If output is None, function(value)
+        equals value.
+        """
+        if output is None:
+            output = value
+        self.assertEqual(function(value), output)
+
+    def test_escape_single_quote(self):
+        """
+        html.escape() escapes a single quote to &#x27;, not &#39;.
+        """
+        self.check_output(escape, "'", "&#x27;")

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/utils/html\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 utils_tests.test_html2
cat coverage.cover
git checkout 28d5262fa3315690395f04e3619ed554dbaf725b
git apply /root/pre_state.patch
