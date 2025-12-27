#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 2e0f04507b17362239ba49830d26fec504d46978 >> /root/pre_state.patch
sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen
export LANG=en_US.UTF-8
export LANGUAGE=en_US:en
export LC_ALL=en_US.UTF-8
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 2e0f04507b17362239ba49830d26fec504d46978
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/django/contrib/admin/utils.py b/django/contrib/admin/utils.py
--- a/django/contrib/admin/utils.py
+++ b/django/contrib/admin/utils.py
@@ -398,6 +398,11 @@ def display_for_field(value, field, empty_value_display):
         return formats.number_format(value)
     elif isinstance(field, models.FileField) and value:
         return format_html('<a href="{}">{}</a>', value.url, value)
+    elif isinstance(field, models.JSONField) and value:
+        try:
+            return field.get_prep_value(value)
+        except TypeError:
+            return display_for_value(value, empty_value_display)
     else:
         return display_for_value(value, empty_value_display)
 

EOF_114329324912
git apply -v - <<'EOF_114329324912'
diff --git a/tests/admin_utils/test_jsonfield_display.py b/tests/admin_utils/test_jsonfield_display.py
new file mode 100644
index 0000000000..f9223eed28
--- /dev/null
+++ b/tests/admin_utils/test_jsonfield_display.py
@@ -0,0 +1,17 @@
+import json
+
+from django.contrib.admin.utils import display_for_field
+from django.db import models
+from django.test import SimpleTestCase
+
+
+class JSONFieldDisplayTests(SimpleTestCase):
+    def test_display_for_json_field(self):
+        """
+        display_for_field() should serialize a JSONField value to a JSON string
+        for display.
+        """
+        field = models.JSONField()
+        value = {'foo': 'bar'}
+        result = display_for_field(value, field, '---')
+        self.assertEqual(result, json.dumps(value))

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/contrib/admin/utils\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 admin_utils.test_jsonfield_display
cat coverage.cover
git checkout 2e0f04507b17362239ba49830d26fec504d46978
git apply /root/pre_state.patch
