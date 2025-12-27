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
diff --git a/tests/auth_tests/test_token_invalidation.py b/tests/auth_tests/test_token_invalidation.py
new file mode 100644
index 0000000000..b10bc65570
--- /dev/null
+++ b/tests/auth_tests/test_token_invalidation.py
@@ -0,0 +1,36 @@
+from django.contrib.auth.models import User
+from django.contrib.auth.tokens import PasswordResetTokenGenerator
+from django.test import TestCase
+
+
+class PasswordTokenGeneratorTest(TestCase):
+
+    def test_token_invalidated_by_email_change(self):
+        """
+        Tests that a password reset token is invalidated when the user's email
+        is changed.
+        """
+        user = User.objects.create_user('tokentestuser', 'test@example.com', 'testpw')
+        p = PasswordResetTokenGenerator()
+        
+        # First, confirm that a token is invalidated by a password change.
+        token_for_password_test = p.make_token(user)
+        user.set_password('new-password')
+        user.save()
+        self.assertFalse(p.check_token(user, token_for_password_test))
+
+        # Now, test the email change invalidation.
+        # Reset password to original state and create a new token.
+        user.set_password('testpw')
+        user.save()
+        token_for_email_test = p.make_token(user)
+
+        # Change email and save.
+        user.email = 'test2@example.com'
+        user.save()
+
+        # Re-fetch the user to ensure the state is updated from the database.
+        updated_user = User.objects.get(pk=user.pk)
+
+        # The token should now be invalid. This is the assertion for the bug.
+        self.assertFalse(p.check_token(updated_user, token_for_email_test))

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/contrib/auth/tokens\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 auth_tests.test_token_invalidation
cat coverage.cover
git checkout 7f9e4524d6b23424cf44fbe1bf1f4e70f6bb066e
git apply /root/pre_state.patch
