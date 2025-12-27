#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD bf47c719719d0e190a99fa2e7f959d5bbb7caf8a >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff bf47c719719d0e190a99fa2e7f959d5bbb7caf8a
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/tests/expressions/test_expression_operators.py b/tests/expressions/test_expression_operators.py
new file mode 100644
index 0000000000..57e1655b68
--- /dev/null
+++ b/tests/expressions/test_expression_operators.py
@@ -0,0 +1,283 @@
+import datetime
+import pickle
+import unittest
+import uuid
+from collections import namedtuple
+from copy import deepcopy
+from decimal import Decimal
+from unittest import mock
+
+from django.core.exceptions import FieldError
+from django.db import DatabaseError, NotSupportedError, connection
+from django.db.models import (
+    AutoField,
+    Avg,
+    BinaryField,
+    BooleanField,
+    Case,
+    CharField,
+    Count,
+    DateField,
+    DateTimeField,
+    DecimalField,
+    DurationField,
+    Exists,
+    Expression,
+    ExpressionList,
+    ExpressionWrapper,
+    F,
+    FloatField,
+    Func,
+    IntegerField,
+    Max,
+    Min,
+    Model,
+    OrderBy,
+    OuterRef,
+    Q,
+    StdDev,
+    Subquery,
+    Sum,
+    TimeField,
+    UUIDField,
+    Value,
+    Variance,
+    When,
+)
+from django.db.models.expressions import (
+    Col,
+    Combinable,
+    CombinedExpression,
+    RawSQL,
+    Ref,
+)
+from django.db.models.functions import (
+    Coalesce,
+    Concat,
+    Left,
+    Length,
+    Lower,
+    Mod,
+    Substr,
+    Upper,
+)
+from django.db.models.sql import constants
+from django.db.models.sql.datastructures import Join
+from django.test import SimpleTestCase, TestCase, skipUnlessDBFeature
+from django.test.utils import (
+    Approximate,
+    CaptureQueriesContext,
+    isolate_apps,
+    register_lookup,
+)
+from django.utils.deprecation import RemovedInDjango50Warning
+from django.utils.functional import SimpleLazyObject
+
+from .models import (
+    UUID,
+    UUIDPK,
+    Company,
+    Employee,
+    Experiment,
+    Manager,
+    Number,
+    RemoteEmployee,
+    Result,
+    SimulationRun,
+    Time,
+)
+
+
+class ExpressionOperatorTests(TestCase):
+    @classmethod
+    def setUpTestData(cls):
+        cls.n = Number.objects.create(integer=42, float=15.5)
+        cls.n1 = Number.objects.create(integer=-42, float=-15.5)
+
+    def test_lefthand_addition(self):
+        # LH Addition of floats and integers
+        Number.objects.filter(pk=self.n.pk).update(
+            integer=F("integer") + 15, float=F("float") + 42.7
+        )
+
+        self.assertEqual(Number.objects.get(pk=self.n.pk).integer, 57)
+        self.assertEqual(
+            Number.objects.get(pk=self.n.pk).float, Approximate(58.200, places=3)
+        )
+
+    def test_lefthand_subtraction(self):
+        # LH Subtraction of floats and integers
+        Number.objects.filter(pk=self.n.pk).update(
+            integer=F("integer") - 15, float=F("float") - 42.7
+        )
+
+        self.assertEqual(Number.objects.get(pk=self.n.pk).integer, 27)
+        self.assertEqual(
+            Number.objects.get(pk=self.n.pk).float, Approximate(-27.200, places=3)
+        )
+
+    def test_lefthand_multiplication(self):
+        # Multiplication of floats and integers
+        Number.objects.filter(pk=self.n.pk).update(
+            integer=F("integer") * 15, float=F("float") * 42.7
+        )
+
+        self.assertEqual(Number.objects.get(pk=self.n.pk).integer, 630)
+        self.assertEqual(
+            Number.objects.get(pk=self.n.pk).float, Approximate(661.850, places=3)
+        )
+
+    def test_lefthand_division(self):
+        # LH Division of floats and integers
+        Number.objects.filter(pk=self.n.pk).update(
+            integer=F("integer") / 2, float=F("float") / 42.7
+        )
+
+        selfassertEqual(Number.objects.get(pk=self.n.pk).integer, 21)
+        self.assertEqual(
+            Number.objects.get(pk=self.n.pk).float, Approximate(0.363, places=3)
+        )
+
+    def test_lefthand_modulo(self):
+        # LH Modulo arithmetic on integers
+        Number.objects.filter(pk=self.n.pk).update(integer=F("integer") % 20)
+        self.assertEqual(Number.objects.get(pk=self.n.pk).integer, 2)
+
+    def test_lefthand_modulo_null(self):
+        # LH Modulo arithmetic on integers.
+        Employee.objects.create(firstname="John", lastname="Doe", salary=None)
+        qs = Employee.objects.annotate(modsalary=F("salary") % 20)
+        self.assertIsNone(qs.get().salary)
+
+    def test_lefthand_bitwise_and(self):
+        # LH Bitwise ands on integers
+        Number.objects.filter(pk=self.n.pk).update(integer=F("integer").bitand(56))
+        Number.objects.filter(pk=self.n1.pk).update(integer=F("integer").bitand(-56))
+
+        self.assertEqual(Number.objects.get(pk=self.n.pk).integer, 40)
+        self.assertEqual(Number.objects.get(pk=self.n1.pk).integer, -64)
+
+    def test_lefthand_bitwise_left_shift_operator(self):
+        Number.objects.update(integer=F("integer").bitleftshift(2))
+        self.assertEqual(Number.objects.get(pk=self.n.pk).integer, 168)
+        self.assertEqual(Number.objects.get(pk=self.n1.pk).integer, -168)
+
+    def test_lefthand_bitwise_right_shift_operator(self):
+        Number.objects.update(integer=F("integer").bitrightshift(2))
+        self.assertEqual(Number.objects.get(pk=self.n.pk).integer, 10)
+        self.assertEqual(Number.objects.get(pk=self.n1.pk).integer, -11)
+
+    def test_lefthand_bitwise_or(self):
+        # LH Bitwise or on integers
+        Number.objects.update(integer=F("integer").bitor(48))
+
+        self.assertEqual(Number.objects.get(pk=self.n.pk).integer, 58)
+        self.assertEqual(Number.objects.get(pk=self.n1.pk).integer, -10)
+
+    def test_lefthand_transformed_field_bitwise_or(self):
+        Employee.objects.create(firstname="Max", lastname="Mustermann")
+        with register_lookup(CharField, Length):
+            qs = Employee.objects.annotate(bitor=F("lastname__length").bitor(48))
+            self.assertEqual(qs.get().bitor, 58)
+
+    def test_lefthand_power(self):
+        # LH Power arithmetic operation on floats and integers
+        Number.objects.filter(pk=self.n.pk).update(
+            integer=F("integer") ** 2, float=F("float") ** 1.5
+        )
+        self.assertEqual(Number.objects.get(pk=self.n.pk).integer, 1764)
+        self.assertEqual(
+            Number.objects.get(pk=self.n.pk).float, Approximate(61.02, places=2)
+        )
+
+    def test_lefthand_bitwise_xor(self):
+        Number.objects.update(integer=F("integer").bitxor(48))
+        self.assertEqual(Number.objects.get(pk=self.n.pk).integer, 26)
+        self.assertEqual(Number.objects.get(pk=self.n1.pk).integer, -26)
+
+    def test_lefthand_bitwise_xor_null(self):
+        employee = Employee.objects.create(firstname="John", lastname="Doe")
+        Employee.objects.update(salary=F("salary").bitxor(48))
+        employee.refresh_from_db()
+        self.assertIsNone(employee.salary)
+
+    def test_lefthand_bitwise_xor_right_null(self):
+        employee = Employee.objects.create(firstname="John", lastname="Doe", salary=48)
+        Employee.objects.update(salary=F("salary").bitxor(None))
+        employee.refresh_from_db()
+        self.assertIsNone(employee.salary)
+
+    @unittest.skipUnless(
+        connection.vendor == "oracle", "Oracle doesn't support bitwise XOR."
+    )
+    def test_lefthand_bitwise_xor_not_supported(self):
+        msg = "Bitwise XOR is not supported in Oracle."
+        with self.assertRaisesMessage(NotSupportedError, msg):
+            Number.objects.update(integer=F("integer").bitxor(48))
+
+    def test_right_hand_addition(self):
+        # Right hand operators
+        Number.objects.filter(pk=self.n.pk).update(
+            integer=15 + F("integer"), float=42.7 + F("float")
+        )
+
+        # RH Addition of floats and integers
+        self.assertEqual(Number.objects.get(pk=self.n.pk).integer, 57)
+        self.assertEqual(
+            Number.objects.get(pk=self.n.pk).float, Approximate(58.200, places=3)
+        )
+
+    def test_right_hand_subtraction(self):
+        Number.objects.filter(pk=self.n.pk).update(
+            integer=15 - F("integer"), float=42.7 - F("float")
+        )
+
+        # RH Subtraction of floats and integers
+        self.assertEqual(Number.objects.get(pk=self.n.pk).integer, -27)
+        self.assertEqual(
+            Number.objects.get(pk=selfn.pk).float, Approximate(27.200, places=3)
+        )
+
+    def test_right_hand_multiplication(self):
+        # RH Multiplication of floats and integers
+        Number.objects.filter(pk=self.n.pk).update(
+            integer=15 * F("integer"), float=42.7 * F("float")
+        )
+
+        self.assertEqual(Number.objects.get(pk=self.n.pk).integer, 630)
+        self.assertEqual(
+            Number.objects.get(pk=self.n.pk).float, Approximate(661.850, places=3)
+        )
+
+    def test_right_hand_division(self):
+        # RH Division of floats and integers
+        Number.objects.filter(pk=self.n.pk).update(
+            integer=640 / F("integer"), float=42.7 / F("float")
+        )
+
+        self.assertEqual(Number.objects.get(pk=self.n.pk).integer, 15)
+        self.assertEqual(
+            Number.objects.get(pk=self.n.pk).float, Approximate(2.755, places=3)
+        )
+
+    def test_right_hand_modulo(self):
+        # RH Modulo arithmetic on integers
+        Number.objects.filter(pk=self.n.pk).update(integer=69 % F("integer"))
+
+        self.assertEqual(Number.objects.get(pk=self.n.pk).integer, 27)
+
+    def test_righthand_power(self):
+        # RH Power arithmetic operation on floats and integers
+        Number.objects.filter(pk=self.n.pk).update(
+            integer=2 ** F("integer"), float=1.5 ** F("float")
+        )
+        self.assertEqual(Number.objects.get(pk=self.n.pk).integer, 4398046511104)
+        self.assertEqual(
+            Number.objects.get(pk=self.n.pk).float, Approximate(536.308, places=3)
+        )
+
+    def test_mod_decimal_field_preserves_decimal_places(self):
+        qs = Number.objects.annotate(n_mod=Mod("decimal_value", "integer"))
+        resolved_field = qs.query.annotations["n_mod"].output_field
+        source_field = Number._meta.get_field("decimal_value")
+        self.assertEqual(resolved_field.decimal_places, source_field.decimal_places)

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/db/models/expressions\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 expressions.test_expression_operators
cat coverage.cover
git checkout bf47c719719d0e190a99fa2e7f959d5bbb7caf8a
git apply /root/pre_state.patch
