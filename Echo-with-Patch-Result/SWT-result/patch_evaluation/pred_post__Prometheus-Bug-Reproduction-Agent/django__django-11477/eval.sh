#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD e28671187903e6aca2428374fdd504fca3032aee >> /root/pre_state.patch
sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen
export LANG=en_US.UTF-8
export LANGUAGE=en_US:en
export LC_ALL=en_US.UTF-8
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff e28671187903e6aca2428374fdd504fca3032aee
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/django/urls/resolvers.py b/django/urls/resolvers.py
--- a/django/urls/resolvers.py
+++ b/django/urls/resolvers.py
@@ -153,7 +153,7 @@ def match(self, path):
             # If there are any named groups, use those as kwargs, ignoring
             # non-named groups. Otherwise, pass all non-named arguments as
             # positional arguments.
-            kwargs = match.groupdict()
+            kwargs = {k: v for k, v in match.groupdict().items() if v is not None}
             args = () if kwargs else match.groups()
             return path[match.end():], args, kwargs
         return None

EOF_114329324912
git apply -v - <<'EOF_114329324912'
diff --git a/tests/test_translate_url_optional_param.py b/tests/test_translate_url_optional_param.py
new file mode 100644
index 0000000000..4f656b05ab
--- /dev/null
+++ b/tests/test_translate_url_optional_param.py
@@ -0,0 +1,44 @@
+from types import ModuleType
+
+from django.conf.urls.i18n import i18n_patterns
+from django.http import HttpResponse
+from django.test import SimpleTestCase, override_settings
+from django.urls import clear_url_caches, re_path, translate_url
+from django.utils import translation
+
+
+@override_settings(
+    USE_I18N=True,
+    LANGUAGES=[
+        ('nl', 'Dutch'),
+        ('en', 'English'),
+    ],
+    LANGUAGE_CODE='en',
+)
+class TranslateURLOptionalParamTests(SimpleTestCase):
+    def setUp(self):
+        clear_url_caches()
+
+    def tearDown(self):
+        clear_url_caches()
+
+    def test_translate_url_with_optional_parameter(self):
+        """
+        translate_url() should work with an optional parameter that is not
+        present in the URL.
+        """
+        def view(request, **kwargs):
+            return HttpResponse()
+
+        urlpatterns = i18n_patterns(
+            re_path(r'^items(?:/(?P<optional_arg>\w+))?/$', view, name='items_optional'),
+        )
+        # A ROOT_URLCONF needs to be a module, so we create a fake one.
+        test_urls = ModuleType('test_urls')
+        test_urls.urlpatterns = urlpatterns
+
+        with self.settings(ROOT_URLCONF=test_urls):
+            with translation.override('en'):
+                url = '/en/items/'
+                translated_url = translate_url(url, 'nl')
+                self.assertEqual(translated_url, '/nl/items/')

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/urls/resolvers\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 test_translate_url_optional_param
cat coverage.cover
git checkout e28671187903e6aca2428374fdd504fca3032aee
git apply /root/pre_state.patch
