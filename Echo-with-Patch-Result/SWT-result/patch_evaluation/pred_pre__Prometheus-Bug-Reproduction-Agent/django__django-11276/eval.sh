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
diff --git a/tests/test_html_escape.py b/tests/test_html_escape.py
new file mode 100644
index 0000000000..b20ecc4a37
--- /dev/null
+++ b/tests/test_html_escape.py
@@ -0,0 +1,10 @@
+from django.test import SimpleTestCase
+from django.utils.html import escape
+
+
+class EscapeBackwardsIncompatibleTest(SimpleTestCase):
+    def test_escape_single_quote(self):
+        """
+        html.escape() escapes a single quote to &#x27; instead of &#39;.
+        """
+        self.assertEqual(escape("'"), "&#x27;")

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/utils/html\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 test_html_escape
cat coverage.cover
git checkout 28d5262fa3315690395f04e3619ed554dbaf725b
git apply /root/pre_state.patch
