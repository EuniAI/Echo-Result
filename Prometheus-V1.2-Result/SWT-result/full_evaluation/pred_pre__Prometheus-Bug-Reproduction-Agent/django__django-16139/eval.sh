#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD d559cb02da30f74debbb1fc3a46de0df134d2d80 >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff d559cb02da30f74debbb1fc3a46de0df134d2d80
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/tests/auth_tests/test_password_change_link.py b/tests/auth_tests/test_password_change_link.py
new file mode 100644
index 0000000000..0d9cf49162
--- /dev/null
+++ b/tests/auth_tests/test_password_change_link.py
@@ -0,0 +1,59 @@
+from unittest import mock
+
+from django.contrib import admin
+from django.contrib.admin.options import TO_FIELD_VAR
+from django.contrib.auth.admin import UserAdmin
+from django.contrib.auth.models import User
+from django.db import models
+from django.test import TestCase
+from django.urls import reverse
+
+
+# A model that refers to User via a non-PK `to_field` to make the admin
+# validation pass. It needs to be defined at the module level for the test
+# runner to create its DB table.
+class UserReferrer(models.Model):
+    user = models.ForeignKey(User, on_delete=models.CASCADE, to_field="username")
+
+    class Meta:
+        # Place the model in an app that's part of the test environment.
+        app_label = "auth"
+
+
+class UserReferrerAdmin(admin.ModelAdmin):
+    pass
+
+
+class UserAdminPasswordLinkTest(TestCase):
+    @classmethod
+    def setUpTestData(cls):
+        cls.superuser = User.objects.create_superuser(
+            "super", "super@example.com", "password"
+        )
+        cls.user_to_edit = User.objects.create_user(
+            "testuser", "test@example.com", "password"
+        )
+
+    def setUp(self):
+        self.client.login(username="super", password="password")
+        # Register a dummy model admin that refers to User via `to_field`
+        # to satisfy the admin's security check.
+        admin.site.register(UserReferrer, UserReferrerAdmin)
+        self.addCleanup(admin.site.unregister, UserReferrer)
+
+    def test_password_change_link_with_to_field(self):
+        """
+        The password change link on the user change form is correct when the
+        user is accessed via a `to_field` URL.
+        """
+        change_url = reverse("admin:auth_user_change", args=[self.user_to_edit.username])
+        response = self.client.get(f"{change_url}?{TO_FIELD_VAR}=username")
+
+        self.assertEqual(response.status_code, 200)
+
+        # The password help text contains the link. With the bug, the href is
+        # "../password/", which resolves incorrectly relative to a to_field URL.
+        # The fix changes it to `../../<pk>/password/`. We assert the correct
+        # link is present, which will fail until the bug is fixed.
+        expected_link = f'<a href="../../{self.user_to_edit.pk}/password/">this form</a>'
+        self.assertContains(response, expected_link)

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/contrib/auth/forms\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 auth_tests.test_password_change_link
cat coverage.cover
git checkout d559cb02da30f74debbb1fc3a46de0df134d2d80
git apply /root/pre_state.patch
