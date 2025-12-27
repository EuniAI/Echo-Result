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
diff --git a/tests/auth_tests/test_username_validator_bug.py b/tests/auth_tests/test_username_validator_bug.py
new file mode 100644
index 0000000000..e8edfde048
--- /dev/null
+++ b/tests/auth_tests/test_username_validator_bug.py
@@ -0,0 +1,17 @@
+import pytest
+from django.contrib.auth import validators
+from django.core.exceptions import ValidationError
+from django.test import SimpleTestCase
+
+
+class UsernameValidatorsTests(SimpleTestCase):
+
+    def test_username_validator_allows_trailing_newline(self):
+        """
+        The ASCIIUsernameValidator and UnicodeUsernameValidator should not allow
+        a trailing newline character in the username.
+        """
+        for validator in (validators.ASCIIUsernameValidator(), validators.UnicodeUsernameValidator()):
+            with self.subTest(validator=validator.__class__.__name__):
+                with self.assertRaises(ValidationError):
+                    validator("user\n")

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/contrib/auth/validators\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 auth_tests.test_username_validator_bug
cat coverage.cover
git checkout d26b2424437dabeeca94d7900b37d2df4410da0c
git apply /root/pre_state.patch
