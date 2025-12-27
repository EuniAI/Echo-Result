#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD d26b2424437dabeeca94d7900b37d2df4410da0c >> /root/pre_state.patch
sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen
export LANG=en_US.UTF-8
export LANGUAGE=en_US:en
export LC_ALL=en_US.UTF-8
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff d26b2424437dabeeca94d7900b37d2df4410da0c
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/django/contrib/auth/validators.py b/django/contrib/auth/validators.py
--- a/django/contrib/auth/validators.py
+++ b/django/contrib/auth/validators.py
@@ -7,7 +7,7 @@
 
 @deconstructible
 class ASCIIUsernameValidator(validators.RegexValidator):
-    regex = r'^[\w.@+-]+$'
+    regex = r'^[\w.@+-]+\Z'
     message = _(
         'Enter a valid username. This value may contain only English letters, '
         'numbers, and @/./+/-/_ characters.'
@@ -17,7 +17,7 @@ class ASCIIUsernameValidator(validators.RegexValidator):
 
 @deconstructible
 class UnicodeUsernameValidator(validators.RegexValidator):
-    regex = r'^[\w.@+-]+$'
+    regex = r'^[\w.@+-]+\Z'
     message = _(
         'Enter a valid username. This value may contain only letters, '
         'numbers, and @/./+/-/_ characters.'

EOF_114329324912
git apply -v - <<'EOF_114329324912'
diff --git a/tests/auth_tests/test_username_trailing_newline.py b/tests/auth_tests/test_username_trailing_newline.py
new file mode 100644
index 0000000000..d625314b48
--- /dev/null
+++ b/tests/auth_tests/test_username_trailing_newline.py
@@ -0,0 +1,29 @@
+from django.contrib.auth import validators
+from django.core.exceptions import ValidationError
+from django.test import SimpleTestCase
+
+
+class UsernameTrailingNewlineValidatorTest(SimpleTestCase):
+    """
+    Tests that username validators reject usernames with trailing newlines.
+    """
+
+    def test_ascii_validator_rejects_trailing_newline(self):
+        """
+        The ASCIIUsernameValidator should raise a ValidationError for a
+        username with a trailing newline.
+        """
+        validator = validators.ASCIIUsernameValidator()
+        # Use hex escape for newline to avoid string parsing issues.
+        with self.assertRaises(ValidationError):
+            validator('testuser\x0a')
+
+    def test_unicode_validator_rejects_trailing_newline(self):
+        """
+        The UnicodeUsernameValidator should raise a ValidationError for a
+        username with a trailing newline.
+        """
+        validator = validators.UnicodeUsernameValidator()
+        # Use hex escape for newline to avoid string parsing issues.
+        with self.assertRaises(ValidationError):
+            validator('testuser\x0a')

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/contrib/auth/validators\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 auth_tests.test_username_trailing_newline
cat coverage.cover
git checkout d26b2424437dabeeca94d7900b37d2df4410da0c
git apply /root/pre_state.patch
