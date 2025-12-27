#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD a708f39ce67af174df90c5b5e50ad1976cec7cb8 >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff a708f39ce67af174df90c5b5e50ad1976cec7cb8
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/django/core/validators.py b/django/core/validators.py
--- a/django/core/validators.py
+++ b/django/core/validators.py
@@ -92,6 +92,7 @@ class URLValidator(RegexValidator):
         r'\Z', re.IGNORECASE)
     message = _('Enter a valid URL.')
     schemes = ['http', 'https', 'ftp', 'ftps']
+    unsafe_chars = frozenset('\t\r\n')
 
     def __init__(self, schemes=None, **kwargs):
         super().__init__(**kwargs)
@@ -101,6 +102,8 @@ def __init__(self, schemes=None, **kwargs):
     def __call__(self, value):
         if not isinstance(value, str):
             raise ValidationError(self.message, code=self.code, params={'value': value})
+        if self.unsafe_chars.intersection(value):
+            raise ValidationError(self.message, code=self.code, params={'value': value})
         # Check if the scheme is valid.
         scheme = value.split('://')[0].lower()
         if scheme not in self.schemes:

EOF_114329324912
git apply -v - <<'EOF_114329324912'
diff --git a/tests/forms_tests/tests/test_urlvalidator.py b/tests/forms_tests/tests/test_urlvalidator.py
new file mode 100644
index 0000000000..1089c84dee
--- /dev/null
+++ b/tests/forms_tests/tests/test_urlvalidator.py
@@ -0,0 +1,21 @@
+from django.core.exceptions import ValidationError
+from django.core.validators import URLValidator
+from django.test import SimpleTestCase
+
+
+class URLValidatorTest(SimpleTestCase):
+    def test_url_with_newline_is_invalid(self):
+        """
+        A URL containing a newline should not be considered valid. The underlying
+        urllib.parse.urlsplit() was changed in Python 3.9+ to strip leading
+        and trailing whitespace, which includes newlines.
+        """
+        validator = URLValidator()
+        urls = [
+            "http://www.djangoproject.com/\n",
+            "http://[::ffff:192.9.5.5]\n",
+        ]
+        for url in urls:
+            with self.subTest(url=url):
+                with self.assertRaises(ValidationError):
+                    validator(url)

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/core/validators\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 forms_tests.tests.test_urlvalidator
cat coverage.cover
git checkout a708f39ce67af174df90c5b5e50ad1976cec7cb8
git apply /root/pre_state.patch
