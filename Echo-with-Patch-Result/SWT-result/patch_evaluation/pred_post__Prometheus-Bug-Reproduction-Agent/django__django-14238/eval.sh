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
diff --git a/tests/test_autofield.py b/tests/test_autofield.py
new file mode 100644
index 0000000000..3777e43370
--- /dev/null
+++ b/tests/test_autofield.py
@@ -0,0 +1,19 @@
+from django.db import models
+from django.test import SimpleTestCase
+
+
+class AutoFieldSubclassTests(SimpleTestCase):
+    def test_subclasses_of_autofield_subclasses(self):
+        """
+        Subclasses of BigAutoField and SmallAutoField should also be
+        subclasses of AutoField.
+        """
+        class MyBigAutoField(models.BigAutoField):
+            pass
+
+        class MySmallAutoField(models.SmallAutoField):
+            pass
+
+        for field in (MyBigAutoField, MySmallAutoField):
+            with self.subTest(field=field.__name__):
+                self.assertTrue(issubclass(field, models.AutoField))

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/db/models/fields/__init__\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 test_autofield
cat coverage.cover
git checkout 30e123ed351317b7527f632b3b7dc4e81e850449
git apply /root/pre_state.patch
