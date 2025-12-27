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
diff --git a/django/contrib/auth/forms.py b/django/contrib/auth/forms.py
--- a/django/contrib/auth/forms.py
+++ b/django/contrib/auth/forms.py
@@ -163,7 +163,9 @@ def __init__(self, *args, **kwargs):
         super().__init__(*args, **kwargs)
         password = self.fields.get("password")
         if password:
-            password.help_text = password.help_text.format("../password/")
+            password.help_text = password.help_text.format(
+                f"../../{self.instance.pk}/password/"
+            )
         user_permissions = self.fields.get("user_permissions")
         if user_permissions:
             user_permissions.queryset = user_permissions.queryset.select_related(

EOF_114329324912
git apply -v - <<'EOF_114329324912'
diff --git a/tests/test_to_field_password_link.py b/tests/test_to_field_password_link.py
new file mode 100644
index 0000000000..480976bd0d
--- /dev/null
+++ b/tests/test_to_field_password_link.py
@@ -0,0 +1,33 @@
+import uuid
+
+from django.contrib.auth.forms import UserChangeForm
+from django.contrib.auth.models import User
+from django.test import TestCase
+
+
+class ToFieldPasswordLinkTests(TestCase):
+    """
+    Tests for the password change link in the UserChangeForm.
+    """
+
+    def test_password_help_text_link(self):
+        """
+        The password change link in UserChangeForm should use the user's PK
+        to create a robust relative link, ensuring it works correctly even when
+        the User admin is accessed via a URL containing a `to_field` value.
+        """
+        # Create a user instance for the form.
+        user = User.objects.create_user(username="testuser", password="password")
+
+        # Instantiate the form, which will trigger the __init__ logic.
+        form = UserChangeForm(instance=user)
+        password_help_text = form.fields["password"].help_text
+
+        # The corrected link should be relative to the app's admin URL,
+        # using the user's primary key to build the correct path.
+        # This format is "../../<pk>/password/".
+        expected_href = f'href="../../{user.pk}/password/"'
+
+        # This assertion fails with the old code, which generates a static
+        # 'href="../password/"', and passes with the corrected code.
+        self.assertIn(expected_href, password_help_text)

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/contrib/auth/forms\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 test_to_field_password_link
cat coverage.cover
git checkout d559cb02da30f74debbb1fc3a46de0df134d2d80
git apply /root/pre_state.patch
