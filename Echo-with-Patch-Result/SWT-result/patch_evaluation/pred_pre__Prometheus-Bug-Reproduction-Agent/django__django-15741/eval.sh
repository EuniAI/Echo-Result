#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 8c0886b068ba4e224dd78104b93c9638b860b398 >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 8c0886b068ba4e224dd78104b93c9638b860b398
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/tests/test_ticket_25812.py b/tests/test_ticket_25812.py
new file mode 100644
index 0000000000..1788be306b
--- /dev/null
+++ b/tests/test_ticket_25812.py
@@ -0,0 +1,30 @@
+import datetime
+
+from django.test import SimpleTestCase
+from django.utils import translation
+from django.utils.formats import date_format, reset_format_cache
+from django.utils.translation import gettext_lazy
+
+
+class FormattingTests(SimpleTestCase):
+
+    def setUp(self):
+        super().setUp()
+        reset_format_cache()
+
+    def tearDown(self):
+        reset_format_cache()
+        super().tearDown()
+
+    def test_lazy_string_as_date_format_argument(self):
+        """
+        get_format() shouldn't raise a TypeError on a lazy format string
+        (#25812).
+        """
+        d = datetime.date(2015, 10, 26)
+        lazy_format = gettext_lazy('Y-m-d')
+        # With an active language, format localization is triggered. On the
+        # unpatched code, this causes the lazy format object to be passed to
+        # getattr(), raising a TypeError.
+        with translation.override('en'):
+            self.assertEqual(date_format(d, lazy_format), '2015-10-26')

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/utils/formats\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 test_ticket_25812
cat coverage.cover
git checkout 8c0886b068ba4e224dd78104b93c9638b860b398
git apply /root/pre_state.patch
