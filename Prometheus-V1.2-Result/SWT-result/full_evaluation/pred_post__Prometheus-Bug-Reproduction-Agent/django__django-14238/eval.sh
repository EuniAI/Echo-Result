#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 30e123ed351317b7527f632b3b7dc4e81e850449 >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 30e123ed351317b7527f632b3b7dc4e81e850449
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/django/db/models/fields/__init__.py b/django/db/models/fields/__init__.py
--- a/django/db/models/fields/__init__.py
+++ b/django/db/models/fields/__init__.py
@@ -2524,7 +2524,7 @@ def __instancecheck__(self, instance):
         return isinstance(instance, self._subclasses) or super().__instancecheck__(instance)
 
     def __subclasscheck__(self, subclass):
-        return subclass in self._subclasses or super().__subclasscheck__(subclass)
+        return issubclass(subclass, self._subclasses) or super().__subclasscheck__(subclass)
 
 
 class AutoField(AutoFieldMixin, IntegerField, metaclass=AutoFieldMeta):

EOF_114329324912
git apply -v - <<'EOF_114329324912'
diff --git a/tests/model_options/test_default_auto_field.py b/tests/model_options/test_default_auto_field.py
new file mode 100644
index 0000000000..096ca0bb51
--- /dev/null
+++ b/tests/model_options/test_default_auto_field.py
@@ -0,0 +1,66 @@
+from django.core.exceptions import ImproperlyConfigured
+from django.db import models
+from django.test import SimpleTestCase, override_settings
+from django.test.utils import isolate_apps
+
+
+# Define classes at the module level to make them importable.
+class MyBigAutoField(models.BigAutoField):
+    pass
+
+
+class MySmallAutoField(models.SmallAutoField):
+    pass
+
+
+@isolate_apps('model_options')
+class TestDefaultPK(SimpleTestCase):
+    @override_settings(DEFAULT_AUTO_FIELD='django.db.models.NonexistentAutoField')
+    def test_default_auto_field_setting_nonexistent(self):
+        msg = (
+            "DEFAULT_AUTO_FIELD refers to the module "
+            "'django.db.models.NonexistentAutoField' that could not be "
+            "imported."
+        )
+        with self.assertRaisesMessage(ImproperlyConfigured, msg):
+            class Model(models.Model):
+                pass
+
+    @isolate_apps('model_options.apps.ModelPKNonexistentConfig')
+    def test_app_default_auto_field_nonexistent(self):
+        msg = (
+            "model_options.apps.ModelPKNonexistentConfig.default_auto_field "
+            "refers to the module 'django.db.models.NonexistentAutoField' "
+            "that could not be imported."
+        )
+        with self.assertRaisesMessage(ImproperlyConfigured, msg):
+            class Model(models.Model):
+                pass
+
+    @override_settings(DEFAULT_AUTO_FIELD='django.db.models.TextField')
+    def test_default_auto_field_setting_non_auto(self):
+        msg = (
+            "Primary key 'django.db.models.TextField' referred by "
+            "DEFAULT_AUTO_FIELD must subclass AutoField."
+        )
+        with self.assertRaisesMessage(ValueError, msg):
+            class Model(models.Model):
+                pass
+
+    def test_default_auto_field_subclasses(self):
+        """
+        Subclasses of BigAutoField and SmallAutoField can be used for
+        DEFAULT_AUTO_FIELD.
+        """
+        module_path = __name__
+        for field_name, field_class in (
+            ('MyBigAutoField', MyBigAutoField),
+            ('MySmallAutoField', MySmallAutoField),
+        ):
+            field_path = f'{module_path}.{field_name}'
+            with self.subTest(field=field_path):
+                with override_settings(DEFAULT_AUTO_FIELD=field_path):
+                    class Model(models.Model):
+                        pass
+
+                    self.assertIsInstance(Model._meta.pk, field_class)

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/db/models/fields/__init__\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 model_options.test_default_auto_field
cat coverage.cover
git checkout 30e123ed351317b7527f632b3b7dc4e81e850449
git apply /root/pre_state.patch
