#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD e8fcdaad5c428878d0a5d6ba820d957013f75595 >> /root/pre_state.patch
sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen
export LANG=en_US.UTF-8
export LANGUAGE=en_US:en
export LC_ALL=en_US.UTF-8
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff e8fcdaad5c428878d0a5d6ba820d957013f75595
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/django/contrib/admindocs/tests/test_trim_docstring.py b/django/contrib/admindocs/tests/test_trim_docstring.py
new file mode 100644
index 0000000000..166c5a9de2
--- /dev/null
+++ b/django/contrib/admindocs/tests/test_trim_docstring.py
@@ -0,0 +1,18 @@
+import unittest
+
+from django.contrib.admindocs.utils import docutils_is_available, trim_docstring
+from django.test import SimpleTestCase
+
+
+@unittest.skipUnless(docutils_is_available, "no docutils installed.")
+class TrimDocstringTests(SimpleTestCase):
+    def test_trim_docstring_no_leading_newline(self):
+        """
+        trim_docstring() correctly trims docstrings that don't start with a
+        newline, calculating indentation from the second line onwards.
+        """
+        docstring = """Summary line.
+          Line 2.
+            Line 3."""
+        expected = "Summary line.\nLine 2.\n  Line 3."
+        self.assertEqual(trim_docstring(docstring), expected)

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/contrib/admindocs/utils\.py|django/contrib/admindocs/views\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 django.contrib.admindocs.tests.test_trim_docstring
cat coverage.cover
git checkout e8fcdaad5c428878d0a5d6ba820d957013f75595
git apply /root/pre_state.patch
