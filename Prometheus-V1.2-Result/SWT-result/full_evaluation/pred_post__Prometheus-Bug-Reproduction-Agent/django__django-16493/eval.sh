#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD e3a4cee081cf60650b8824f0646383b79cb110e7 >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff e3a4cee081cf60650b8824f0646383b79cb110e7
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/django/db/models/fields/files.py b/django/db/models/fields/files.py
--- a/django/db/models/fields/files.py
+++ b/django/db/models/fields/files.py
@@ -295,8 +295,9 @@ def deconstruct(self):
         if kwargs.get("max_length") == 100:
             del kwargs["max_length"]
         kwargs["upload_to"] = self.upload_to
-        if self.storage is not default_storage:
-            kwargs["storage"] = getattr(self, "_storage_callable", self.storage)
+        storage = getattr(self, "_storage_callable", self.storage)
+        if storage is not default_storage:
+            kwargs["storage"] = storage
         return name, path, args, kwargs
 
     def get_internal_type(self):

EOF_114329324912
git apply -v - <<'EOF_114329324912'
diff --git a/tests/field_deconstruction/test_file_field.py b/tests/field_deconstruction/test_file_field.py
new file mode 100644
index 0000000000..68813da410
--- /dev/null
+++ b/tests/field_deconstruction/test_file_field.py
@@ -0,0 +1,24 @@
+import unittest
+
+from django.core.files.storage import default_storage
+from django.db import models
+from django.test import SimpleTestCase
+
+
+# For the purposes of this test, this function must be defined at the module
+# level so that it can be imported by the migration framework.
+def deconstruct_test_storage():
+    return default_storage
+
+
+class FieldDeconstructionTests(SimpleTestCase):
+    def test_file_field_with_callable_storage_returning_default(self):
+        """
+        A callable storage that returns default_storage is deconstructed
+        correctly.
+        """
+        field = models.FileField(storage=deconstruct_test_storage)
+        name, path, args, kwargs = field.deconstruct()
+        self.assertEqual(path, "django.db.models.FileField")
+        self.assertEqual(args, [])
+        self.assertEqual(kwargs, {"storage": deconstruct_test_storage})

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/db/models/fields/files\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 field_deconstruction.test_file_field
cat coverage.cover
git checkout e3a4cee081cf60650b8824f0646383b79cb110e7
git apply /root/pre_state.patch
