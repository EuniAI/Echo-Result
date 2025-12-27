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
diff --git a/tests/validators/test_rfc1738.py b/tests/validators/test_rfc1738.py
new file mode 100644
index 0000000000..c409fe02b6
--- /dev/null
+++ b/tests/validators/test_rfc1738.py
@@ -0,0 +1,22 @@
+from django.core.exceptions import ValidationError
+from django.core.validators import URLValidator
+from django.test import SimpleTestCase
+
+
+class URLValidatorRFC1738Tests(SimpleTestCase):
+    """
+    Tests for URLValidator to ensure it adheres to RFC 1738 regarding
+    special characters in the user/password section of a URL.
+    """
+
+    def test_rejects_unencoded_special_chars_in_user_info(self):
+        """
+        Checks that URLValidator rejects URLs with unencoded special
+        characters (e.g., '/', '@') in the user information part, which is
+        required by RFC 1738.
+        """
+        validator = URLValidator()
+        # This URL is invalid because the '/' in 'foo/bar' must be percent-encoded.
+        invalid_url = 'http://foo/bar@example.com'
+        with self.assertRaises(ValidationError):
+            validator(invalid_url)

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/core/validators\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 validators.test_rfc1738
cat coverage.cover
git checkout b9cf764be62e77b4777b3a75ec256f6209a57671
git apply /root/pre_state.patch
