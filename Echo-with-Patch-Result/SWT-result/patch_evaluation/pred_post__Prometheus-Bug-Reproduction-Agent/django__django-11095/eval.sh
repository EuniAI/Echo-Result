#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 7d49ad76562e8c0597a0eb66046ab423b12888d8 >> /root/pre_state.patch
sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen
export LANG=en_US.UTF-8
export LANGUAGE=en_US:en
export LC_ALL=en_US.UTF-8
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 7d49ad76562e8c0597a0eb66046ab423b12888d8
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/django/contrib/admin/options.py b/django/contrib/admin/options.py
--- a/django/contrib/admin/options.py
+++ b/django/contrib/admin/options.py
@@ -327,6 +327,10 @@ def get_fieldsets(self, request, obj=None):
             return self.fieldsets
         return [(None, {'fields': self.get_fields(request, obj)})]
 
+    def get_inlines(self, request, obj):
+        """Hook for specifying custom inlines."""
+        return self.inlines
+
     def get_ordering(self, request):
         """
         Hook for specifying field ordering.
@@ -582,7 +586,7 @@ def __str__(self):
 
     def get_inline_instances(self, request, obj=None):
         inline_instances = []
-        for inline_class in self.inlines:
+        for inline_class in self.get_inlines(request, obj):
             inline = inline_class(self.model, self.admin_site)
             if request:
                 if not (inline.has_view_or_change_permission(request, obj) or

EOF_114329324912
git apply -v - <<'EOF_114329324912'
diff --git a/tests/regression/test_get_inlines_hook.py b/tests/regression/test_get_inlines_hook.py
new file mode 100644
index 0000000000..ea1f70c38a
--- /dev/null
+++ b/tests/regression/test_get_inlines_hook.py
@@ -0,0 +1,100 @@
+from django.contrib import admin
+from django.contrib.auth.models import User
+from django.db import models
+from django.test import TestCase, override_settings
+from django.urls import path, reverse
+
+# Models are defined with an app_label of an existing app ('auth')
+# to ensure they are picked up by the test runner without needing a custom AppConfig.
+class Teacher(models.Model):
+    name = models.CharField(max_length=100)
+
+    class Meta:
+        app_label = 'auth'
+        verbose_name = 'teacher'
+        verbose_name_plural = 'teachers'
+
+
+class Child(models.Model):
+    teacher = models.ForeignKey(Teacher, on_delete=models.CASCADE)
+    name = models.CharField(max_length=100)
+
+    class Meta:
+        app_label = 'auth'
+        verbose_name = 'child'
+        verbose_name_plural = 'children'
+
+
+class OtherChild(models.Model):
+    teacher = models.ForeignKey(Teacher, on_delete=models.CASCADE)
+    name = models.CharField(max_length=100)
+
+    class Meta:
+        app_label = 'auth'
+        verbose_name = 'other child'
+        verbose_name_plural = 'other children'
+
+
+# Inlines and ModelAdmin
+class ChildInline(admin.TabularInline):
+    model = Child
+
+
+class OtherChildInline(admin.TabularInline):
+    model = OtherChild
+
+
+class TeacherAdmin(admin.ModelAdmin):
+    inlines = [ChildInline, OtherChildInline]
+
+    def get_inlines(self, request, obj=None):
+        """
+        Dynamically return one inline for the add view.
+        """
+        if obj is None:
+            return [ChildInline]
+        return super().get_inlines(request, obj)
+
+
+# Test setup
+site = admin.AdminSite(name='test_admin')
+site.register(Teacher, TeacherAdmin)
+
+urlpatterns = [
+    path('admin/', site.urls),
+]
+
+
+@override_settings(
+    ROOT_URLCONF=__name__,
+    INSTALLED_APPS=[
+        'django.contrib.admin',
+        'django.contrib.auth',
+        'django.contrib.contenttypes',
+        'django.contrib.sessions',
+        'django.contrib.messages',
+    ]
+)
+class GetInlinesHookTests(TestCase):
+
+    @classmethod
+    def setUpTestData(cls):
+        cls.superuser = User.objects.create_superuser('super', 'super@example.com', 'secret')
+        cls.teacher = Teacher.objects.create(name='Mr. Harrison')
+
+    def setUp(self):
+        self.client.force_login(self.superuser)
+
+    def test_get_inlines_hook(self):
+        """
+        The get_inlines() hook should be used to determine the inlines on the add view.
+        """
+        # The URL name is derived from the model's app_label and model_name.
+        add_url = reverse('test_admin:auth_teacher_add')
+        response = self.client.get(add_url)
+
+        # On unpatched code, get_inline_instances uses `self.inlines` directly,
+        # which has 2 items. The assertion will fail (2 != 1).
+        # When patched, `get_inline_instances` calls `get_inlines`, which returns
+        # one inline for the add view, and the test will pass.
+        self.assertEqual(len(response.context['inline_admin_formsets']), 1)

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/contrib/admin/options\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 regression.test_get_inlines_hook
cat coverage.cover
git checkout 7d49ad76562e8c0597a0eb66046ab423b12888d8
git apply /root/pre_state.patch
