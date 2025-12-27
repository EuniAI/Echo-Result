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
diff --git a/tests/auth_tests/test_user_model_checks.py b/tests/auth_tests/test_user_model_checks.py
new file mode 100644
index 0000000000..da5d553f82
--- /dev/null
+++ b/tests/auth_tests/test_user_model_checks.py
@@ -0,0 +1,29 @@
+from django.contrib.auth.checks import check_user_model
+from django.contrib.auth.models import AbstractBaseUser
+from django.core import checks
+from django.db import models
+from django.test import SimpleTestCase, override_settings
+from django.test.utils import isolate_apps, override_system_checks
+
+
+@isolate_apps('auth_tests', attr_name='apps')
+@override_system_checks([check_user_model])
+class UserModelChecksTests(SimpleTestCase):
+    @override_settings(AUTH_USER_MODEL='auth_tests.UserWithUniqueConstraint')
+    def test_username_unique_constraint(self):
+        """
+        auth.E003 should not be raised when USERNAME_FIELD is covered by a
+        UniqueConstraint.
+        """
+        class UserWithUniqueConstraint(AbstractBaseUser):
+            username = models.CharField(max_length=30)
+            USERNAME_FIELD = 'username'
+
+            class Meta:
+                constraints = [
+                    models.UniqueConstraint(fields=['username'], name='user_username_unq'),
+                ]
+                app_label = 'auth_tests'
+
+        errors = checks.run_checks(app_configs=self.apps.get_app_configs())
+        self.assertEqual(errors, [])

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/contrib/auth/checks\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 auth_tests.test_user_model_checks
cat coverage.cover
git checkout ede9fac75807fe5810df66280a60e7068cc97e4a
git apply /root/pre_state.patch
