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
diff --git a/tests/test_callable_storage.py b/tests/test_callable_storage.py
new file mode 100644
index 0000000000..e5fb535527
--- /dev/null
+++ b/tests/test_callable_storage.py
@@ -0,0 +1,17 @@
+from django.core.files.storage import default_storage
+from django.db import models
+from django.test import SimpleTestCase
+
+
+def get_default_storage():
+    return default_storage
+
+
+class CallableStorageDeconstructionTest(SimpleTestCase):
+    def test_callable_storage_returns_default_storage(self):
+        field = models.FileField(storage=get_default_storage)
+        name, path, args, kwargs = field.deconstruct()
+        self.assertEqual(path, "django.db.models.FileField")
+        self.assertEqual(args, [])
+        self.assertIn("storage", kwargs)
+        self.assertEqual(kwargs["storage"], get_default_storage)

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/db/models/fields/files\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 test_callable_storage
cat coverage.cover
git checkout e3a4cee081cf60650b8824f0646383b79cb110e7
git apply /root/pre_state.patch
