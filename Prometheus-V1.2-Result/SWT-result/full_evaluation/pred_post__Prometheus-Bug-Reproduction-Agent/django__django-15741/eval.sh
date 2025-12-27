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
diff --git a/django/utils/formats.py b/django/utils/formats.py
--- a/django/utils/formats.py
+++ b/django/utils/formats.py
@@ -113,6 +113,7 @@ def get_format(format_type, lang=None, use_l10n=None):
             use_l10n = settings.USE_L10N
     if use_l10n and lang is None:
         lang = get_language()
+    format_type = str(format_type)  # format_type may be lazy.
     cache_key = (format_type, lang)
     try:
         return _format_cache[cache_key]

EOF_114329324912
git apply -v - <<'EOF_114329324912'
diff --git a/tests/template_tests/filter_tests/test_i18n.py b/tests/template_tests/filter_tests/test_i18n.py
new file mode 100644
index 0000000000..aabb86d274
--- /dev/null
+++ b/tests/template_tests/filter_tests/test_i18n.py
@@ -0,0 +1,20 @@
+import datetime
+import decimal
+
+from django.template import Context, Template
+from django.test import SimpleTestCase
+from django.utils.translation import gettext_lazy
+
+
+class FormattingTests(SimpleTestCase):
+    def setUp(self):
+        super().setUp()
+        self.dt = datetime.datetime(2009, 12, 31, 20, 50)
+        self.ctxt = Context({"dt": self.dt})
+
+    def test_date_filter_lazy_format(self):
+        """
+        The date filter should accept a lazy string for the format (#21949).
+        """
+        t = Template("{% load i18n %}{{ dt|date:_('Y-m-d') }}")
+        self.assertEqual(t.render(self.ctxt), "2009-12-31")

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/utils/formats\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 template_tests.filter_tests.test_i18n
cat coverage.cover
git checkout 8c0886b068ba4e224dd78104b93c9638b860b398
git apply /root/pre_state.patch
