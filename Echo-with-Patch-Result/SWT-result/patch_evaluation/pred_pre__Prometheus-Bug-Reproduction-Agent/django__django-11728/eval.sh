#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 05457817647368be4b019314fcc655445a5b4c0c >> /root/pre_state.patch
sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen
export LANG=en_US.UTF-8
export LANGUAGE=en_US:en
export LC_ALL=en_US.UTF-8
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 05457817647368be4b019314fcc655445a5b4c0c
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/django/contrib/admindocs/tests/test_simplify_regex.py b/django/contrib/admindocs/tests/test_simplify_regex.py
new file mode 100644
index 0000000000..4cc189dda8
--- /dev/null
+++ b/django/contrib/admindocs/tests/test_simplify_regex.py
@@ -0,0 +1,15 @@
+import unittest
+
+from django.contrib.admindocs.views import simplify_regex
+from django.test import SimpleTestCase
+
+
+class AdminDocViewFunctionsTests(SimpleTestCase):
+    def test_simplify_regex_trailing_named_group_without_trailing_slash(self):
+        """
+        simplify_regex() should handle named groups at the end of a regex
+        that doesn't have a trailing slash.
+        """
+        pattern = r'entries/(?P<pk>[^/.]+)/relationships/(?P<related_field>\w+)'
+        expected = '/entries/<pk>/relationships/<related_field>'
+        self.assertEqual(simplify_regex(pattern), expected)

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/contrib/admindocs/utils\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 django.contrib.admindocs.tests.test_simplify_regex
cat coverage.cover
git checkout 05457817647368be4b019314fcc655445a5b4c0c
git apply /root/pre_state.patch
