#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 6866c91b638de5368c18713fa851bfe56253ea55 >> /root/pre_state.patch
sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen
export LANG=en_US.UTF-8
export LANGUAGE=en_US:en
export LC_ALL=en_US.UTF-8
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 6866c91b638de5368c18713fa851bfe56253ea55
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/tests/db/models/test_constraints.py b/tests/db/models/test_constraints.py
new file mode 100644
index 0000000000..62d875fbd9
--- /dev/null
+++ b/tests/db/models/test_constraints.py
@@ -0,0 +1,219 @@
+from django.core.exceptions import ValidationError
+from django.db import IntegrityError, connection, models
+from django.db.models import Q
+from django.db.models.constraints import BaseConstraint
+from django.test import (
+    SimpleTestCase, TestCase, TransactionTestCase, skipUnlessDBFeature,
+)
+
+from .models import Product
+
+
+def get_constraints(table):
+    with connection.cursor() as cursor:
+        return connection.introspection.get_constraints(cursor, table)
+
+
+class BaseConstraintTests(SimpleTestCase):
+    def test_constraint_sql(self):
+        c = BaseConstraint('name')
+        msg = 'This method must be implemented by a subclass.'
+        with self.assertRaisesMessage(NotImplementedError, msg):
+            c.constraint_sql(None, None)
+
+    def test_create_sql(self):
+        c = BaseConstraint('name')
+        msg = 'This method must be implemented by a subclass.'
+        with self.assertRaisesMessage(NotImplementedError, msg):
+            c.create_sql(None, None)
+
+    def test_remove_sql(self):
+        c = BaseConstraint('name')
+        msg = 'This method must be implemented by a subclass.'
+        with self.assertRaisesMessage(NotImplementedError, msg):
+            c.remove_sql(None, None)
+
+
+class CheckConstraintTests(TestCase):
+    def test_eq(self):
+        check1 = models.Q(price__gt=models.F('discounted_price'))
+        check2 = models.Q(price__lt=models.F('discounted_price'))
+        self.assertEqual(
+            models.CheckConstraint(check=check1, name='price'),
+            models.CheckConstraint(check=check1, name='price'),
+        )
+        self.assertNotEqual(
+            models.CheckConstraint(check=check1, name='price'),
+            models.CheckConstraint(check=check1, name='price2'),
+        )
+        self.assertNotEqual(
+            models.CheckConstraint(check=check1, name='price'),
+            models.CheckConstraint(check=check2, name='price'),
+        )
+        self.assertNotEqual(models.CheckConstraint(check=check1, name='price'), 1)
+
+    def test_repr(self):
+        check = models.Q(price__gt=models.F('discounted_price'))
+        name = 'price_gt_discounted_price'
+        constraint = models.CheckConstraint(check=check, name=name)
+        self.assertEqual(
+            repr(constraint),
+            "<CheckConstraint: check='{}' name='{}'>".format(check, name),
+        )
+
+    def test_deconstruction(self):
+        check = models.Q(price__gt=models.F('discounted_price'))
+        name = 'price_gt_discounted_price'
+        constraint = models.CheckConstraint(check=check, name=name)
+        path, args, kwargs = constraint.deconstruct()
+        self.assertEqual(path, 'django.db.models.CheckConstraint')
+        self.assertEqual(args, ())
+        self.assertEqual(kwargs, {'check': check, 'name': name})
+
+    @skipUnlessDBFeature('supports_table_check_constraints')
+    def test_database_constraint(self):
+        Product.objects.create(name='Valid', price=10, discounted_price=5)
+        with self.assertRaises(IntegrityError):
+            Product.objects.create(name='Invalid', price=10, discounted_price=20)
+
+    @skipUnlessDBFeature('supports_table_check_constraints')
+    def test_name(self):
+        constraints = get_constraints(Product._meta.db_table)
+        expected_name = 'price_gt_discounted_price'
+        self.assertIn(expected_name, constraints)
+
+
+class CheckConstraintOROperatorTests(TransactionTestCase):
+    available_apps = ['constraints']
+
+    @skipUnlessDBFeature('supports_table_check_constraints')
+    def test_check_constraint_or_operator_sql(self):
+        class TestModel(models.Model):
+            field_1 = models.IntegerField(blank=True, null=True)
+            flag = models.BooleanField()
+
+            class Meta:
+                app_label = 'constraints'
+                managed = False
+
+        constraint = models.CheckConstraint(
+            check=models.Q(flag=True, field_1__isnull=False) | models.Q(flag=False),
+            name='field_1_has_value_if_flag_set',
+        )
+
+        with connection.schema_editor() as editor:
+            constraint_sql = constraint.constraint_sql(TestModel, editor)
+
+        self.assertNotIn(
+            '"%s"' % TestModel._meta.db_table,
+            constraint_sql,
+        )
+
+
+class UniqueConstraintTests(TestCase):
+    @classmethod
+    def setUpTestData(cls):
+        cls.p1, cls.p2 = Product.objects.bulk_create([
+            Product(name='p1', color='red'),
+            Product(name='p2'),
+        ])
+
+    def test_eq(self):
+        self.assertEqual(
+            models.UniqueConstraint(fields=['foo', 'bar'], name='unique'),
+            models.UniqueConstraint(fields=['foo', 'bar'], name='unique'),
+        )
+        self.assertNotEqual(
+            models.UniqueConstraint(fields=['foo', 'bar'], name='unique'),
+            models.UniqueConstraint(fields=['foo', 'bar'], name='unique2'),
+        )
+        self.assertNotEqual(
+            models.UniqueConstraint(fields=['foo', 'bar'], name='unique'),
+            models.UniqueConstraint(fields=['foo', 'baz'], name='unique'),
+        )
+        self.assertNotEqual(models.UniqueConstraint(fields=['foo', 'bar'], name='unique'), 1)
+
+    def test_eq_with_condition(self):
+        self.assertEqual(
+            models.UniqueConstraint(
+                fields=['foo', 'bar'], name='unique',
+                condition=models.Q(foo=models.F('bar'))
+            ),
+            models.UniqueConstraint(
+                fields=['foo', 'bar'], name='unique',
+                condition=models.Q(foo=models.F('bar'))),
+        )
+        self.assertNotEqual(
+            models.UniqueConstraint(
+                fields=['foo', 'bar'],
+                name='unique',
+                condition=models.Q(foo=models.F('bar'))
+            ),
+            models.UniqueConstraint(
+                fields=['foo', 'bar'],
+                name='unique',
+                condition=models.Q(foo=models.F('baz'))
+            ),
+        )
+
+    def test_repr(self):
+        fields = ['foo', 'bar']
+        name = 'unique_fields'
+        constraint = models.UniqueConstraint(fields=fields, name=name)
+        self.assertEqual(
+            repr(constraint),
+            "<UniqueConstraint: fields=('foo', 'bar') name='unique_fields'>",
+        )
+
+    def test_repr_with_condition(self):
+        constraint = models.UniqueConstraint(
+            fields=['foo', 'bar'],
+            name='unique_fields',
+            condition=models.Q(foo=models.F('bar')),
+        )
+        self.assertEqual(
+            repr(constraint),
+            "<UniqueConstraint: fields=('foo', 'bar') name='unique_fields' "
+            "condition=(AND: ('foo', F(bar)))>",
+        )
+
+    def test_deconstruction(self):
+        fields = ['foo', 'bar']
+        name = 'unique_fields'
+        constraint = models.UniqueConstraint(fields=fields, name=name)
+        path, args, kwargs = constraint.deconstruct()
+        self.assertEqual(path, 'django.db.models.UniqueConstraint')
+        self.assertEqual(args, ())
+        self.assertEqual(kwargs, {'fields': tuple(fields), 'name': name})
+
+    def test_deconstruction_with_condition(self):
+        fields = ['foo', 'bar']
+        name = 'unique_fields'
+        condition = models.Q(foo=models.F('bar'))
+        constraint = models.UniqueConstraint(fields=fields, name=name, condition=condition)
+        path, args, kwargs = constraint.deconstruct()
+        self.assertEqual(path, 'django.db.models.UniqueConstraint')
+        self.assertEqual(args, ())
+        self.assertEqual(kwargs, {'fields': tuple(fields), 'name': name, 'condition': condition})
+
+    def test_database_constraint(self):
+        with self.assertRaises(IntegrityError):
+            Product.objects.create(name=self.p1.name, color=self.p1.color)
+
+    def test_model_validation(self):
+        with self.assertRaisesMessage(ValidationError, 'Product with this Name and Color already exists.'):
+            Product(name=self.p1.name, color=self.p1.color).validate_unique()
+
+    def test_model_validation_with_condition(self):
+        """Partial unique constraints are ignored by Model.validate_unique()."""
+        Product(name=self.p1.name, color='blue').validate_unique()
+        Product(name=self.p2.name).validate_unique()
+
+    def test_name(self):
+        constraints = get_constraints(Product._meta.db_table)
+        expected_name = 'name_color_uniq'
+        self.assertIn(expected_name, constraints)
+
+    def test_condition_must_be_q(self):
+        with self.assertRaisesMessage(ValueError, 'UniqueConstraint.condition must be a Q instance.'):
+            models.UniqueConstraint(name='uniq', fields=['name'], condition='invalid')

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/db/models/sql/query\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 db.models.test_constraints
cat coverage.cover
git checkout 6866c91b638de5368c18713fa851bfe56253ea55
git apply /root/pre_state.patch
