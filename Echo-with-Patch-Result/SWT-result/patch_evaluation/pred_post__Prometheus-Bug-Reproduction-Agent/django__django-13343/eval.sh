#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD ece18207cbb64dd89014e279ac636a6c9829828e >> /root/pre_state.patch
sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen
export LANG=en_US.UTF-8
export LANGUAGE=en_US:en
export LC_ALL=en_US.UTF-8
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff ece18207cbb64dd89014e279ac636a6c9829828e
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/django/db/models/fields/files.py b/django/db/models/fields/files.py
--- a/django/db/models/fields/files.py
+++ b/django/db/models/fields/files.py
@@ -229,6 +229,8 @@ def __init__(self, verbose_name=None, name=None, upload_to='', storage=None, **k
 
         self.storage = storage or default_storage
         if callable(self.storage):
+            # Hold a reference to the callable for deconstruct().
+            self._storage_callable = self.storage
             self.storage = self.storage()
             if not isinstance(self.storage, Storage):
                 raise TypeError(
@@ -279,7 +281,7 @@ def deconstruct(self):
             del kwargs["max_length"]
         kwargs['upload_to'] = self.upload_to
         if self.storage is not default_storage:
-            kwargs['storage'] = self.storage
+            kwargs['storage'] = getattr(self, '_storage_callable', self.storage)
         return name, path, args, kwargs
 
     def get_internal_type(self):

EOF_114329324912
git apply -v - <<'EOF_114329324912'
diff --git a/tests/test_filefield_deconstruction.py b/tests/test_filefield_deconstruction.py
new file mode 100644
index 0000000000..4b34c4bcd0
--- /dev/null
+++ b/tests/test_filefield_deconstruction.py
@@ -0,0 +1,29 @@
+from django.core.files.storage import FileSystemStorage
+from django.db import models
+from django.test import SimpleTestCase
+
+# These need to be at the top level for deconstruction.
+def get_storage():
+    """Callable that returns a storage instance."""
+    return CustomStorage()
+
+
+class CustomStorage(FileSystemStorage):
+    """A custom storage class for testing."""
+    pass
+
+
+class FileFieldDeconstructionTests(SimpleTestCase):
+    def test_callable_storage_deconstruction(self):
+        """
+        A FileField with a callable storage should deconstruct to a reference
+        to that callable, not an instance of the storage.
+        """
+        field = models.FileField(storage=get_storage, upload_to='custom_upload')
+        name, path, args, kwargs = field.deconstruct()
+
+        # Before the fix, kwargs['storage'] would be an instance of
+        # CustomStorage. After the fix, it will be the `get_storage` callable.
+        self.assertEqual(path, 'django.db.models.FileField')
+        self.assertEqual(args, [])
+        self.assertEqual(kwargs, {'storage': get_storage, 'upload_to': 'custom_upload'})

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/db/models/fields/files\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 test_filefield_deconstruction
cat coverage.cover
git checkout ece18207cbb64dd89014e279ac636a6c9829828e
git apply /root/pre_state.patch
