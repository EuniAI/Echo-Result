#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD e7fd69d051eaa67cb17f172a39b57253e9cb831a >> /root/pre_state.patch
sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen
export LANG=en_US.UTF-8
export LANGUAGE=en_US:en
export LC_ALL=en_US.UTF-8
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff e7fd69d051eaa67cb17f172a39b57253e9cb831a
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/tests/storage/test_file_upload_permissions.py b/tests/storage/test_file_upload_permissions.py
new file mode 100644
index 0000000000..1c63bc6f11
--- /dev/null
+++ b/tests/storage/test_file_upload_permissions.py
@@ -0,0 +1,51 @@
+import os
+import shutil
+import tempfile
+
+from django.core.files.storage import FileSystemStorage
+from django.core.files.uploadedfile import TemporaryUploadedFile
+from django.test import TestCase
+
+
+class FileUploadPermissionsTest(TestCase):
+    """
+    Tests for file upload permissions.
+    """
+    def setUp(self):
+        self.storage_dir = tempfile.mkdtemp()
+        # The FILE_UPLOAD_PERMISSIONS setting is None by default in the old code.
+        # We don't need to override it to test the default behavior.
+        self.storage = FileSystemStorage(location=self.storage_dir)
+
+    def tearDown(self):
+        shutil.rmtree(self.storage_dir)
+
+    def test_temporary_file_upload_permissions(self):
+        """
+        A file uploaded using TemporaryUploadedFile is moved, so it should
+        have its permissions set by the default FILE_UPLOAD_PERMISSIONS.
+        """
+        # This test is sensitive to the umask. Set a restrictive umask to
+        # ensure that the temporary file is created with permissions that
+        # would fail the test if they were preserved.
+        old_umask = os.umask(0o077)
+        try:
+            # Use TemporaryUploadedFile to simulate a large file upload, which
+            # is moved into place by FileSystemStorage.
+            with TemporaryUploadedFile('test.txt', 'text/plain', 1, 'utf-8') as tmp_file:
+                tmp_file.write(b'content')
+                tmp_file.seek(0)
+                # Before the fix, FILE_UPLOAD_PERMISSIONS is None by default,
+                # so os.chmod() is not called. The restrictive permissions of
+                # the temporary file (e.g., 0o600 due to the umask) are kept.
+                # After the fix, the default is 0o644, and os.chmod() is called.
+                saved_name = self.storage.save('test_permissions.txt', tmp_file)
+                path = self.storage.path(saved_name)
+                mode = os.stat(path).st_mode
+                self.addCleanup(self.storage.delete, saved_name)
+
+                # This assertion will fail before the fix (e.g. 0o600 != 0o644)
+                # and pass after.
+                self.assertEqual(mode & 0o777, 0o644)
+        finally:
+            os.umask(old_umask)

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/conf/global_settings\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 storage.test_file_upload_permissions
cat coverage.cover
git checkout e7fd69d051eaa67cb17f172a39b57253e9cb831a
git apply /root/pre_state.patch
