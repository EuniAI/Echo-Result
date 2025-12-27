#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 7af8f4127397279d19ef7c7899e93018274e2f9b >> /root/pre_state.patch
sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen
export LANG=en_US.UTF-8
export LANGUAGE=en_US:en
export LC_ALL=en_US.UTF-8
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 7af8f4127397279d19ef7c7899e93018274e2f9b
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/django/db/models/sql/query.py b/django/db/models/sql/query.py
--- a/django/db/models/sql/query.py
+++ b/django/db/models/sql/query.py
@@ -305,6 +305,7 @@ def clone(self):
             obj.annotation_select_mask = None
         else:
             obj.annotation_select_mask = self.annotation_select_mask.copy()
+        obj.combined_queries = tuple(query.clone() for query in self.combined_queries)
         # _annotation_select_cache cannot be copied, as doing so breaks the
         # (necessary) state in which both annotations and
         # _annotation_select_cache point to the same underlying objects.
@@ -1777,6 +1778,8 @@ def split_exclude(self, filter_expr, can_reuse, names_with_path):
 
     def set_empty(self):
         self.where.add(NothingNode(), AND)
+        for query in self.combined_queries:
+            query.set_empty()
 
     def is_empty(self):
         return any(isinstance(c, NothingNode) for c in self.where.children)

EOF_114329324912
git apply -v - <<'EOF_114329324912'
diff --git a/tests/model_forms/test_modelmultiplechoicefield.py b/tests/model_forms/test_modelmultiplechoicefield.py
new file mode 100644
index 0000000000..35f7c0827b
--- /dev/null
+++ b/tests/model_forms/test_modelmultiplechoicefield.py
@@ -0,0 +1,39 @@
+import datetime
+from django import forms
+from django.test import TestCase, skipUnlessDBFeature
+from .models import Article, Category, Writer
+
+
+class ModelFormValidationTests(TestCase):
+
+    @skipUnlessDBFeature('supports_select_union')
+    def test_model_multiple_choice_field_union_empty_submission(self):
+        """
+        A ModelMultipleChoiceField using a union() queryset should not add all
+        objects when the form is submitted with the field empty.
+        """
+        writer = Writer.objects.create(name='Test Writer')
+        c1 = Category.objects.create(name='cat1', slug='c1', url='u1')
+        Category.objects.create(name='cat2', slug='c2', url='u2')
+        c3 = Category.objects.create(name='cat3', slug='c3', url='u3')
+
+        class ArticleForm(forms.ModelForm):
+            categories = forms.ModelMultipleChoiceField(
+                Category.objects.filter(pk=c1.pk).union(Category.objects.filter(pk=c3.pk)),
+                required=False,
+            )
+
+            class Meta:
+                model = Article
+                fields = ['headline', 'slug', 'pub_date', 'writer', 'categories']
+
+        form_data = {
+            'headline': 'Test',
+            'slug': 'test',
+            'pub_date': datetime.date(2023, 1, 1),
+            'writer': writer.pk,
+        }
+        form = ArticleForm(form_data)
+        self.assertTrue(form.is_valid())
+        article_instance = form.save()
+        self.assertEqual(article_instance.categories.count(), 0)

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/db/models/sql/query\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 model_forms.test_modelmultiplechoicefield
cat coverage.cover
git checkout 7af8f4127397279d19ef7c7899e93018274e2f9b
git apply /root/pre_state.patch
