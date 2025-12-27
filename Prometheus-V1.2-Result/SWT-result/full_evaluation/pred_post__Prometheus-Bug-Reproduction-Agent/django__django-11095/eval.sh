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
diff --git a/tests/admin_inlines/test_get_inlines_hook.py b/tests/admin_inlines/test_get_inlines_hook.py
new file mode 100644
index 0000000000..b5552fcbf4
--- /dev/null
+++ b/tests/admin_inlines/test_get_inlines_hook.py
@@ -0,0 +1,51 @@
+from django.contrib import admin
+from django.contrib.auth.models import User
+from django.test import TestCase, override_settings
+from django.urls import reverse
+
+from .admin import site as admin_site
+from .models import Holder4, Inner4Stacked, Inner4Tabular
+
+
+@override_settings(ROOT_URLCONF='admin_inlines.urls')
+class GetInlinesHookTest(TestCase):
+
+    @classmethod
+    def setUpTestData(cls):
+        cls.superuser = User.objects.create_superuser('super', 'super@example.com', 'password')
+
+    def setUp(self):
+        self.client.force_login(self.superuser)
+
+    def test_get_inlines_hook(self):
+        """
+        ModelAdmin.get_inlines() can be used to dynamically specify inlines.
+        """
+        class Inner4StackedInline(admin.StackedInline):
+            model = Inner4Stacked
+
+        class Inner4TabularInline(admin.TabularInline):
+            model = Inner4Tabular
+
+        class DynamicInlinesHolder4Admin(admin.ModelAdmin):
+            inlines = [Inner4TabularInline]
+
+            def get_inlines(self, request, obj=None):
+                if obj and obj.dummy > 10:
+                    return [Inner4StackedInline]
+                return self.inlines
+
+        original_admin = admin_site._registry[Holder4]
+        admin_site.unregister(Holder4)
+        admin_site.register(Holder4, DynamicInlinesHolder4Admin)
+
+        try:
+            # When dummy > 10, the stacked inline should be used.
+            holder = Holder4.objects.create(dummy=20)
+            response = self.client.get(reverse('admin:admin_inlines_holder4_change', args=(holder.pk,)))
+            self.assertContains(response, 'id="inner4stacked_set-group"')
+            self.assertNotContains(response, 'id="inner4tabular_set-group"')
+        finally:
+            # Restore original ModelAdmin.
+            admin_site.unregister(Holder4)
+            admin_site.register(Holder4, original_admin)

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/contrib/admin/options\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 admin_inlines.test_get_inlines_hook
cat coverage.cover
git checkout 7d49ad76562e8c0597a0eb66046ab423b12888d8
git apply /root/pre_state.patch
