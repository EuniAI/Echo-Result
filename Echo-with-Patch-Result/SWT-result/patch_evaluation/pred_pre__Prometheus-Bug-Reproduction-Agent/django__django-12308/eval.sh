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
diff --git a/tests/admin_utils/test_json_field.py b/tests/admin_utils/test_json_field.py
new file mode 100644
index 0000000000..3f235b2048
--- /dev/null
+++ b/tests/admin_utils/test_json_field.py
@@ -0,0 +1,39 @@
+import datetime
+from decimal import Decimal
+
+from django import forms
+from django.conf import settings
+from django.contrib.admin import helpers
+from django.contrib.admin.utils import (
+    NestedObjects, display_for_field, display_for_value, flatten,
+    flatten_fieldsets, label_for_field, lookup_field, quote,
+)
+from django.db import DEFAULT_DB_ALIAS, models
+from django.test import SimpleTestCase, TestCase, override_settings, skipUnlessDBFeature
+from django.utils.formats import localize
+from django.utils.safestring import mark_safe
+
+from .models import (
+    Article, Car, Count, Event, EventGuide, Location, Site, Vehicle,
+)
+
+
+class JSONFieldTestModel(models.Model):
+    json_field = models.JSONField(default=dict)
+
+    class Meta:
+        app_label = 'admin_utils'
+
+
+@skipUnlessDBFeature('supports_json_field')
+class JSONFieldUtilTests(TestCase):
+
+    def test_display_for_field_json(self):
+        """
+        display_for_field() should display a JSON-serializable dict as JSON,
+        not as a Python repr.
+        """
+        field = JSONFieldTestModel._meta.get_field('json_field')
+        value = {'foo': 'bar'}
+        display_value = display_for_field(value, field, '-empty-')
+        self.assertEqual(display_value, '{"foo": "bar"}')

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/contrib/admin/utils\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 admin_utils.test_json_field
cat coverage.cover
git checkout 2e0f04507b17362239ba49830d26fec504d46978
git apply /root/pre_state.patch
