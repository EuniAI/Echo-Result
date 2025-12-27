#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 8954f255bbf5f4ee997fd6de62cb50fc9b5dd697 >> /root/pre_state.patch
sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen
export LANG=en_US.UTF-8
export LANGUAGE=en_US:en
export LC_ALL=en_US.UTF-8
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 8954f255bbf5f4ee997fd6de62cb50fc9b5dd697
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/django/views/generic/base.py b/django/views/generic/base.py
--- a/django/views/generic/base.py
+++ b/django/views/generic/base.py
@@ -11,7 +11,7 @@
 from django.urls import reverse
 from django.utils.decorators import classonlymethod
 from django.utils.deprecation import RemovedInDjango40Warning
-from django.utils.functional import SimpleLazyObject
+from django.utils.functional import lazy
 
 logger = logging.getLogger('django.request')
 
@@ -169,7 +169,6 @@ def _wrap_url_kwargs_with_deprecation_warning(url_kwargs):
     context_kwargs = {}
     for key, value in url_kwargs.items():
         # Bind into function closure.
-        @SimpleLazyObject
         def access_value(key=key, value=value):
             warnings.warn(
                 'TemplateView passing URL kwargs to the context is '
@@ -178,7 +177,7 @@ def access_value(key=key, value=value):
                 RemovedInDjango40Warning, stacklevel=2,
             )
             return value
-        context_kwargs[key] = access_value
+        context_kwargs[key] = lazy(access_value, type(value))()
     return context_kwargs
 
 

EOF_114329324912
git apply -v - <<'EOF_114329324912'
diff --git a/tests/generic_views/test_lazy_kwarg_resolution.py b/tests/generic_views/test_lazy_kwarg_resolution.py
new file mode 100644
index 0000000000..97d87a9901
--- /dev/null
+++ b/tests/generic_views/test_lazy_kwarg_resolution.py
@@ -0,0 +1,52 @@
+from django.shortcuts import get_object_or_404
+from django.test import TestCase, override_settings
+from django.urls import path
+from django.views.generic import TemplateView
+
+from .models import Author
+
+
+# This view reproduces the bug where a SimpleLazyObject from URL kwargs
+# causes a crash in the ORM.
+class OfferView(TemplateView):
+    template_name = "generic_views/author_detail.html"
+
+    def get_context_data(self, **kwargs):
+        # This implementation follows the bug report exactly. It does not call
+        # super() and builds the context from scratch. This avoids any
+        # unrelated code paths that could mask the bug.
+        offer_slug = kwargs.get("offer_slug", "")
+        offer = get_object_or_404(Author, slug=offer_slug)
+        return {"offer": offer, "offer_slug": offer_slug}
+
+
+# Local URLconf for this test case.
+urlpatterns = [
+    path(
+        "offers/<slug:offer_slug>/",
+        OfferView.as_view(),
+        name="offer_view",
+    ),
+]
+
+
+@override_settings(ROOT_URLCONF=__name__)
+class TemplateViewLazyKwargResolutionTest(TestCase):
+    @classmethod
+    def setUpTestData(cls):
+        # Use the Author model as a stand-in for the Account model from the
+        # bug report, as it has the necessary 'slug' field.
+        cls.author = Author.objects.create(name="Test Offer", slug="test-offer-slug")
+
+    def test_lazy_kwarg_in_get_context_data_orm_lookup(self):
+        """
+        Tests that a lazy object from a URL kwarg is resolved before being
+        used in a database query.
+        """
+        # This request should fail with a database error if the SimpleLazyObject
+        # from the URL is not resolved to a string before the ORM query.
+        # In the test environment, this may present as a DeprecationWarning
+        # being raised as an exception. A 200 response indicates the underlying
+        # bug has been fixed.
+        response = self.client.get("/offers/test-offer-slug/")
+        self.assertEqual(response.status_code, 200)

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/views/generic/base\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 generic_views.test_lazy_kwarg_resolution
cat coverage.cover
git checkout 8954f255bbf5f4ee997fd6de62cb50fc9b5dd697
git apply /root/pre_state.patch
