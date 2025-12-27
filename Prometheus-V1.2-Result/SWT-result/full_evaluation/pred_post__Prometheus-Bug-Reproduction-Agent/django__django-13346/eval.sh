#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 9c92924cd5d164701e2514e1c2d6574126bd7cc2 >> /root/pre_state.patch
sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen
export LANG=en_US.UTF-8
export LANGUAGE=en_US:en
export LC_ALL=en_US.UTF-8
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 9c92924cd5d164701e2514e1c2d6574126bd7cc2
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/django/db/models/fields/json.py b/django/db/models/fields/json.py
--- a/django/db/models/fields/json.py
+++ b/django/db/models/fields/json.py
@@ -378,6 +378,30 @@ def as_sqlite(self, compiler, connection):
         return super().as_sql(compiler, connection)
 
 
+class KeyTransformIn(lookups.In):
+    def process_rhs(self, compiler, connection):
+        rhs, rhs_params = super().process_rhs(compiler, connection)
+        if not connection.features.has_native_json_field:
+            func = ()
+            if connection.vendor == 'oracle':
+                func = []
+                for value in rhs_params:
+                    value = json.loads(value)
+                    function = 'JSON_QUERY' if isinstance(value, (list, dict)) else 'JSON_VALUE'
+                    func.append("%s('%s', '$.value')" % (
+                        function,
+                        json.dumps({'value': value}),
+                    ))
+                func = tuple(func)
+                rhs_params = ()
+            elif connection.vendor == 'mysql' and connection.mysql_is_mariadb:
+                func = ("JSON_UNQUOTE(JSON_EXTRACT(%s, '$'))",) * len(rhs_params)
+            elif connection.vendor in {'sqlite', 'mysql'}:
+                func = ("JSON_EXTRACT(%s, '$')",) * len(rhs_params)
+            rhs = rhs % func
+        return rhs, rhs_params
+
+
 class KeyTransformExact(JSONExact):
     def process_lhs(self, compiler, connection):
         lhs, lhs_params = super().process_lhs(compiler, connection)
@@ -479,6 +503,7 @@ class KeyTransformGte(KeyTransformNumericLookupMixin, lookups.GreaterThanOrEqual
     pass
 
 
+KeyTransform.register_lookup(KeyTransformIn)
 KeyTransform.register_lookup(KeyTransformExact)
 KeyTransform.register_lookup(KeyTransformIExact)
 KeyTransform.register_lookup(KeyTransformIsNull)

EOF_114329324912
git apply -v - <<'EOF_114329324912'
diff --git a/tests/model_fields/test_jsonfield_querying.py b/tests/model_fields/test_jsonfield_querying.py
new file mode 100644
index 0000000000..cd655b026e
--- /dev/null
+++ b/tests/model_fields/test_jsonfield_querying.py
@@ -0,0 +1,75 @@
+import operator
+import uuid
+from unittest import mock, skipIf
+
+from django import forms
+from django.core import serializers
+from django.core.exceptions import ValidationError
+from django.core.serializers.json import DjangoJSONEncoder
+from django.db import (
+    DataError, IntegrityError, NotSupportedError, OperationalError, connection,
+    models,
+)
+from django.db.models import Count, F, OuterRef, Q, Subquery, Transform, Value
+from django.db.models.expressions import RawSQL
+from django.db.models.fields.json import (
+    KeyTextTransform, KeyTransform, KeyTransformFactory,
+    KeyTransformTextLookupMixin,
+)
+from django.db.models.functions import Cast
+from django.test import (
+    SimpleTestCase, TestCase, skipIfDBFeature, skipUnlessDBFeature,
+)
+from django.test.utils import CaptureQueriesContext
+
+from .models import CustomJSONDecoder, JSONModel, NullableJSONModel
+
+
+@skipUnlessDBFeature('supports_json_field')
+class TestQuerying(TestCase):
+    @classmethod
+    def setUpTestData(cls):
+        cls.primitives = [True, False, 'yes', 7, 9.6]
+        values = [
+            None,
+            [],
+            {},
+            {'a': 'b', 'c': 14},
+            {
+                'a': 'b',
+                'c': 14,
+                'd': ['e', {'f': 'g'}],
+                'h': True,
+                'i': False,
+                'j': None,
+                'k': {'l': 'm'},
+                'n': [None],
+            },
+            [1, [2]],
+            {'k': True, 'l': False},
+            {
+                'foo': 'bar',
+                'baz': {'a': 'b', 'c': 'd'},
+                'bar': ['foo', 'bar'],
+                'bax': {'foo': 'bar'},
+            },
+        ]
+        cls.objs = [
+            NullableJSONModel.objects.create(value=value)
+            for value in values
+        ]
+        if connection.features.supports_primitives_in_json_field:
+            cls.objs.extend([
+                NullableJSONModel.objects.create(value=value)
+                for value in cls.primitives
+            ])
+        cls.raw_sql = '%s::jsonb' if connection.vendor == 'postgresql' else '%s'
+
+    def test_key_transform_in_lookup(self):
+        """
+        Test __in lookup on a key transform.
+        """
+        self.assertSequenceEqual(
+            NullableJSONModel.objects.filter(value__c__in=[14]),
+            [self.objs[3], self.objs[4]],
+        )

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/db/models/fields/json\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 model_fields.test_jsonfield_querying
cat coverage.cover
git checkout 9c92924cd5d164701e2514e1c2d6574126bd7cc2
git apply /root/pre_state.patch
