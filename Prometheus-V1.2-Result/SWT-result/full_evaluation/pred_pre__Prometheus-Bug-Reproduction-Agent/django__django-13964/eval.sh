#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD f39634ff229887bf7790c069d0c411b38494ca38 >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff f39634ff229887bf7790c069d0c411b38494ca38
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/tests/model_fields/test_foreignkey_regress.py b/tests/model_fields/test_foreignkey_regress.py
new file mode 100644
index 0000000000..212d146893
--- /dev/null
+++ b/tests/model_fields/test_foreignkey_regress.py
@@ -0,0 +1,159 @@
+from decimal import Decimal
+
+from django.apps import apps
+from django.core import checks
+from django.core.exceptions import FieldError
+from django.db import models, transaction
+from django.test import TestCase, skipIfDBFeature
+from django.test.utils import isolate_apps
+
+from .models import Bar, FkToChar, Foo, PrimaryKeyCharModel
+
+
+class ForeignKeyTests(TestCase):
+
+    def test_callable_default(self):
+        """A lazy callable may be used for ForeignKey.default."""
+        a = Foo.objects.create(id=1, a='abc', d=Decimal('12.34'))
+        b = Bar.objects.create(b='bcd')
+        self.assertEqual(b.a, a)
+
+    @skipIfDBFeature('interprets_empty_strings_as_nulls')
+    def test_empty_string_fk(self):
+        """
+        Empty strings foreign key values don't get converted to None (#19299).
+        """
+        char_model_empty = PrimaryKeyCharModel.objects.create(string='')
+        fk_model_empty = FkToChar.objects.create(out=char_model_empty)
+        fk_model_empty = FkToChar.objects.select_related('out').get(id=fk_model_empty.pk)
+        self.assertEqual(fk_model_empty.out, char_model_empty)
+
+    def test_fk_to_char_pk_late_assignment(self):
+        with transaction.atomic():
+            order = FkToChar()
+            product = PrimaryKeyCharModel()
+            order.out = product
+            product.string = 'foo'
+            product.save()
+            order.save()
+            self.assertTrue(FkToChar.objects.filter(out=product).exists())
+
+    @isolate_apps('model_fields')
+    def test_warning_when_unique_true_on_fk(self):
+        class Foo(models.Model):
+            pass
+
+        class FKUniqueTrue(models.Model):
+            fk_field = models.ForeignKey(Foo, models.CASCADE, unique=True)
+
+        model = FKUniqueTrue()
+        expected_warnings = [
+            checks.Warning(
+                'Setting unique=True on a ForeignKey has the same effect as using a OneToOneField.',
+                hint='ForeignKey(unique=True) is usually better served by a OneToOneField.',
+                obj=FKUniqueTrue.fk_field.field,
+                id='fields.W342',
+            )
+        ]
+        warnings = model.check()
+        self.assertEqual(warnings, expected_warnings)
+
+    def test_related_name_converted_to_text(self):
+        rel_name = Bar._meta.get_field('a').remote_field.related_name
+        self.assertIsInstance(rel_name, str)
+
+    def test_abstract_model_pending_operations(self):
+        """
+        Foreign key fields declared on abstract models should not add lazy
+        relations to resolve relationship declared as string (#24215).
+        """
+        pending_ops_before = list(apps._pending_operations.items())
+
+        class AbstractForeignKeyModel(models.Model):
+            fk = models.ForeignKey('missing.FK', models.CASCADE)
+
+            class Meta:
+                abstract = True
+
+        self.assertIs(AbstractForeignKeyModel._meta.apps, apps)
+        self.assertEqual(
+            pending_ops_before,
+            list(apps._pending_operations.items()),
+            'Pending lookup added for a foreign key on an abstract model'
+        )
+
+    @isolate_apps('model_fields', 'model_fields.tests')
+    def test_abstract_model_app_relative_foreign_key(self):
+        class AbstractReferent(models.Model):
+            reference = models.ForeignKey('Referred', on_delete=models.CASCADE)
+
+            class Meta:
+                app_label = 'model_fields'
+                abstract = True
+
+        def assert_app_model_resolved(label):
+            class Referred(models.Model):
+                class Meta:
+                    app_label = label
+
+            class ConcreteReferent(AbstractReferent):
+                class Meta:
+                    app_label = label
+
+            self.assertEqual(ConcreteReferent._meta.get_field('reference').related_model, Referred)
+
+        assert_app_model_resolved('model_fields')
+        assert_app_model_resolved('tests')
+
+    @isolate_apps('model_fields')
+    def test_to_python(self):
+        class Foo(models.Model):
+            pass
+
+        class Bar(models.Model):
+            fk = models.ForeignKey(Foo, models.CASCADE)
+
+        self.assertEqual(Bar._meta.get_field('fk').to_python('1'), 1)
+
+    @isolate_apps('model_fields')
+    def test_fk_to_fk_get_col_output_field(self):
+        class Foo(models.Model):
+            pass
+
+        class Bar(models.Model):
+            foo = models.ForeignKey(Foo, models.CASCADE, primary_key=True)
+
+        class Baz(models.Model):
+            bar = models.ForeignKey(Bar, models.CASCADE, primary_key=True)
+
+        col = Baz._meta.get_field('bar').get_col('alias')
+        self.assertIs(col.output_field, Foo._meta.pk)
+
+    @isolate_apps('model_fields')
+    def test_recursive_fks_get_col(self):
+        class Foo(models.Model):
+            bar = models.ForeignKey('Bar', models.CASCADE, primary_key=True)
+
+        class Bar(models.Model):
+            foo = models.ForeignKey(Foo, models.CASCADE, primary_key=True)
+
+        with self.assertRaisesMessage(ValueError, 'Cannot resolve output_field'):
+            Foo._meta.get_field('bar').get_col('alias')
+
+    @isolate_apps('model_fields')
+    def test_non_local_to_field(self):
+        class Parent(models.Model):
+            key = models.IntegerField(unique=True)
+
+        class Child(Parent):
+            pass
+
+        class Related(models.Model):
+            child = models.ForeignKey(Child, on_delete=models.CASCADE, to_field='key')
+
+        msg = (
+            "'model_fields.Related.child' refers to field 'key' which is not "
+            "local to model 'model_fields.Child'."
+        )
+        with self.assertRaisesMessage(FieldError, msg):
+            Related._meta.get_field('child').related_fields

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/db/models/base\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 model_fields.test_foreignkey_regress
cat coverage.cover
git checkout f39634ff229887bf7790c069d0c411b38494ca38
git apply /root/pre_state.patch
