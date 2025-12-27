#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD fbe850106b2e4b85f838219cb9e1df95fba6c164 >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff fbe850106b2e4b85f838219cb9e1df95fba6c164
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/django/http/response.py b/django/http/response.py
--- a/django/http/response.py
+++ b/django/http/response.py
@@ -609,7 +609,9 @@ def set_headers(self, filelike):
                 # Encoding isn't set to prevent browsers from automatically
                 # uncompressing files.
                 content_type = {
+                    "br": "application/x-brotli",
                     "bzip2": "application/x-bzip",
+                    "compress": "application/x-compress",
                     "gzip": "application/gzip",
                     "xz": "application/x-xz",
                 }.get(encoding, content_type)

EOF_114329324912
git apply -v - <<'EOF_114329324912'
diff --git a/tests/test_fileresponse.py b/tests/test_fileresponse.py
new file mode 100644
index 0000000000..940a2206ee
--- /dev/null
+++ b/tests/test_fileresponse.py
@@ -0,0 +1,21 @@
+import tempfile
+
+from django.http import FileResponse
+from django.test import SimpleTestCase
+
+
+class FileResponseMimeTypeTests(SimpleTestCase):
+    def test_compressed_content_type_guessing(self):
+        """
+        FileResponse should guess the content type of compressed files that
+        mimetypes doesn't know about, like .br and .Z.
+        """
+        test_cases = (
+            (".html.br", "application/brotli"),
+            (".html.Z", "application/x-compress"),
+        )
+        for extension, expected_content_type in test_cases:
+            with self.subTest(extension=extension):
+                with tempfile.NamedTemporaryFile(suffix=extension) as tmp_file:
+                    response = FileResponse(tmp_file)
+                self.assertEqual(response.headers["Content-Type"], expected_content_type)

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/http/response\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 test_fileresponse
cat coverage.cover
git checkout fbe850106b2e4b85f838219cb9e1df95fba6c164
git apply /root/pre_state.patch
