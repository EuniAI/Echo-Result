#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 60a7bd89860e504c0c33b02c78edcac87f6d1b5a >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 60a7bd89860e504c0c33b02c78edcac87f6d1b5a
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/django/contrib/auth/forms.py b/django/contrib/auth/forms.py
--- a/django/contrib/auth/forms.py
+++ b/django/contrib/auth/forms.py
@@ -141,6 +141,8 @@ def save(self, commit=True):
         user.set_password(self.cleaned_data["password1"])
         if commit:
             user.save()
+            if hasattr(self, "save_m2m"):
+                self.save_m2m()
         return user
 
 

EOF_114329324912
git apply -v - <<'EOF_114329324912'
diff --git a/tests/auth_tests/test_forms_m2m.py b/tests/auth_tests/test_forms_m2m.py
new file mode 100644
index 0000000000..72390adb5d
--- /dev/null
+++ b/tests/auth_tests/test_forms_m2m.py
@@ -0,0 +1,51 @@
+from django.contrib.auth.forms import UserCreationForm
+from django.test import TestCase
+from django.test.utils import override_settings
+
+# Import the existing models from the test suite's model definitions
+# to avoid the model conflict error.
+from auth_tests.models.with_many_to_many import CustomUserWithM2M, Organization
+
+
+class CustomUserWithM2MCreationForm(UserCreationForm):
+    """
+    A custom UserCreationForm for the CustomUserWithM2M model that includes
+    the 'orgs' ManyToManyField.
+    """
+
+    class Meta(UserCreationForm.Meta):
+        model = CustomUserWithM2M
+        fields = ("username", "orgs")
+
+
+@override_settings(AUTH_USER_MODEL="auth_tests.CustomUserWithM2M")
+class UserCreationFormM2MTest(TestCase):
+    @classmethod
+    def setUpTestData(cls):
+        # Create some organizations to be used in the m2m relationship.
+        cls.org1 = Organization.objects.create(name="Django Software Foundation")
+        cls.org2 = Organization.objects.create(name="Jazzband")
+
+    def test_user_creation_form_does_not_save_m2m_field(self):
+        """
+        Test that UserCreationForm fails to save ManyToManyField data.
+
+        This test will fail with an AssertionError because form.save() does not
+        call save_m2m(), but it will pass once the bug is fixed.
+        """
+        data = {
+            "username": "testuser",
+            "password1": "password",
+            "password2": "password",
+            "orgs": [self.org1.pk, self.org2.pk],
+        }
+        form = CustomUserWithM2MCreationForm(data)
+        self.assertTrue(form.is_valid())
+        user = form.save()
+
+        # The user object must be reloaded from the database to get the
+        # up-to-date m2m fields.
+        user.refresh_from_db()
+
+        # This assertion will fail because the 'orgs' will be empty.
+        self.assertCountEqual(user.orgs.all(), [self.org1, self.org2])

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/contrib/auth/forms\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 auth_tests.test_forms_m2m
cat coverage.cover
git checkout 60a7bd89860e504c0c33b02c78edcac87f6d1b5a
git apply /root/pre_state.patch
