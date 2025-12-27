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
diff --git a/tests/test_m2m_user_creation_form.py b/tests/test_m2m_user_creation_form.py
new file mode 100644
index 0000000000..c60f888a34
--- /dev/null
+++ b/tests/test_m2m_user_creation_form.py
@@ -0,0 +1,80 @@
+from django import forms
+from django.contrib.auth.forms import UserCreationForm
+from django.contrib.auth.models import AbstractUser, Group, Permission
+from django.db import models
+from django.test import TestCase, override_settings
+
+
+# Models required for the test
+class Organization(models.Model):
+    name = models.CharField(max_length=255)
+
+    class Meta:
+        app_label = "auth"
+
+    def __str__(self):
+        return self.name
+
+
+class CustomUserWithM2M(AbstractUser):
+    # Redefine groups and user_permissions to avoid clashes with the default
+    # User model when running tests.
+    groups = models.ManyToManyField(
+        Group,
+        verbose_name="groups",
+        blank=True,
+        help_text=(
+            "The groups this user belongs to. A user will get all permissions "
+            "granted to each of their groups."
+        ),
+        related_name="customuserwithm2m_set",
+        related_query_name="user",
+    )
+    user_permissions = models.ManyToManyField(
+        Permission,
+        verbose_name="user permissions",
+        blank=True,
+        help_text="Specific permissions for this user.",
+        related_name="customuserwithm2m_permissions_set",
+        related_query_name="user",
+    )
+    orgs = models.ManyToManyField(Organization, blank=True)
+
+    class Meta:
+        app_label = "auth"
+
+
+# The custom UserCreationForm for the custom user model
+class M2MUserCreationForm(UserCreationForm):
+    class Meta(UserCreationForm.Meta):
+        model = CustomUserWithM2M
+        fields = ("username", "orgs")
+
+
+@override_settings(AUTH_USER_MODEL="auth.CustomUserWithM2M")
+class UserCreationFormM2MTest(TestCase):
+    """
+    Tests for UserCreationForm with ManyToManyFields.
+    """
+
+    @classmethod
+    def setUpTestData(cls):
+        cls.org1 = Organization.objects.create(name="Organization 1")
+        cls.org2 = Organization.objects.create(name="Organization 2")
+
+    def test_user_creation_with_m2m_save(self):
+        """
+        A custom UserCreationForm with a ManyToManyField should save the
+        m2m data when the form is saved.
+        """
+        data = {
+            "username": "newuser",
+            "password1": "password123",
+            "password2": "password123",
+            "orgs": [self.org1.pk, self.org2.pk],
+        }
+        form = M2MUserCreationForm(data)
+        self.assertTrue(form.is_valid(), form.errors)
+        user = form.save()
+        # The m2m relations should be saved. This fails if save_m2m() isn't called.
+        self.assertCountEqual(user.orgs.all(), [self.org1, self.org2])

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/contrib/auth/forms\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 test_m2m_user_creation_form
cat coverage.cover
git checkout 60a7bd89860e504c0c33b02c78edcac87f6d1b5a
git apply /root/pre_state.patch
