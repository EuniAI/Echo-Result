#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD f4e93919e4608cfc50849a1f764fd856e0917401 >> /root/pre_state.patch
sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen
export LANG=en_US.UTF-8
export LANGUAGE=en_US:en
export LC_ALL=en_US.UTF-8
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff f4e93919e4608cfc50849a1f764fd856e0917401
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/tests/validators/test_value_in_error.py b/tests/validators/test_value_in_error.py
new file mode 100644
index 0000000000..d31724d6e0
--- /dev/null
+++ b/tests/validators/test_value_in_error.py
@@ -0,0 +1,20 @@
+from django.core.exceptions import ValidationError
+from django.core.validators import EmailValidator
+from django.test import SimpleTestCase
+
+
+class ValidatorsIncludeValueInErrorTest(SimpleTestCase):
+    def test_email_validator_includes_value(self):
+        """
+        A ValidationError from EmailValidator should have the invalid value in
+        its params dictionary, allowing for error messages like:
+        "'%(value)s' is not a valid email."
+        """
+        invalid_email = 'not-an-email'
+        message = "'%(value)s' is not a valid email."
+        validator = EmailValidator(message=message)
+
+        with self.assertRaises(ValidationError) as cm:
+            validator(invalid_email)
+
+        self.assertEqual(cm.exception.messages, ["'not-an-email' is not a valid email."])

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/core/validators\.py|django/forms/fields\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 validators.test_value_in_error
cat coverage.cover
git checkout f4e93919e4608cfc50849a1f764fd856e0917401
git apply /root/pre_state.patch
