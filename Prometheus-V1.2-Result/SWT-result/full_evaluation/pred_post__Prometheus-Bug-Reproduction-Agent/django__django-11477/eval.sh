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
diff --git a/tests/i18n/patterns/test_optional_args.py b/tests/i18n/patterns/test_optional_args.py
new file mode 100644
index 0000000000..4dbf136384
--- /dev/null
+++ b/tests/i18n/patterns/test_optional_args.py
@@ -0,0 +1,80 @@
+import os
+
+from django.conf import settings
+from django.conf.urls.i18n import i18n_patterns
+from django.core.exceptions import ImproperlyConfigured
+from django.http import HttpResponsePermanentRedirect
+from django.middleware.locale import LocaleMiddleware
+from django.template import Context, Template
+from django.test import SimpleTestCase, override_settings
+from django.test.client import RequestFactory
+from django.test.utils import override_script_prefix
+from django.urls import clear_url_caches, re_path, reverse, translate_url
+from django.utils import translation
+from django.views.generic import TemplateView
+
+
+class PermanentRedirectLocaleMiddleWare(LocaleMiddleware):
+    response_redirect_class = HttpResponsePermanentRedirect
+
+
+@override_settings(
+    USE_I18N=True,
+    LOCALE_PATHS=[
+        os.path.join(os.path.dirname(__file__), 'locale'),
+    ],
+    LANGUAGE_CODE='en-us',
+    LANGUAGES=[
+        ('nl', 'Dutch'),
+        ('en', 'English'),
+        ('pt-br', 'Brazilian Portuguese'),
+    ],
+    MIDDLEWARE=[
+        'django.middleware.locale.LocaleMiddleware',
+        'django.middleware.common.CommonMiddleware',
+    ],
+    ROOT_URLCONF='i18n.patterns.urls.default',
+    TEMPLATES=[{
+        'BACKEND': 'django.template.backends.django.DjangoTemplates',
+        'DIRS': [os.path.join(os.path.dirname(__file__), 'templates')],
+        'OPTIONS': {
+            'context_processors': [
+                'django.template.context_processors.i18n',
+            ],
+        },
+    }],
+)
+class URLTestCaseBase(SimpleTestCase):
+    """
+    TestCase base-class for the URL tests.
+    """
+
+    def setUp(self):
+        # Make sure the cache is empty before we are doing our tests.
+        clear_url_caches()
+
+    def tearDown(self):
+        # Make sure we will leave an empty cache for other testcases.
+        clear_url_caches()
+
+
+class OptionalArgumentI18nTest(URLTestCaseBase):
+    """
+    Tests translation of URLs with optional parameters.
+    """
+    class urls:
+        view = TemplateView.as_view(template_name='dummy.html')
+        urlpatterns = i18n_patterns(
+            re_path(r'^optional-arg/(?:(?P<arg>\w+)/)?$', view, name='optional-arg'),
+        )
+
+    @override_settings(ROOT_URLCONF=urls)
+    def test_translate_url_with_missing_optional_arg(self):
+        """
+        translate_url() should correctly handle URLs with missing optional
+        named groups.
+        """
+        url = '/en/optional-arg/'
+        with translation.override('en'):
+            translated_url = translate_url(url, 'nl')
+        self.assertEqual(translated_url, '/nl/optional-arg/')

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/urls/resolvers\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 i18n.patterns.test_optional_args
cat coverage.cover
git checkout e28671187903e6aca2428374fdd504fca3032aee
git apply /root/pre_state.patch
