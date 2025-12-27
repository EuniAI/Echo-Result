#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 0c42cdf0d2422f4c080e93594d5d15381d6e955e >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 0c42cdf0d2422f4c080e93594d5d15381d6e955e
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/django/db/models/base.py b/django/db/models/base.py
--- a/django/db/models/base.py
+++ b/django/db/models/base.py
@@ -1299,6 +1299,11 @@ def check(cls, **kwargs):
     def _check_default_pk(cls):
         if (
             cls._meta.pk.auto_created and
+            # Inherited PKs are checked in parents models.
+            not (
+                isinstance(cls._meta.pk, OneToOneField) and
+                cls._meta.pk.remote_field.parent_link
+            ) and
             not settings.is_overridden('DEFAULT_AUTO_FIELD') and
             not cls._meta.app_config._is_default_auto_field_overridden
         ):

EOF_114329324912
git apply -v - <<'EOF_114329324912'
diff --git a/tests/check_framework/test_model_default_auto_field.py b/tests/check_framework/test_model_default_auto_field.py
new file mode 100644
index 0000000000..b73b366318
--- /dev/null
+++ b/tests/check_framework/test_model_default_auto_field.py
@@ -0,0 +1,49 @@
+from unittest import mock
+
+from django.core import checks
+from django.core.checks import Warning
+from django.db import models
+from django.test import SimpleTestCase
+from django.test.utils import isolate_apps, override_settings, override_system_checks
+
+
+def mocked_is_overridden(self, setting):
+    # Force treating DEFAULT_AUTO_FIELD = 'django.db.models.AutoField' as a not
+    # overridden setting.
+    return (
+        setting != 'DEFAULT_AUTO_FIELD' or
+        self.DEFAULT_AUTO_FIELD != 'django.db.models.AutoField'
+    )
+
+
+@mock.patch('django.conf.UserSettingsHolder.is_overridden', mocked_is_overridden)
+@override_settings(DEFAULT_AUTO_FIELD='django.db.models.AutoField')
+@isolate_apps('check_framework.apps.CheckDefaultPKConfig', attr_name='apps')
+@override_system_checks([checks.model_checks.check_all_models])
+class ModelDefaultAutoFieldTests(SimpleTestCase):
+    def test_multi_table_inheritance(self):
+        """
+        W042 is not raised for a model with a primary key inherited from a
+        parent model.
+        """
+        class Parent(models.Model):
+            pass
+
+        class Child(Parent):
+            pass
+
+        # The warning is expected for Parent, but not for Child.
+        self.assertEqual(checks.run_checks(app_configs=self.apps.get_app_configs()), [
+            Warning(
+                "Auto-created primary key used when not defining a primary "
+                "key type, by default 'django.db.models.AutoField'.",
+                hint=(
+                    "Configure the DEFAULT_AUTO_FIELD setting or the "
+                    "CheckDefaultPKConfig.default_auto_field attribute to "
+                    "point to a subclass of AutoField, e.g. "
+                    "'django.db.models.BigAutoField'."
+                ),
+                obj=Parent,
+                id='models.W042',
+            ),
+        ])

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/db/models/base\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 check_framework.test_model_default_auto_field
cat coverage.cover
git checkout 0c42cdf0d2422f4c080e93594d5d15381d6e955e
git apply /root/pre_state.patch
