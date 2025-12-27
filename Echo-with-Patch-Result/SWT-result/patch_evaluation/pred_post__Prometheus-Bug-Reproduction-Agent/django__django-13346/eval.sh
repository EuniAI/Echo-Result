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
diff --git a/model_fields/tests/test_jsonfield.py b/model_fields/tests/test_jsonfield.py
new file mode 100644
index 0000000000..1e5292bb1c
--- /dev/null
+++ b/model_fields/tests/test_jsonfield.py
@@ -0,0 +1,505 @@
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
+class JSONFieldTests(TestCase):
+    def test_invalid_value(self):
+        msg = 'is not JSON serializable'
+        with self.assertRaisesMessage(TypeError, msg):
+            NullableJSONModel.objects.create(value={
+                'uuid': uuid.UUID('d85e2076-b67c-4ee7-8c3a-2bf5a2cc2475'),
+            })
+
+    def test_custom_encoder_decoder(self):
+        value = {'uuid': uuid.UUID('{d85e2076-b67c-4ee7-8c3a-2bf5a2cc2475}')}
+        obj = NullableJSONModel(value_custom=value)
+        obj.clean_fields()
+        obj.save()
+        obj.refresh_from_db()
+        self.assertEqual(obj.value_custom, value)
+
+    def test_db_check_constraints(self):
+        value = '{@!invalid json value 123 $!@#}'
+        with mock.patch.object(DjangoJSONEncoder, 'encode', return_value=value):
+            with self.assertRaises((IntegrityError, DataError, OperationalError)):
+                NullableJSONModel.objects.create(value_custom=value)
+
+
+class TestMethods(SimpleTestCase):
+    def test_deconstruct(self):
+        field = models.JSONField()
+        name, path, args, kwargs = field.deconstruct()
+        self.assertEqual(path, 'django.db.models.JSONField')
+        self.assertEqual(args, [])
+        self.assertEqual(kwargs, {})
+
+    def test_deconstruct_custom_encoder_decoder(self):
+        field = models.JSONField(encoder=DjangoJSONEncoder, decoder=CustomJSONDecoder)
+        name, path, args, kwargs = field.deconstruct()
+        self.assertEqual(kwargs['encoder'], DjangoJSONEncoder)
+        self.assertEqual(kwargs['decoder'], CustomJSONDecoder)
+
+    def test_get_transforms(self):
+        @models.JSONField.register_lookup
+        class MyTransform(Transform):
+            lookup_name = 'my_transform'
+        field = models.JSONField()
+        transform = field.get_transform('my_transform')
+        self.assertIs(transform, MyTransform)
+        models.JSONField._unregister_lookup(MyTransform)
+        models.JSONField._clear_cached_lookups()
+        transform = field.get_transform('my_transform')
+        self.assertIsInstance(transform, KeyTransformFactory)
+
+    def test_key_transform_text_lookup_mixin_non_key_transform(self):
+        transform = Transform('test')
+        msg = (
+            'Transform should be an instance of KeyTransform in order to use '
+            'this lookup.'
+        )
+        with self.assertRaisesMessage(TypeError, msg):
+            KeyTransformTextLookupMixin(transform)
+
+
+class TestValidation(SimpleTestCase):
+    def test_invalid_encoder(self):
+        msg = 'The encoder parameter must be a callable object.'
+        with self.assertRaisesMessage(ValueError, msg):
+            models.JSONField(encoder=DjangoJSONEncoder())
+
+    def test_invalid_decoder(self):
+        msg = 'The decoder parameter must be a callable object.'
+        with self.assertRaisesMessage(ValueError, msg):
+            models.JSONField(decoder=CustomJSONDecoder())
+
+    def test_validation_error(self):
+        field = models.JSONField()
+        msg = 'Value must be valid JSON.'
+        value = uuid.UUID('{d85e2076-b67c-4ee7-8c3a-2bf5a2cc2475}')
+        with self.assertRaisesMessage(ValidationError, msg):
+            field.clean({'uuid': value}, None)
+
+    def test_custom_encoder(self):
+        field = models.JSONField(encoder=DjangoJSONEncoder)
+        value = uuid.UUID('{d85e2076-b67c-4ee7-8c3a-2bf5a2cc2475}')
+        field.clean({'uuid': value}, None)
+
+
+class TestFormField(SimpleTestCase):
+    def test_formfield(self):
+        model_field = models.JSONField()
+        form_field = model_field.formfield()
+        self.assertIsInstance(form_field, forms.JSONField)
+
+    def test_formfield_custom_encoder_decoder(self):
+        model_field = models.JSONField(encoder=DjangoJSONEncoder, decoder=CustomJSONDecoder)
+        form_field = model_field.formfield()
+        self.assertIs(form_field.encoder, DjangoJSONEncoder)
+        self.assertIs(form_field.decoder, CustomJSONDecoder)
+
+
+class TestSerialization(SimpleTestCase):
+    test_data = (
+        '[{"fields": {"value": %s}, '
+        '"model": "model_fields.jsonmodel", "pk": null}]'
+    )
+    test_values = (
+        # (Python value, serialized value),
+        ({'a': 'b', 'c': None}, '{"a": "b", "c": null}'),
+        ('abc', '"abc"'),
+        ('{"a": "a"}', '"{\"a\": \"a\"}"'),
+    )
+
+    def test_dumping(self):
+        for value, serialized in self.test_values:
+            with self.subTest(value=value):
+                instance = JSONModel(value=value)
+                data = serializers.serialize('json', [instance])
+                self.assertJSONEqual(data, self.test_data % serialized)
+
+    def test_loading(self):
+        for value, serialized in self.test_values:
+            with self.subTest(value=value):
+                instance = list(
+                    serializers.deserialize('json', self.test_data % serialized)
+                )[0].object
+                self.assertEqual(instance.value, value)
+
+    def test_xml_serialization(self):
+        test_xml_data = (
+            '<django-objects version="1.0">'
+            '<object model="model_fields.nullablejsonmodel">'
+            '<field name="value" type="JSONField">%s'
+            '</field></object></django-objects>'
+        )
+        for value, serialized in self.test_values:
+            with self.subTest(value=value):
+                instance = NullableJSONModel(value=value)
+                data = serializers.serialize('xml', [instance], fields=['value'])
+                self.assertXMLEqual(data, test_xml_data % serialized)
+                new_instance = list(serializers.deserialize('xml', data))[0].object
+                self.assertEqual(new_instance.value, instance.value)
+
+
+@skipUnlessDBFeature('supports_json_field')
+class TestSaveLoad(TestCase):
+    def test_null(self):
+        obj = NullableJSONModel(value=None)
+        obj.save()
+        obj.refresh_from_db()
+        self.assertIsNone(obj.value)
+
+    @skipUnlessDBFeature('supports_primitives_in_json_field')
+    def test_json_null_different_from_sql_null(self):
+        json_null = NullableJSONModel.objects.create(value=Value('null'))
+        json_null.refresh_from_db()
+        sql_null = NullableJSONModel.objects.create(value=None)
+        sql_null.refresh_from_db()
+        # 'null' is not equal to NULL in the database.
+        self.assertSequenceEqual(
+            NullableJSONModel.objects.filter(value=Value('null')),
+            [json_null],
+        )
+        self.assertSequenceEqual(
+            NullableJSONModel.objects.filter(value=None),
+            [json_null],
+        )
+        self.assertSequenceEqual(
+            NullableJSONModel.objects.filter(value__isnull=True),
+            [sql_null],
+        )
+        # 'null' is equal to NULL in Python (None).
+        self.assertEqual(json_null.value, sql_null.value)
+
+    @skipUnlessDBFeature('supports_primitives_in_json_field')
+    def test_primitives(self):
+        values = [
+            True,
+            1,
+            1.45,
+            'String',
+            '',
+        ]
+        for value in values:
+            with self.subTest(value=value):
+                obj = JSONModel(value=value)
+                obj.save()
+                obj.refresh_from_db()
+                self.assertEqual(obj.value, value)
+
+    def test_dict(self):
+        values = [
+            {},
+            {'name': 'John', 'age': 20, 'height': 180.3},
+            {'a': True, 'b': {'b1': False, 'b2': None}},
+        ]
+        for value in values:
+            with self.subTest(value=value):
+                obj = JSONModel.objects.create(value=value)
+                obj.refresh_from_db()
+                self.assertEqual(obj.value, value)
+
+    def test_list(self):
+        values = [
+            [],
+            ['John', 20, 180.3],
+            [True, [False, None]],
+        ]
+        for value in values:
+            with self.subTest(value=value):
+                obj = JSONModel.objects.create(value=value)
+                obj.refresh_from_db()
+                self.assertEqual(obj.value, value)
+
+    def test_realistic_object(self):
+        value = {
+            'name': 'John',
+            'age': 20,
+            'pets': [
+                {'name': 'Kit', 'type': 'cat', 'age': 2},
+                {'name': 'Max', 'type': 'dog', 'age': 1},
+            ],
+            'courses': [
+                ['A1', 'A2', 'A3'],
+                ['B1', 'B2'],
+                ['C1'],
+            ],
+        }
+        obj = JSONModel.objects.create(value=value)
+        obj.refresh_from_db()
+        self.assertEqual(obj.value, value)
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
+    def test_exact(self):
+        self.assertSequenceEqual(
+            NullableJSONModel.objects.filter(value__exact={}),
+            [self.objs[2]],
+        )
+
+    def test_exact_complex(self):
+        self.assertSequenceEqual(
+            NullableJSONModel.objects.filter(value__exact={'a': 'b', 'c': 14}),
+            [self.objs[3]],
+        )
+
+    def test_isnull(self):
+        self.assertSequenceEqual(
+            NullableJSONModel.objects.filter(value__isnull=True),
+            [self.objs[0]],
+        )
+
+    def test_key_in_lookup(self):
+        self.assertCountEqual(
+            NullableJSONModel.objects.filter(value__c__in=[14]),
+            [self.objs[3], self.objs[4]],
+        )
+
+    def test_ordering_by_transform(self):
+        objs = [
+            NullableJSONModel.objects.create(value={'ord': 93, 'name': 'bar'}),
+            NullableJSONModel.objects.create(value={'ord': 22.1, 'name': 'foo'}),
+            NullableJSONModel.objects.create(value={'ord': -1, 'name': 'baz'}),
+            NullableJSONModel.objects.create(value={'ord': 21.931902, 'name': 'spam'}),
+            NullableJSONModel.objects.create(value={'ord': -100291029, 'name': 'eggs'}),
+        ]
+        query = NullableJSONModel.objects.filter(value__name__isnull=False).order_by('value__ord')
+        expected = [objs[4], objs[2], objs[3], objs[1], objs[0]]
+        mariadb = connection.vendor == 'mysql' and connection.mysql_is_mariadb
+        if mariadb or connection.vendor == 'oracle':
+            # MariaDB and Oracle return JSON values as strings.
+            expected = [objs[2], objs[4], objs[3], objs[1], objs[0]]
+        self.assertSequenceEqual(query, expected)
+
+    def test_ordering_grouping_by_key_transform(self):
+        base_qs = NullableJSONModel.objects.filter(value__d__0__isnull=False)
+        for qs in (
+            base_qs.order_by('value__d__0'),
+            base_qs.annotate(key=KeyTransform('0', KeyTransform('d', 'value'))).order_by('key'),
+        ):
+            self.assertSequenceEqual(qs, [self.objs[4]])
+        qs = NullableJSONModel.objects.filter(value__isnull=False)
+        self.assertQuerysetEqual(
+            qs.filter(value__isnull=False).annotate(
+                key=KeyTextTransform('f', KeyTransform('1', KeyTransform('d', 'value'))),
+            ).values('key').annotate(count=Count('key')).order_by('count'),
+            [(None, 0), ('g', 1)],
+            operator.itemgetter('key', 'count'),
+        )
+
+    @skipIf(connection.vendor == 'oracle', "Oracle doesn't support grouping by LOBs, see #24096.")
+    def test_ordering_grouping_by_count(self):
+        qs = NullableJSONModel.objects.filter(
+            value__isnull=False,
+        ).values('value__d__0').annotate(count=Count('value__d__0')).order_by('count')
+        self.assertQuerysetEqual(qs, [1, 11], operator.itemgetter('count'))
+
+    def test_key_transform_raw_expression(self):
+        expr = RawSQL(self.raw_sql, ['{"x": "bar"}'])
+        self.assertSequenceEqual(
+            NullableJSONModel.objects.filter(value__foo=KeyTransform('x', expr)),
+            [self.objs[7]],
+        )
+
+    def test_nested_key_transform_raw_expression(self):
+        expr = RawSQL(self.raw_sql, ['{"x": {"y": "bar"}}'])
+        self.assertSequenceEqual(
+            NullableJSONModel.objects.filter(value__foo=KeyTransform('y', KeyTransform('x', expr))),
+            [self.objs[7]],
+        )
+
+    def test_key_transform_expression(self):
+        self.assertSequenceEqual(
+            NullableJSONModel.objects.filter(value__d__0__isnull=False).annotate(
+                key=KeyTransform('d', 'value'),
+                chain=KeyTransform('0', 'key'),
+                expr=KeyTransform('0', Cast('key', models.JSONField())),
+            ).filter(chain=F('expr')),
+            [self.objs[4]],
+        )
+
+    def test_nested_key_transform_expression(self):
+        self.assertSequenceEqual(
+            NullableJSONModel.objects.filter(value__d__0__isnull=False).annotate(
+                key=KeyTransform('d', 'value'),
+                chain=KeyTransform('f', KeyTransform('1', 'key')),
+                expr=KeyTransform('f', KeyTransform('1', Cast('key', models.JSONField()))),
+            ).filter(chain=F('expr')),
+            [self.objs[4]],
+        )
+
+    def test_has_key(self):
+        self.assertSequenceEqual(
+            NullableJSONModel.objects.filter(value__has_key='a'),
+            [self.objs[3], self.objs[4]],
+        )
+
+    def test_has_key_null_value(self):
+        self.assertSequenceEqual(
+            NullableJSONModel.objects.filter(value__has_key='j'),
+            [self.objs[4]],
+        )
+
+    def test_has_key_deep(self):
+        tests = [
+            (Q(value__baz__has_key='a'), self.objs[7]),
+            (Q(value__has_key=KeyTransform('a', KeyTransform('baz', 'value'))), self.objs[7]),
+            (Q(value__has_key=KeyTransform('c', KeyTransform('baz', 'value'))), self.objs[7]),
+            (Q(value__d__1__has_key='f'), self.objs[4]),
+            (
+                Q(value__has_key=KeyTransform('f', KeyTransform('1', KeyTransform('d', 'value')))),
+                self.objs[4],
+            )
+        ]
+        for condition, expected in tests:
+            with self.subTest(condition=condition):
+                self.assertSequenceEqual(
+                    NullableJSONModel.objects.filter(condition),
+                    [expected],
+                )
+
+    def test_has_key_list(self):
+        obj = NullableJSONModel.objects.create(value=[{'a': 1}, {'b': 'x'}])
+        tests = [
+            Q(value__1__has_key='b'),
+            Q(value__has_key=KeyTransform('b', KeyTransform(1, 'value'))),
+            Q(value__has_key=KeyTransform('b', KeyTransform('1', 'value'))),
+        ]
+        for condition in tests:
+            with self.subTest(condition=condition):
+                self.assertSequenceEqual(
+                    NullableJSONModel.objects.filter(condition),
+                    [obj],
+                )
+
+    def test_has_keys(self):
+        self.assertSequenceEqual(
+            NullableJSONModel.objects.filter(value__has_keys=['a', 'c', 'h']),
+            [self.objs[4]],
+        )
+
+    def test_has_any_keys(self):
+        self.assertSequenceEqual(
+            NullableJSONModel.objects.filter(value__has_any_keys=['c', 'l']),
+            [self.objs[3], self.objs[4], self.objs[6]],
+        )
+
+    @skipUnlessDBFeature('supports_json_field_contains')
+    def test_contains(self):
+        tests = [
+            ({}, self.objs[2:5] + self.objs[6:8]),
+            ({'baz': {'a': 'b', 'c': 'd'}}, [self.objs[7]]),
+            ({'baz': {'a': 'b'}}, [self.objs[7]]),
+            ({'baz': {'c': 'd'}}, [self.objs[7]]),
+            ({'k': True, 'l': False}, [self.objs[6]]),
+            ({'d': ['e', {'f': 'g'}]}, [self.objs[4]]),
+            ({'d': ['e']}, [self.objs[4]]),
+            ({'d': [{'f': 'g'}]}, [self.objs[4]]),
+            ([1, [2]], [self.objs[5]]),
+            ([1], [self.objs[5]]),
+            ([[2]], [self.objs[5]]),
+            ({'n': [None]}, [self.objs[4]]),
+            ({'j': None}, [self.objs[4]]),
+        ]
+        for value, expected in tests:
+            with self.subTest(value=value):
+                qs = NullableJSONModel.objects.filter(value__contains=value)
+                selfse.assertSequenceEqual(qs, expected)
+
+    @skipIfDBFeature('supports_json_field_contains')
+    def test_contains_unsupported(self):
+        msg = 'contains lookup is not supported on this database backend.'
+        with self.assertRaisesMessage(NotSupportedError, msg):
+            NullableJSONModel.objects.filter(
+                value__contains={'baz': {'a': 'b', 'c': 'd'}},
+            ).get()
+
+    @skipUnlessDBFeature(
+        'supports_primitives_in_json_field',
+        'supports_json_field_contains',
+    )
+    def test_contains_primitives(self):
+        for value in self.primitives:
+            with self.subTest(value=value):
+                qs = NullableJSONModel.objects.filter(value__contains=value)
+                self.assertIs(qs.exists(), True)
+
+    @skipUnlessDBFeature('supports_json_field_contains')
+    def test_contained_by(self):
+        qs = NullableJSONModel.objects.filter(value__contained_by={'a': 'b', 'c': 14, 'h': True})
+        self.assertSequenceEqual(qs, self.objs[2:4])
+
+    @skipIfDBFeature('supports_json_field_contains')
+    def test_contained_by_unsupported(self):
+        msg = 'contained_by lookup is not supported on this database backend.'
+        with self.assertRaisesMessage(NotSupportedError, msg):
+            NullableJSONModel.objects.filter(value__contained_by={'a': 'b'}).get()
+
+    def test_deep_values(self):
+        qs = NullableJSONModel.objects.values_list('value__k__l')
+        expected_objs = [(None,)] * len(self.objs)
+        expected_objs[4] = ('m',)
+        self.assertSequenceEqual(qs, expected_objs)

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/db/models/fields/json\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 model_fields.tests.test_jsonfield
cat coverage.cover
git checkout 9c92924cd5d164701e2514e1c2d6574126bd7cc2
git apply /root/pre_state.patch
