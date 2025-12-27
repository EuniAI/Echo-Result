#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD c2678e49759e5c4c329bff0eeca2886267005d21 >> /root/pre_state.patch
sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen
export LANG=en_US.UTF-8
export LANGUAGE=en_US:en
export LC_ALL=en_US.UTF-8
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff c2678e49759e5c4c329bff0eeca2886267005d21
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/tests/auth_tests/test_ticket_32847.py b/tests/auth_tests/test_ticket_32847.py
new file mode 100644
index 0000000000..0c3b35447b
--- /dev/null
+++ b/tests/auth_tests/test_ticket_32847.py
@@ -0,0 +1,14 @@
+from django.contrib.auth.models import User
+from django.test import TestCase
+
+
+class Ticket32847Tests(TestCase):
+    def test_check_password_for_user_with_unusable_password(self):
+        """
+        check_password() should return False for a user with an unusable
+        password.
+        """
+        user = User.objects.create_user(username='test_user')
+        user.set_unusable_password()
+        user.save()
+        self.assertFalse(user.check_password('password'))

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/db/models/base\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 auth_tests.test_ticket_32847
cat coverage.cover
git checkout c2678e49759e5c4c329bff0eeca2886267005d21
git apply /root/pre_state.patch
