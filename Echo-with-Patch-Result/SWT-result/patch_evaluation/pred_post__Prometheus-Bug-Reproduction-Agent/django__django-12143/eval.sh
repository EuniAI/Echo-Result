#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 5573a54d409bb98b5c5acdb308310bed02d392c2 >> /root/pre_state.patch
sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen
export LANG=en_US.UTF-8
export LANGUAGE=en_US:en
export LC_ALL=en_US.UTF-8
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 5573a54d409bb98b5c5acdb308310bed02d392c2
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/django/contrib/admin/options.py b/django/contrib/admin/options.py
--- a/django/contrib/admin/options.py
+++ b/django/contrib/admin/options.py
@@ -1631,7 +1631,9 @@ def change_view(self, request, object_id, form_url='', extra_context=None):
 
     def _get_edited_object_pks(self, request, prefix):
         """Return POST data values of list_editable primary keys."""
-        pk_pattern = re.compile(r'{}-\d+-{}$'.format(prefix, self.model._meta.pk.name))
+        pk_pattern = re.compile(
+            r'{}-\d+-{}$'.format(re.escape(prefix), self.model._meta.pk.name)
+        )
         return [value for key, value in request.POST.items() if pk_pattern.match(key)]
 
     def _get_list_editable_queryset(self, request, prefix):

EOF_114329324912
git apply -v - <<'EOF_114329324912'
diff --git a/tests/test_model_admin_regex.py b/tests/test_model_admin_regex.py
new file mode 100644
index 0000000000..0ada93c744
--- /dev/null
+++ b/tests/test_model_admin_regex.py
@@ -0,0 +1,52 @@
+import datetime
+
+from django.contrib.admin.options import ModelAdmin
+from django.contrib.admin.sites import AdminSite
+from django.test import TestCase
+
+from .models import Band
+
+
+class MockRequest:
+    """A mock request class to simulate a POST request."""
+    def __init__(self, POST=None):
+        self.POST = POST or {}
+
+
+class ModelAdminRegexTest(TestCase):
+    """Tests for regex handling in ModelAdmin."""
+
+    @classmethod
+    def setUpTestData(cls):
+        """Set up a Band object and an AdminSite instance for the tests."""
+        # Provide values for all required fields to avoid IntegrityError.
+        cls.band = Band.objects.create(
+            name='The Bug',
+            bio='A test band.',
+            sign_date=datetime.date(2020, 1, 1)
+        )
+        cls.site = AdminSite()
+
+    def test_get_edited_object_pks_special_chars_in_prefix(self):
+        """
+        _get_edited_object_pks() should escape the prefix passed to re.compile(),
+        so that special regex characters in a formset prefix don't break it.
+        """
+        ma = ModelAdmin(Band, self.site)
+        # A prefix with a regex special character ('+').
+        prefix_with_special_chars = 'band+members'
+        pk_name = Band._meta.pk.name
+        pk_value = str(self.band.pk)
+
+        # Simulate POST data from a formset where the key contains the prefix.
+        post_data = {
+            '%s-0-%s' % (prefix_with_special_chars, pk_name): pk_value
+        }
+        request = MockRequest(POST=post_data)
+
+        edited_pks = ma._get_edited_object_pks(request, prefix_with_special_chars)
+
+        # Before the fix, the unescaped '+' in the regex causes the match to
+        # fail, returning an empty list. After the fix, the prefix is escaped,
+        # the match succeeds, and the list contains the pk.
+        self.assertEqual(edited_pks, [pk_value])

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/contrib/admin/options\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 test_model_admin_regex
cat coverage.cover
git checkout 5573a54d409bb98b5c5acdb308310bed02d392c2
git apply /root/pre_state.patch
