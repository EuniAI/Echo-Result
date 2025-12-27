#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 2c7846d992ca512d36a73f518205015c88ed088c >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 2c7846d992ca512d36a73f518205015c88ed088c
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/django/utils/translation/trans_real.py b/django/utils/translation/trans_real.py
--- a/django/utils/translation/trans_real.py
+++ b/django/utils/translation/trans_real.py
@@ -43,7 +43,7 @@
     re.IGNORECASE
 )
 
-language_code_prefix_re = _lazy_re_compile(r'^/(\w+([@-]\w+)?)(/|$)')
+language_code_prefix_re = _lazy_re_compile(r'^/(\w+([@-]\w+){0,2})(/|$)')
 
 
 @receiver(setting_changed)

EOF_114329324912
git apply -v - <<'EOF_114329324912'
diff --git a/tests/i18n/patterns/test_bcp47_language_code.py b/tests/i18n/patterns/test_bcp47_language_code.py
new file mode 100644
index 0000000000..b85a3aa30b
--- /dev/null
+++ b/tests/i18n/patterns/test_bcp47_language_code.py
@@ -0,0 +1,74 @@
+import os
+
+from django.conf import settings
+from django.core.exceptions import ImproperlyConfigured
+from django.http import HttpResponse, HttpResponsePermanentRedirect
+from django.middleware.locale import LocaleMiddleware
+from django.template import Context, Template
+from django.test import SimpleTestCase, override_settings
+from django.test.client import RequestFactory
+from django.test.utils import override_script_prefix
+from django.urls import clear_url_caches, reverse, translate_url
+from django.utils import translation
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
+@override_settings(
+    LANGUAGES=[
+        ('en-us', 'English'),
+        ('en-latn-us', 'Latin English'),
+        ('en-Latn-US', 'BCP 47 case format'),
+    ],
+    ROOT_URLCONF='i18n.patterns.urls.default',
+)
+class LanguageCodeWithScriptAndRegionTests(URLTestCaseBase):
+    """
+    Tests that language codes with script and region are correctly handled.
+    """
+    def test_language_code_with_script_and_region(self):
+        """
+        A language code including a script and a region should be matched.
+        """
+        response = self.client.get('/en-latn-us/prefixed/')
+        self.assertEqual(response.status_code, 200)
+        response = self.client.get('/en-Latn-US/prefixed/')
+        self.assertEqual(response.status_code, 200)

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/utils/translation/trans_real\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 i18n.patterns.test_bcp47_language_code
cat coverage.cover
git checkout 2c7846d992ca512d36a73f518205015c88ed088c
git apply /root/pre_state.patch
