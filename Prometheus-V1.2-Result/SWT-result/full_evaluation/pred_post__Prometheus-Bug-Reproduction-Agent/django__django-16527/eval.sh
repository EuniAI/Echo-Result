#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD bd366ca2aeffa869b7dbc0b0aa01caea75e6dc31 >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff bd366ca2aeffa869b7dbc0b0aa01caea75e6dc31
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/django/contrib/admin/templatetags/admin_modify.py b/django/contrib/admin/templatetags/admin_modify.py
--- a/django/contrib/admin/templatetags/admin_modify.py
+++ b/django/contrib/admin/templatetags/admin_modify.py
@@ -100,7 +100,7 @@ def submit_row(context):
                 and context.get("show_delete", True)
             ),
             "show_save_as_new": not is_popup
-            and has_change_permission
+            and has_add_permission
             and change
             and save_as,
             "show_save_and_add_another": can_save_and_add_another,

EOF_114329324912
git apply -v - <<'EOF_114329324912'
diff --git a/tests/admin_views/test_permissions.py b/tests/admin_views/test_permissions.py
new file mode 100644
index 0000000000..18438084d1
--- /dev/null
+++ b/tests/admin_views/test_permissions.py
@@ -0,0 +1,65 @@
+from django.contrib.auth import get_permission_codename
+from django.contrib.auth.models import Permission, User
+from django.contrib.contenttypes.models import ContentType
+from django.test import TestCase, override_settings
+from django.urls import reverse
+
+from .models import Person
+
+
+def get_perm(model, codename):
+    """
+    Return the Permission object for a given model and codename.
+    """
+    return Permission.objects.get(
+        content_type=ContentType.objects.get_for_model(model),
+        codename=codename,
+    )
+
+
+@override_settings(
+    ROOT_URLCONF="admin_views.urls",
+    TEMPLATES=[
+        {
+            "BACKEND": "django.template.backends.django.DjangoTemplates",
+            "APP_DIRS": True,
+            "OPTIONS": {
+                "context_processors": [
+                    "django.template.context_processors.request",
+                    "django.contrib.auth.context_processors.auth",
+                    "django.contrib.messages.context_processors.messages",
+                ],
+            },
+        }
+    ],
+)
+class AdminViewPermissionsTest(TestCase):
+    @classmethod
+    def setUpTestData(cls):
+        """
+        Set up a user with change permission but no add permission.
+        """
+        cls.changeuser = User.objects.create_user(
+            username="changeuser", password="secret", is_staff=True
+        )
+        # Grant change permission for Person model, which has save_as=True.
+        cls.changeuser.user_permissions.add(
+            get_perm(Person, get_permission_codename("change", Person._meta))
+        )
+        cls.person = Person.objects.create(name="test person")
+
+    def test_save_as_new_requires_add_permission(self):
+        """
+        The "Save as new" button is not displayed if the user doesn't have
+        add permission.
+        """
+        self.client.force_login(self.changeuser)
+        # The PersonAdmin has `save_as = True`, so the button would normally
+        # be shown if permissions were not an issue.
+        url = reverse("admin:admin_views_person_change", args=(self.person.pk,))
+        response = self.client.get(url)
+
+        self.assertEqual(response.status_code, 200)
+        # This assertion fails because of the bug. "Save as new" is an add
+        # operation, so it should not be available without add permission.
+        self.assertFalse(response.context["show_save_as_new"])

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/contrib/admin/templatetags/admin_modify\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 admin_views.test_permissions
cat coverage.cover
git checkout bd366ca2aeffa869b7dbc0b0aa01caea75e6dc31
git apply /root/pre_state.patch
