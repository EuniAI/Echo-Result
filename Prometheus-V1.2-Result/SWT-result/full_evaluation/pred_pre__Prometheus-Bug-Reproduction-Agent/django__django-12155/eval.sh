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
diff --git a/tests/admin_docs/test_trim_docstring.py b/tests/admin_docs/test_trim_docstring.py
new file mode 100644
index 0000000000..03154a1149
--- /dev/null
+++ b/tests/admin_docs/test_trim_docstring.py
@@ -0,0 +1,19 @@
+import unittest
+
+from django.contrib.admindocs.utils import (
+    docutils_is_available, trim_docstring,
+)
+from django.test import SimpleTestCase
+
+
+@unittest.skipUnless(docutils_is_available, "no docutils installed.")
+class TrimDocstringTests(SimpleTestCase):
+
+    def test_trim_docstring_first_line_not_empty(self):
+        """
+        trim_docstring() correctly handles docstrings where the first line of
+        content has no preceding newline.
+        """
+        docstring = "First line summary.\n\n    Second line body."
+        expected = "First line summary.\n\nSecond line body."
+        self.assertEqual(trim_docstring(docstring), expected)

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/contrib/admindocs/utils\.py|django/contrib/admindocs/views\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 admin_docs.test_trim_docstring
cat coverage.cover
git checkout e8fcdaad5c428878d0a5d6ba820d957013f75595
git apply /root/pre_state.patch
