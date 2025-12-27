#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 84633905273fc916e3d17883810d9969c03f73c2 >> /root/pre_state.patch
sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen
export LANG=en_US.UTF-8
export LANGUAGE=en_US:en
export LC_ALL=en_US.UTF-8
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 84633905273fc916e3d17883810d9969c03f73c2
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/tests/model_fields/test_get_field_display.py b/tests/model_fields/test_get_field_display.py
new file mode 100644
index 0000000000..d9c8830d64
--- /dev/null
+++ b/tests/model_fields/test_get_field_display.py
@@ -0,0 +1,24 @@
+from django.db import models
+from django.test import SimpleTestCase
+from django.utils.translation import gettext_lazy as _
+
+# Model based on the user's example in the issue description.
+class FooBar(models.Model):
+    foo_bar = models.CharField(_("foo"), max_length=10, choices=[(1, 'foo'), (2, 'bar')])
+
+    def get_foo_bar_display(self):
+        return "something"
+
+    class Meta:
+        # app_label is needed for tests that define models locally.
+        app_label = 'model_fields'
+
+
+class GetFieldDisplayOverrideTests(SimpleTestCase):
+    def test_override_get_field_display(self):
+        """
+        Tests that get_FIELD_display() can be overridden on a model.
+        """
+        instance = FooBar(foo_bar=1)
+        # This will fail in Django 2.2+, returning 'foo' instead of 'something'.
+        self.assertEqual(instance.get_foo_bar_display(), "something")

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/db/models/fields/__init__\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 model_fields.test_get_field_display
cat coverage.cover
git checkout 84633905273fc916e3d17883810d9969c03f73c2
git apply /root/pre_state.patch
