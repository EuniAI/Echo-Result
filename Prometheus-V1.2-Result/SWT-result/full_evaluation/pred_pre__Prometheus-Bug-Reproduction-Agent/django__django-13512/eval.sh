#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD b79088306513d5ed76d31ac40ab3c15f858946ea >> /root/pre_state.patch
sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen
export LANG=en_US.UTF-8
export LANGUAGE=en_US:en
export LC_ALL=en_US.UTF-8
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff b79088306513d5ed76d31ac40ab3c15f858946ea
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/tests/admin_widgets/test_json_widget.py b/tests/admin_widgets/test_json_widget.py
new file mode 100644
index 0000000000..5def293c65
--- /dev/null
+++ b/tests/admin_widgets/test_json_widget.py
@@ -0,0 +1,39 @@
+import json
+
+from django.contrib import admin
+from django.db import models
+from django.test import SimpleTestCase
+
+
+# Minimal model for the test, similar to those in the test suite.
+class DataModel(models.Model):
+    json_data = models.JSONField()
+
+    class Meta:
+        app_label = 'admin_widgets'
+
+
+class AdminJSONWidgetTests(SimpleTestCase):
+    def test_formfield_for_jsonfield_handles_unicode(self):
+        """
+        The widget for JSONField should use json.dumps() with
+        ensure_ascii=False so that non-ASCII characters are displayed
+        correctly in the admin.
+        """
+        class DataModelAdmin(admin.ModelAdmin):
+            pass
+
+        model_admin = DataModelAdmin(DataModel, admin.site)
+        form_field = model_admin.formfield_for_dbfield(
+            DataModel._meta.get_field('json_data'), request=None
+        )
+
+        # Python value with unicode characters.
+        python_value = {'key': '中国'}
+        # The form field's prepare_value() serializes the value for the widget.
+        prepared_value = form_field.prepare_value(python_value)
+
+        # The bug causes this to be '{"key": "\u4e2d\u56fd"}'.
+        # The fix should ensure it is '{"key": "中国"}'. This assertion will
+        # fail with the bug and pass when the bug is fixed.
+        self.assertEqual(prepared_value, '{"key": "中国"}')

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/contrib/admin/utils\.py|django/forms/fields\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 admin_widgets.test_json_widget
cat coverage.cover
git checkout b79088306513d5ed76d31ac40ab3c15f858946ea
git apply /root/pre_state.patch
