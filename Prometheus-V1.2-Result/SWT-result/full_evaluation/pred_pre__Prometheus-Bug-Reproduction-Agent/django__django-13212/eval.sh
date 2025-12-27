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
diff --git a/tests/validation/test_email_validator.py b/tests/validation/test_email_validator.py
new file mode 100644
index 0000000000..4ca41718a4
--- /dev/null
+++ b/tests/validation/test_email_validator.py
@@ -0,0 +1,16 @@
+from django.core.exceptions import ValidationError
+from django.core.validators import EmailValidator
+from django.test import SimpleTestCase
+
+
+class ValidatorsTests(SimpleTestCase):
+    def test_email_validator_value_in_error(self):
+        """
+        ValidationError from EmailValidator includes the invalid value in
+        its params.
+        """
+        value = 'blah'
+        message = '“%(value)s” is not a valid email.'
+        validator = EmailValidator(message=message)
+        with self.assertRaisesMessage(ValidationError, '“blah” is not a valid email.'):
+            validator(value)

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/core/validators\.py|django/forms/fields\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 validation.test_email_validator
cat coverage.cover
git checkout f4e93919e4608cfc50849a1f764fd856e0917401
git apply /root/pre_state.patch
