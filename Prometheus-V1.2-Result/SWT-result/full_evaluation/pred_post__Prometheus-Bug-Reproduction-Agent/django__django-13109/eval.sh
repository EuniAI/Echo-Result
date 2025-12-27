#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD fbe82f82555bc25dccb476c749ca062f0b522be3 >> /root/pre_state.patch
sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen
export LANG=en_US.UTF-8
export LANGUAGE=en_US:en
export LC_ALL=en_US.UTF-8
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff fbe82f82555bc25dccb476c749ca062f0b522be3
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/django/db/models/fields/related.py b/django/db/models/fields/related.py
--- a/django/db/models/fields/related.py
+++ b/django/db/models/fields/related.py
@@ -914,7 +914,7 @@ def validate(self, value, model_instance):
             return
 
         using = router.db_for_read(self.remote_field.model, instance=model_instance)
-        qs = self.remote_field.model._default_manager.using(using).filter(
+        qs = self.remote_field.model._base_manager.using(using).filter(
             **{self.remote_field.field_name: value}
         )
         qs = qs.complex_filter(self.get_limit_choices_to())

EOF_114329324912
git apply -v - <<'EOF_114329324912'
diff --git a/tests/custom_managers/test_foreignkey_validation.py b/tests/custom_managers/test_foreignkey_validation.py
new file mode 100644
index 0000000000..1c5cf3f2d5
--- /dev/null
+++ b/tests/custom_managers/test_foreignkey_validation.py
@@ -0,0 +1,52 @@
+from django import forms
+from django.db import models
+from django.test import TestCase
+
+
+class ArticleManager(models.Manager):
+    def get_queryset(self):
+        return super().get_queryset().filter(archived=False)
+
+
+class Article(models.Model):
+    title = models.CharField(max_length=100)
+    archived = models.BooleanField(default=False)
+
+    objects = ArticleManager()
+    base_manager = models.Manager()
+
+    class Meta:
+        app_label = 'custom_managers'
+
+
+class FavoriteArticle(models.Model):
+    article = models.ForeignKey(Article, on_delete=models.CASCADE)
+
+    class Meta:
+        app_label = 'custom_managers'
+
+
+class FavoriteArticleForm(forms.ModelForm):
+    class Meta:
+        model = FavoriteArticle
+        fields = '__all__'
+
+    def __init__(self, *args, **kwargs):
+        super().__init__(*args, **kwargs)
+        # Use the base manager to allow archived articles.
+        self.fields['article'].queryset = Article.base_manager.all()
+
+
+class ForeignKeyValidationTests(TestCase):
+    def test_foreignkey_validation_uses_base_manager(self):
+        """
+        ForeignKey.validate() should use the model's base manager instead of
+        the default manager.
+        """
+        archived_article = Article.objects.create(title='Archived', archived=True)
+        data = {'article': archived_article.pk}
+        form = FavoriteArticleForm(data)
+        # This fails because ForeignKey.validate() uses Article.objects (the
+        # default manager) and doesn't find the archived article. The fix is
+        # to use the base manager for validation.
+        self.assertTrue(form.is_valid())

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/db/models/fields/related\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 custom_managers.test_foreignkey_validation
cat coverage.cover
git checkout fbe82f82555bc25dccb476c749ca062f0b522be3
git apply /root/pre_state.patch
