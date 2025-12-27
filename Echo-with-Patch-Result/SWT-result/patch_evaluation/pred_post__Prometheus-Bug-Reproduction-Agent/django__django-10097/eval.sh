#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD b9cf764be62e77b4777b3a75ec256f6209a57671 >> /root/pre_state.patch
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8
export PYTHONIOENCODING=utf8
export LANGUAGE=en_US:en
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff b9cf764be62e77b4777b3a75ec256f6209a57671
source /opt/miniconda3/bin/activate
conda activate testbed
python setup.py install
git apply -v - <<'EOF_114329324912'
diff --git a/django/core/validators.py b/django/core/validators.py
--- a/django/core/validators.py
+++ b/django/core/validators.py
@@ -94,7 +94,7 @@ class URLValidator(RegexValidator):
 
     regex = _lazy_re_compile(
         r'^(?:[a-z0-9\.\-\+]*)://'  # scheme is validated separately
-        r'(?:\S+(?::\S*)?@)?'  # user:pass authentication
+        r'(?:[^\s:@/]+(?::[^\s:@/]*)?@)?'  # user:pass authentication
         r'(?:' + ipv4_re + '|' + ipv6_re + '|' + host_re + ')'
         r'(?::\d{2,5})?'  # port
         r'(?:[/?#][^\s]*)?'  # resource path

EOF_114329324912
git apply -v - <<'EOF_114329324912'
diff --git a/tests/test_urlvalidator.py b/tests/test_urlvalidator.py
new file mode 100644
index 0000000000..a56ee5b813
--- /dev/null
+++ b/tests/test_urlvalidator.py
@@ -0,0 +1,15 @@
+from django.core.exceptions import ValidationError
+from django.core.validators import URLValidator
+from django.test import SimpleTestCase
+
+
+class URLValidatorUserInfoTest(SimpleTestCase):
+    def test_invalid_chars_in_userinfo(self):
+        """
+        URLValidator should reject URLs with unencoded special characters
+        in the userinfo part, as required by RFC 1738.
+        """
+        validator = URLValidator()
+        # The userinfo 'foo/bar' contains an unencoded '/', which is invalid.
+        with self.assertRaises(ValidationError):
+            validator('http://foo/bar@example.com')

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/core/validators\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 test_urlvalidator
cat coverage.cover
git checkout b9cf764be62e77b4777b3a75ec256f6209a57671
git apply /root/pre_state.patch
