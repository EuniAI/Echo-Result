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
diff --git a/tests/test_readonly_fk_custom_admin.py b/tests/test_readonly_fk_custom_admin.py
new file mode 100644
index 0000000000..35c313165e
--- /dev/null
+++ b/tests/test_readonly_fk_custom_admin.py
@@ -0,0 +1,120 @@
+from django.contrib import admin
+from django.contrib.auth.models import User
+from django.db import models
+from django.test import TestCase, override_settings
+from django.urls import path, reverse
+
+# Models for test. Using 'auth' as app_label to ensure models are created
+# by the test runner without needing a separate app.
+class Book(models.Model):
+    name = models.CharField(max_length=100)
+
+    class Meta:
+        app_label = 'auth'
+
+    def __str__(self):
+        return self.name
+
+class Chapter(models.Model):
+    title = models.CharField(max_length=100)
+    book = models.ForeignKey(Book, on_delete=models.CASCADE)
+
+    class Meta:
+        app_label = 'auth'
+
+    def __str__(self):
+        return self.title
+
+class ReadOnlyFKModel(models.Model):
+    chapter = models.ForeignKey(Chapter, on_delete=models.CASCADE)
+    name = models.CharField(max_length=100)
+
+    class Meta:
+        app_label = 'auth'
+        verbose_name = 'Read-only FK Model'
+
+
+# Admin classes for the models
+class BookAdmin(admin.ModelAdmin):
+    pass
+
+class ChapterAdmin(admin.ModelAdmin):
+    pass
+
+class ReadOnlyFKModelAdmin(admin.ModelAdmin):
+    readonly_fields = ('chapter',)
+
+
+# A custom admin site is instantiated to test namespaced URLs.
+custom_admin_site = admin.AdminSite(name='custom_admin')
+
+# Models are registered with both the default admin.site AND the custom_admin_site.
+# This is crucial for reproducing the bug, as the incorrect URL resolution
+# happens when both sites are active.
+admin.site.register(Book, BookAdmin)
+admin.site.register(Chapter, ChapterAdmin)
+admin.site.register(ReadOnlyFKModel, ReadOnlyFKModelAdmin)
+
+custom_admin_site.register(Book, BookAdmin)
+custom_admin_site.register(Chapter, ChapterAdmin)
+custom_admin_site.register(ReadOnlyFKModel, ReadOnlyFKModelAdmin)
+
+
+# The test URLconf includes both the default and the custom admin sites.
+urlpatterns = [
+    path('admin/', admin.site.urls),
+    path('custom_admin/', custom_admin_site.urls),
+]
+
+
+@override_settings(
+    ROOT_URLCONF=__name__,
+    # Add required apps for the admin and our models (which are in 'auth' app)
+    INSTALLED_APPS=(
+        'django.contrib.auth',
+        'django.contrib.contenttypes',
+        'django.contrib.sessions',
+        'django.contrib.messages',
+        'django.contrib.admin',
+    ),
+)
+class ReadonlyURLTests(TestCase):
+    """
+    Tests for readonly field URL generation in a custom AdminSite.
+    """
+    @classmethod
+    def setUpTestData(cls):
+        cls.superuser = User.objects.create_superuser('super', 'super@example.com', 'password')
+        cls.book = Book.objects.create(name='Test Book')
+        cls.chapter = Chapter.objects.create(title='Test Chapter', book=cls.book)
+        cls.readonly_instance = ReadOnlyFKModel.objects.create(
+            name='Test Readonly',
+            chapter=cls.chapter
+        )
+
+    def test_readonly_fk_link_in_custom_admin(self):
+        """
+        A readonly foreign key field on a custom admin site should link to the
+        change view on the same site, not the default one.
+        """
+        self.client.force_login(self.superuser)
+        # Access the change page on the custom admin site.
+        url = reverse(
+            'custom_admin:auth_readonlyfkmodel_change',
+            args=(self.readonly_instance.pk,)
+        )
+        response = self.client.get(url)
+
+        # This is the URL that *should* be generated for the readonly field.
+        correct_url = reverse(
+            'custom_admin:auth_chapter_change',
+            args=(self.chapter.pk,)
+        )
+
+        # This assertion should fail because the bug causes the URL to be
+        # generated for the 'admin' namespace instead of 'custom_admin'.
+        self.assertContains(
+            response,
+            f'<a href="{correct_url}">{self.chapter}</a>',
+            html=True
+        )

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/contrib/admin/helpers\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 test_readonly_fk_custom_admin
cat coverage.cover
git checkout 475cffd1d64c690cdad16ede4d5e81985738ceb4
git apply /root/pre_state.patch
