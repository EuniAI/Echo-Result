#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 7f9e4524d6b23424cf44fbe1bf1f4e70f6bb066e >> /root/pre_state.patch
sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen
export LANG=en_US.UTF-8
export LANGUAGE=en_US:en
export LC_ALL=en_US.UTF-8
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 7f9e4524d6b23424cf44fbe1bf1f4e70f6bb066e
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/tests/auth_tests/test_token_generator.py b/tests/auth_tests/test_token_generator.py
new file mode 100644
index 0000000000..ec3ee5484f
--- /dev/null
+++ b/tests/auth_tests/test_token_generator.py
@@ -0,0 +1,16 @@
+from django.contrib.auth.models import User
+from django.contrib.auth.tokens import PasswordResetTokenGenerator
+from django.test import TestCase
+
+
+class TokenGeneratorTest(TestCase):
+    def test_email_change_invalidates_token(self):
+        """
+        Changing a user's email address invalidates their password reset token.
+        """
+        user = User.objects.create_user('tokentestuser', 'test@example.com', 'testpw')
+        p = PasswordResetTokenGenerator()
+        token = p.make_token(user)
+        user.email = 'test2@example.com'
+        user.save()
+        self.assertFalse(p.check_token(user, token))

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/contrib/auth/tokens\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 auth_tests.test_token_generator
cat coverage.cover
git checkout 7f9e4524d6b23424cf44fbe1bf1f4e70f6bb066e
git apply /root/pre_state.patch
