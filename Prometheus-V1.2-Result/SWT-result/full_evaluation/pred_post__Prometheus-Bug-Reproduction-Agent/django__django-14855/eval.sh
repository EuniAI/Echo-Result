#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 475cffd1d64c690cdad16ede4d5e81985738ceb4 >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 475cffd1d64c690cdad16ede4d5e81985738ceb4
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/django/contrib/admin/helpers.py b/django/contrib/admin/helpers.py
--- a/django/contrib/admin/helpers.py
+++ b/django/contrib/admin/helpers.py
@@ -209,7 +209,11 @@ def get_admin_url(self, remote_field, remote_obj):
             remote_field.model._meta.model_name,
         )
         try:
-            url = reverse(url_name, args=[quote(remote_obj.pk)])
+            url = reverse(
+                url_name,
+                args=[quote(remote_obj.pk)],
+                current_app=self.model_admin.admin_site.name,
+            )
             return format_html('<a href="{}">{}</a>', url, remote_obj)
         except NoReverseMatch:
             return str(remote_obj)

EOF_114329324912
git apply -v - <<'EOF_114329324912'
diff --git a/tests/admin_views/test_readonly_foreign_key.py b/tests/admin_views/test_readonly_foreign_key.py
new file mode 100644
index 0000000000..ed7d7a2297
--- /dev/null
+++ b/tests/admin_views/test_readonly_foreign_key.py
@@ -0,0 +1,63 @@
+import admin_views.models
+from django.contrib import admin
+from django.contrib.auth.models import User
+from django.test import TestCase, override_settings
+from django.urls import path, reverse
+
+# Models are defined in admin_views.models, so we can import them.
+from admin_views.models import Child, Parent
+
+
+# 1. A custom ModelAdmin that makes the ForeignKey readonly.
+class ChildAdmin(admin.ModelAdmin):
+    readonly_fields = ('parent',)
+
+
+# 2. A custom AdminSite instance.
+custom_admin_site = admin.AdminSite(name='custom_admin')
+custom_admin_site.register(Parent)
+custom_admin_site.register(Child, ChildAdmin)
+
+
+# 3. URL patterns for the test, including the custom and default admin sites.
+# This module will be used as the ROOT_URLCONF.
+urlpatterns = [
+    path('custom_admin/', custom_admin_site.urls),
+    path('admin/', admin.site.urls),
+]
+
+
+# 4. The test class, pointing ROOT_URLCONF to this module.
+# The path is based on the file's location in the project structure.
+@override_settings(ROOT_URLCONF='admin_views.test_readonly_foreign_key')
+class ReadonlyForeignKeyInCustomAdminTest(TestCase):
+    @classmethod
+    def setUpTestData(cls):
+        # Create a user and model instances needed for the test.
+        cls.superuser = User.objects.create_superuser('super', 'super@example.com', 'password')
+        cls.parent_obj = Parent.objects.create(name='Test Parent')
+        cls.child_obj = Child.objects.create(parent=cls.parent_obj, name='Test Child')
+
+    def test_readonly_foreign_key_url_in_custom_admin(self):
+        """
+        The link for a readonly ForeignKey field in a custom admin site should
+        use the custom site's URL, not the default admin's URL.
+        """
+        self.client.login(username='super', password='password')
+
+        # URL for the change view of the 'Child' object in our custom admin.
+        child_change_url = reverse('custom_admin:admin_views_child_change', args=[self.child_obj.pk])
+        response = self.client.get(child_change_url)
+
+        # The expected URL for the link to the related 'Parent' object.
+        # It should be resolved within the 'custom_admin' namespace.
+        expected_parent_url = reverse('custom_admin:admin_views_parent_change', args=[self.parent_obj.pk])
+
+        # This assertion will fail if the bug is present because the generated
+        # href will point to '/admin/...' instead of '/custom_admin/...'.
+        self.assertContains(
+            response,
+            f'<a href="{expected_parent_url}">{self.parent_obj.name}</a>',
+            html=True,
+            msg_prefix="The readonly field link does not point to the custom admin URL.",
+        )

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/contrib/admin/helpers\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 admin_views.test_readonly_foreign_key
cat coverage.cover
git checkout 475cffd1d64c690cdad16ede4d5e81985738ceb4
git apply /root/pre_state.patch
