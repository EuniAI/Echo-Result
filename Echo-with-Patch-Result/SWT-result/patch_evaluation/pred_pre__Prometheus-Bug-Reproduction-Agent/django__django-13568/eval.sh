#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD ede9fac75807fe5810df66280a60e7068cc97e4a >> /root/pre_state.patch
sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen
export LANG=en_US.UTF-8
export LANGUAGE=en_US:en
export LC_ALL=en_US.UTF-8
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff ede9fac75807fe5810df66280a60e7068cc97e4a
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/tests/auth_tests/test_user_model_unique_constraint.py b/tests/auth_tests/test_user_model_unique_constraint.py
new file mode 100644
index 0000000000..2aeb113619
--- /dev/null
+++ b/tests/auth_tests/test_user_model_unique_constraint.py
@@ -0,0 +1,32 @@
+from django.contrib.auth.checks import check_user_model
+from django.contrib.auth.models import AbstractBaseUser
+from django.core import checks
+from django.db import models
+from django.db.models.constraints import UniqueConstraint
+from django.test import SimpleTestCase, override_settings, override_system_checks
+from django.test.utils import isolate_apps
+
+
+@isolate_apps('auth_tests', attr_name='apps')
+@override_system_checks([check_user_model])
+class UserModelChecksWithUniqueConstraintTests(SimpleTestCase):
+    @override_settings(AUTH_USER_MODEL='auth_tests.UserWithUniqueConstraint')
+    def test_username_field_unique_constraint(self):
+        """
+        auth.E003 is not raised when USERNAME_FIELD has a UniqueConstraint.
+        """
+        class UserWithUniqueConstraint(AbstractBaseUser):
+            username = models.CharField(max_length=150)
+            USERNAME_FIELD = 'username'
+
+            class Meta:
+                constraints = [
+                    UniqueConstraint(fields=['username'], name='user_username_unq'),
+                ]
+                app_label = 'auth_tests'
+
+        errors = checks.run_checks(app_configs=self.apps.get_app_configs())
+        # Before the patch, `errors` contains auth.E003, so this assertion
+        # fails. After the patch, the check is aware of UniqueConstraint,
+        # `errors` is empty, and the assertion passes.
+        self.assertEqual(errors, [])

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/contrib/auth/checks\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 auth_tests.test_user_model_unique_constraint
cat coverage.cover
git checkout ede9fac75807fe5810df66280a60e7068cc97e4a
git apply /root/pre_state.patch
