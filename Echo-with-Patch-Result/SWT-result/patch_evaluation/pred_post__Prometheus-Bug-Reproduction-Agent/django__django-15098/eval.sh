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
diff --git a/tests/i18n/test_i18n_patterns.py b/tests/i18n/test_i18n_patterns.py
new file mode 100644
index 0000000000..2f54df1158
--- /dev/null
+++ b/tests/i18n/test_i18n_patterns.py
@@ -0,0 +1,42 @@
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
+from django.urls import clear_url_caches, reverse, translate_url, path
+from django.utils import translation
+from django.conf.urls.i18n import i18n_patterns
+
+# This setup is self-contained and mirrors the bug report.
+def bangiah(request):
+    return HttpResponse('U!')
+
+urlpatterns = i18n_patterns(
+    path('', bangiah),
+)
+
+@override_settings(
+    ROOT_URLCONF=__name__,
+    LANGUAGES=[
+        ('en-us', "English"),
+        ('en-latn-us', "Latin English"),
+        ('en-Latn-US', "BCP 47 case format"),
+    ],
+    LANGUAGE_CODE='en-us',
+    MIDDLEWARE=[
+        'django.middleware.locale.LocaleMiddleware',
+        'django.middleware.common.CommonMiddleware',
+    ]
+)
+class LocaleWithScriptAndRegionTests(SimpleTestCase):
+    def test_url_with_script_and_region(self):
+        """
+        i18n_patterns must support language codes with script and region tags.
+        """
+        response = self.client.get('/en-latn-us/')
+        self.assertEqual(response.status_code, 200)

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/utils/translation/trans_real\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 i18n.test_i18n_patterns
cat coverage.cover
git checkout 2c7846d992ca512d36a73f518205015c88ed088c
git apply /root/pre_state.patch
