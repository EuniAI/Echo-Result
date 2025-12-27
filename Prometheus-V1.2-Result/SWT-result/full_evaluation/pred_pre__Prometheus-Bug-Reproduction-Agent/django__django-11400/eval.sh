#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 1f8382d34d54061eddc41df6994e20ee38c60907 >> /root/pre_state.patch
sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen
export LANG=en_US.UTF-8
export LANGUAGE=en_US:en
export LC_ALL=en_US.UTF-8
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 1f8382d34d54061eddc41df6994e20ee38c60907
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/tests/admin_filters/test_related_field_ordering.py b/tests/admin_filters/test_related_field_ordering.py
new file mode 100644
index 0000000000..fa1db6a81b
--- /dev/null
+++ b/tests/admin_filters/test_related_field_ordering.py
@@ -0,0 +1,103 @@
+from django.contrib import admin
+from django.contrib.admin.filters import RelatedOnlyFieldListFilter
+from django.contrib.admin.sites import AdminSite
+from django.contrib.auth.models import User
+from django.db import models
+from django.test import RequestFactory, TestCase
+
+
+# Models defined locally for a self-contained test case.
+class Band(models.Model):
+    name = models.CharField(max_length=100)
+    rank = models.IntegerField()
+
+    class Meta:
+        ordering = ('name',)
+        app_label = 'admin_filters'
+
+    def __str__(self):
+        return self.name
+
+
+class Song(models.Model):
+    name = models.CharField(max_length=100)
+    band = models.ForeignKey(Band, on_delete=models.CASCADE)
+
+    class Meta:
+        app_label = 'admin_filters'
+
+    def __str__(self):
+        return self.name
+
+
+class RelatedFieldFilterOrderingTest(TestCase):
+    request_factory = RequestFactory()
+
+    @classmethod
+    def setUpTestData(cls):
+        cls.superuser = User.objects.create_superuser('super', 'super@example.com', 'password')
+        # Create bands in an order that is different from their alphabetical
+        # and rank ordering to ensure the test isn't passing by chance.
+        cls.band_zz = Band.objects.create(name='ZZ Top', rank=2)
+        cls.band_acdc = Band.objects.create(name='AC/DC', rank=1)
+        # Songs are needed for RelatedOnlyFieldListFilter to populate choices.
+        Song.objects.create(name='La Grange', band=cls.band_zz)
+        Song.objects.create(name='Thunderstruck', band=cls.band_acdc)
+
+    def test_relatedfieldlistfilter_fallback_to_meta_ordering(self):
+        """
+        RelatedFieldListFilter should fall back to the ordering defined in the
+        related model's Meta.ordering.
+        """
+        class SongAdmin(admin.ModelAdmin):
+            list_filter = ['band']
+
+        class BandAdmin(admin.ModelAdmin):
+            # No ordering is specified, so Meta.ordering should be used.
+            pass
+
+        site = AdminSite()
+        site.register(Band, BandAdmin)
+        site.register(Song, SongAdmin)
+
+        request = self.request_factory.get('/')
+        request.user = self.superuser
+        modeladmin = site._registry[Song]
+        changelist = modeladmin.get_changelist_instance(request)
+
+        band_filter = changelist.get_filters(request)[0][0]
+        choices = list(band_filter.choices(changelist))
+
+        # Choices should be ordered by Band.name: 'AC/DC', then 'ZZ Top'.
+        # The bug would likely order by PK, resulting in 'ZZ Top' first.
+        # choices[0] is 'All'.
+        self.assertEqual(choices[1]['display'], 'AC/DC')
+
+    def test_relatedonlyfieldlistfilter_uses_admin_ordering(self):
+        """
+        RelatedOnlyFieldListFilter should use the ordering from the related
+        model's ModelAdmin.
+        """
+        class SongAdmin(admin.ModelAdmin):
+            list_filter = [('band', RelatedOnlyFieldListFilter)]
+
+        class BandAdmin(admin.ModelAdmin):
+            ordering = ['rank']
+
+        site = AdminSite()
+        site.register(Band, BandAdmin)
+        site.register(Song, SongAdmin)
+
+        request = self.request_factory.get('/')
+        request.user = self.superuser
+        modeladmin = site._registry[Song]
+        changelist = modeladmin.get_changelist_instance(request)
+
+        band_filter = changelist.get_filters(request)[0][0]
+        choices = list(band_filter.choices(changelist))
+
+        # Choices should be ordered by BandAdmin.ordering ('rank'): 'AC/DC',
+        # then 'ZZ Top'. The bug means ordering is ignored, likely falling
+        # back to PK, which would be 'ZZ Top' first.
+        # choices[0] is 'All'.
+        self.assertEqual(choices[1]['display'], 'AC/DC')

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/contrib/admin/filters\.py|django/db/models/fields/__init__\.py|django/db/models/fields/reverse_related\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 admin_filters.test_related_field_ordering
cat coverage.cover
git checkout 1f8382d34d54061eddc41df6994e20ee38c60907
git apply /root/pre_state.patch
