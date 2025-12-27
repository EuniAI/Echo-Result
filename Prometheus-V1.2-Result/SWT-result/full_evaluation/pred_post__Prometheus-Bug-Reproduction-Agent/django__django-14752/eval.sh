#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD b64db05b9cedd96905d637a2d824cbbf428e40e7 >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff b64db05b9cedd96905d637a2d824cbbf428e40e7
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/django/contrib/admin/views/autocomplete.py b/django/contrib/admin/views/autocomplete.py
--- a/django/contrib/admin/views/autocomplete.py
+++ b/django/contrib/admin/views/autocomplete.py
@@ -11,7 +11,8 @@ class AutocompleteJsonView(BaseListView):
 
     def get(self, request, *args, **kwargs):
         """
-        Return a JsonResponse with search results of the form:
+        Return a JsonResponse with search results as defined in
+        serialize_result(), by default:
         {
             results: [{id: "123" text: "foo"}],
             pagination: {more: true}
@@ -26,12 +27,19 @@ def get(self, request, *args, **kwargs):
         context = self.get_context_data()
         return JsonResponse({
             'results': [
-                {'id': str(getattr(obj, to_field_name)), 'text': str(obj)}
+                self.serialize_result(obj, to_field_name)
                 for obj in context['object_list']
             ],
             'pagination': {'more': context['page_obj'].has_next()},
         })
 
+    def serialize_result(self, obj, to_field_name):
+        """
+        Convert the provided model object to a dictionary that is added to the
+        results list.
+        """
+        return {'id': str(getattr(obj, to_field_name)), 'text': str(obj)}
+
     def get_paginator(self, *args, **kwargs):
         """Use the ModelAdmin's paginator."""
         return self.model_admin.get_paginator(self.request, *args, **kwargs)

EOF_114329324912
git apply -v - <<'EOF_114329324912'
diff --git a/tests/admin_views/test_autocomplete_extensibility.py b/tests/admin_views/test_autocomplete_extensibility.py
new file mode 100644
index 0000000000..934fb2acbd
--- /dev/null
+++ b/tests/admin_views/test_autocomplete_extensibility.py
@@ -0,0 +1,197 @@
+import json
+from contextlib import contextmanager
+
+from django.contrib import admin
+from django.contrib.admin.tests import AdminSeleniumTestCase
+from django.contrib.admin.views.autocomplete import AutocompleteJsonView
+from django.contrib.auth.models import Permission, User
+from django.contrib.contenttypes.models import ContentType
+from django.core.exceptions import PermissionDenied
+from django.http import Http404
+from django.test import RequestFactory, override_settings
+from django.urls import reverse, reverse_lazy
+
+from .admin import AnswerAdmin, QuestionAdmin
+from .models import (
+    Answer, Author, Authorship, Bonus, Book, Employee, Manager, Parent,
+    PKChild, Question, Toy, WorkHour,
+)
+from .tests import AdminViewBasicTestCase
+
+PAGINATOR_SIZE = AutocompleteJsonView.paginate_by
+
+
+class AuthorAdmin(admin.ModelAdmin):
+    ordering = ['id']
+    search_fields = ['id']
+
+
+class AuthorshipInline(admin.TabularInline):
+    model = Authorship
+    autocomplete_fields = ['author']
+
+
+class BookAdmin(admin.ModelAdmin):
+    inlines = [AuthorshipInline]
+
+
+site = admin.AdminSite(name='autocomplete_admin')
+site.register(Question, QuestionAdmin)
+site.register(Answer, AnswerAdmin)
+site.register(Author, AuthorAdmin)
+site.register(Book, BookAdmin)
+site.register(Employee, search_fields=['name'])
+site.register(WorkHour, autocomplete_fields=['employee'])
+site.register(Manager, search_fields=['name'])
+site.register(Bonus, autocomplete_fields=['recipient'])
+site.register(PKChild, search_fields=['name'])
+site.register(Toy, autocomplete_fields=['child'])
+
+
+@contextmanager
+def model_admin(model, model_admin, admin_site=site):
+    org_admin = admin_site._registry.get(model)
+    if org_admin:
+        admin_site.unregister(model)
+    admin_site.register(model, model_admin)
+    try:
+        yield
+    finally:
+        if org_admin:
+            admin_site._registry[model] = org_admin
+
+
+class AutocompleteJsonViewTests(AdminViewBasicTestCase):
+    as_view_args = {'admin_site': site}
+    opts = {
+        'app_label': Answer._meta.app_label,
+        'model_name': Answer._meta.model_name,
+        'field_name': 'question'
+    }
+    factory = RequestFactory()
+    url = reverse_lazy('autocomplete_admin:autocomplete')
+
+    @classmethod
+    def setUpTestData(cls):
+        cls.user = User.objects.create_user(
+            username='user', password='secret',
+            email='user@example.com', is_staff=True,
+        )
+        super().setUpTestData()
+
+    def test_success(self):
+        q = Question.objects.create(question='Is this a question?')
+        request = self.factory.get(self.url, {'term': 'is', **self.opts})
+        request.user = self.superuser
+        response = AutocompleteJsonView.as_view(**self.as_view_args)(request)
+        self.assertEqual(response.status_code, 200)
+        data = json.loads(response.content.decode('utf-8'))
+        self.assertEqual(data, {
+            'results': [{'id': str(q.pk), 'text': q.question}],
+            'pagination': {'more': False},
+        })
+
+    def test_custom_to_field(self):
+        q = Question.objects.create(question='Is this a question?')
+        request = self.factory.get(self.url, {'term': 'is', **self.opts, 'field_name': 'question_with_to_field'})
+        request.user = self.superuser
+        response = AutocompleteJsonView.as_view(**self.as_view_args)(request)
+        self.assertEqual(response.status_code, 200)
+        data = json.loads(response.content.decode('utf-8'))
+        self.assertEqual(data, {
+            'results': [{'id': str(q.uuid), 'text': q.question}],
+            'pagination': {'more': False},
+        })
+
+    def test_custom_to_field_permission_denied(self):
+        Question.objects.create(question='Is this a question?')
+        request = self.factory.get(self.url, {'term': 'is', **self.opts, 'field_name': 'question_with_to_field'})
+        request.user = self.user
+        with self.assertRaises(PermissionDenied):
+            AutocompleteJsonView.as_view(**self.as_view_args)(request)
+
+    def test_custom_to_field_custom_pk(self):
+        q = Question.objects.create(question='Is this a question?')
+        opts = {
+            'app_label': Question._meta.app_label,
+            'model_name': Question._meta.model_name,
+            'field_name': 'related_questions',
+        }
+        request = self.factory.get(self.url, {'term': 'is', **opts})
+        request.user = self.superuser
+        response = AutocompleteJsonView.as_view(**self.as_view_args)(request)
+        self.assertEqual(response.status_code, 200)
+        data = json.loads(response.content.decode('utf-8'))
+        self.assertEqual(data, {
+            'results': [{'id': str(q.big_id), 'text': q.question}],
+            'pagination': {'more': False},
+        })
+
+    def test_to_field_resolution_with_mti(self):
+        """
+        to_field resolution should correctly resolve for target models using
+        MTI. Tests for single and multi-level cases.
+        """
+        tests = [
+            (Employee, WorkHour, 'employee'),
+            (Manager, Bonus, 'recipient'),
+        ]
+        for Target, Remote, related_name in tests:
+            with self.subTest(target_model=Target, remote_model=Remote, related_name=related_name):
+                o = Target.objects.create(name="Frida Kahlo", gender=2, code="painter", alive=False)
+                opts = {
+                    'app_label': Remote._meta.app_label,
+                    'model_name': Remote._meta.model_name,
+                    'field_name': related_name,
+                }
+                request = self.factory.get(self.url, {'term': 'frida', **opts})
+                request.user = self.superuser
+                response = AutocompleteJsonView.as_view(**self.as_view_args)(request)
+                self.assertEqual(response.status_code, 200)
+                data = json.loads(response.content.decode('utf-8'))
+                self.assertEqual(data, {
+                    'results': [{'id': str(o.pk), 'text': o.name}],
+                    'pagination': {'more': False},
+                })
+
+    def test_to_field_resolution_with_fk_pk(self):
+        p = Parent.objects.create(name="Bertie")
+        c = PKChild.objects.create(parent=p, name="Anna")
+        opts = {
+            'app_label': Toy._meta.app_label,
+            'model_name': Toy._meta.model_name,
+            'field_name': 'child',
+        }
+        request = self.factory.get(self.url, {'term': 'anna', **opts})
+        request.user = self.superuser
+        response = AutocompleteJsonView.as_view(**self.as_view_args)(request)
+        self.assertEqual(response.status_code, 200)
+        data = json.loads(response.content.decode('utf-8'))
+        self.assertEqual(data, {
+            'results': [{'id': str(c.pk), 'text': c.name}],
+            'pagination': {'more': False},
+        })
+
+    def test_serialize_result_hook(self):
+        """
+        AutocompleteJsonView should have a `serialize_result` hook to allow
+        easy customization of the result data, as proposed in the issue.
+        """
+        class CustomAutocompleteJsonView(AutocompleteJsonView):
+            def serialize_result(self, obj, to_field_name):
+                return super().serialize_result(obj, to_field_name) | {'notes': str(obj.uuid)}
+
+        q = Question.objects.create(question='Is this a question?')
+        request = self.factory.get(self.url, {'term': 'is', **self.opts})
+        request.user = self.superuser
+        response = CustomAutocompleteJsonView.as_view(**self.as_view_args)(request)
+        self.assertEqual(response.status_code, 200)
+        data = json.loads(response.content.decode('utf-8'))
+        self.assertEqual(data, {
+            'results': [{
+                'id': str(q.pk),
+                'text': q.question,
+                'notes': str(q.uuid),
+            }],
+            'pagination': {'more': False},
+        })

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/contrib/admin/views/autocomplete\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 admin_views.test_autocomplete_extensibility
cat coverage.cover
git checkout b64db05b9cedd96905d637a2d824cbbf428e40e7
git apply /root/pre_state.patch
