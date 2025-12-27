#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 859a87d873ce7152af73ab851653b4e1c3ffea4c >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 859a87d873ce7152af73ab851653b4e1c3ffea4c
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/django/db/models/fields/json.py b/django/db/models/fields/json.py
--- a/django/db/models/fields/json.py
+++ b/django/db/models/fields/json.py
@@ -172,6 +172,10 @@ def as_sql(self, compiler, connection):
 class HasKeyLookup(PostgresOperatorLookup):
     logical_operator = None
 
+    def compile_json_path_final_key(self, key_transform):
+        # Compile the final key without interpreting ints as array elements.
+        return ".%s" % json.dumps(key_transform)
+
     def as_sql(self, compiler, connection, template=None):
         # Process JSON path from the left-hand side.
         if isinstance(self.lhs, KeyTransform):
@@ -193,13 +197,10 @@ def as_sql(self, compiler, connection, template=None):
                 *_, rhs_key_transforms = key.preprocess_lhs(compiler, connection)
             else:
                 rhs_key_transforms = [key]
-            rhs_params.append(
-                "%s%s"
-                % (
-                    lhs_json_path,
-                    compile_json_path(rhs_key_transforms, include_root=False),
-                )
-            )
+            *rhs_key_transforms, final_key = rhs_key_transforms
+            rhs_json_path = compile_json_path(rhs_key_transforms, include_root=False)
+            rhs_json_path += self.compile_json_path_final_key(final_key)
+            rhs_params.append(lhs_json_path + rhs_json_path)
         # Add condition for each key.
         if self.logical_operator:
             sql = "(%s)" % self.logical_operator.join([sql] * len(rhs_params))
@@ -253,6 +254,11 @@ class HasAnyKeys(HasKeys):
     logical_operator = " OR "
 
 
+class HasKeyOrArrayIndex(HasKey):
+    def compile_json_path_final_key(self, key_transform):
+        return compile_json_path([key_transform], include_root=False)
+
+
 class CaseInsensitiveMixin:
     """
     Mixin to allow case-insensitive comparison of JSON values on MySQL.
@@ -387,7 +393,7 @@ def __init__(self, key_transform, *args, **kwargs):
 class KeyTransformIsNull(lookups.IsNull):
     # key__isnull=False is the same as has_key='key'
     def as_oracle(self, compiler, connection):
-        sql, params = HasKey(
+        sql, params = HasKeyOrArrayIndex(
             self.lhs.lhs,
             self.lhs.key_name,
         ).as_oracle(compiler, connection)
@@ -401,7 +407,7 @@ def as_sqlite(self, compiler, connection):
         template = "JSON_TYPE(%s, %%s) IS NULL"
         if not self.rhs:
             template = "JSON_TYPE(%s, %%s) IS NOT NULL"
-        return HasKey(self.lhs.lhs, self.lhs.key_name).as_sql(
+        return HasKeyOrArrayIndex(self.lhs.lhs, self.lhs.key_name).as_sql(
             compiler,
             connection,
             template=template,
@@ -466,7 +472,7 @@ def as_oracle(self, compiler, connection):
         rhs, rhs_params = super().process_rhs(compiler, connection)
         if rhs_params == ["null"]:
             # Field has key and it's NULL.
-            has_key_expr = HasKey(self.lhs.lhs, self.lhs.key_name)
+            has_key_expr = HasKeyOrArrayIndex(self.lhs.lhs, self.lhs.key_name)
             has_key_sql, has_key_params = has_key_expr.as_oracle(compiler, connection)
             is_null_expr = self.lhs.get_lookup("isnull")(self.lhs, True)
             is_null_sql, is_null_params = is_null_expr.as_sql(compiler, connection)

EOF_114329324912
git apply -v - <<'EOF_114329324912'
diff --git a/tests/model_fields/test_jsonfield_repro.py b/tests/model_fields/test_jsonfield_repro.py
new file mode 100644
index 0000000000..c99d1a0894
--- /dev/null
+++ b/tests/model_fields/test_jsonfield_repro.py
@@ -0,0 +1,589 @@
+import operator
+import uuid
+from unittest import mock
+
+from django import forms
+from django.core import serializers
+from django.core.exceptions import ValidationError
+from django.core.serializers.json import DjangoJSONEncoder
+from django.db import (
+    DataError,
+    IntegrityError,
+    NotSupportedError,
+    OperationalError,
+    connection,
+    models,
+)
+from django.db.models import (
+    Count,
+    ExpressionWrapper,
+    F,
+    IntegerField,
+    OuterRef,
+    Q,
+    Subquery,
+    Transform,
+    Value,
+)
+from django.db.models.expressions import RawSQL
+from django.db.models.fields.json import (
+    KeyTextTransform,
+    KeyTransform,
+    KeyTransformFactory,
+    KeyTransformTextLookupMixin,
+)
+from django.db.models.functions import Cast
+from django.test import SimpleTestCase, TestCase, skipIfDBFeature, skipUnlessDBFeature
+from django.test.utils import CaptureQueriesContext
+
+from .models import CustomJSONDecoder, JSONModel, NullableJSONModel, RelatedJSONModel
+
+
+@skipUnlessDBFeature("supports_json_field")
+class JSONFieldTests(TestCase):
+    def test_invalid_value(self):
+        msg = "is not JSON serializable"
+        with self.assertRaisesMessage(TypeError, msg):
+            NullableJSONModel.objects.create(
+                value={
+                    "uuid": uuid.UUID("d85e2076-b67c-4ee7-8c3a-2bf5a2cc2475"),
+                }
+            )
+
+    def test_custom_encoder_decoder(self):
+        value = {"uuid": uuid.UUID("{d85e2076-b67c-4ee7-8c3a-2bf5a2cc2475}")}
+        obj = NullableJSONModel(value_custom=value)
+        obj.clean_fields()
+        obj.save()
+        obj.refresh_from_db()
+        self.assertEqual(obj.value_custom, value)
+
+    def test_db_check_constraints(self):
+        value = "{@!invalid json value 123 $!@#"
+        with mock.patch.object(DjangoJSONEncoder, "encode", return_value=value):
+            with self.assertRaises((IntegrityError, DataError, OperationalError)):
+                NullableJSONModel.objects.create(value_custom=value)
+
+
+class TestMethods(SimpleTestCase):
+    def test_deconstruct(self):
+        field = models.JSONField()
+        name, path, args, kwargs = field.deconstruct()
+        self.assertEqual(path, "django.db.models.JSONField")
+        self.assertEqual(args, [])
+        self.assertEqual(kwargs, {})
+
+    def test_deconstruct_custom_encoder_decoder(self):
+        field = models.JSONField(encoder=DjangoJSONEncoder, decoder=CustomJSONDecoder)
+        name, path, args, kwargs = field.deconstruct()
+        self.assertEqual(kwargs["encoder"], DjangoJSONEncoder)
+        self.assertEqual(kwargs["decoder"], CustomJSONDecoder)
+
+    def test_get_transforms(self):
+        @models.JSONField.register_lookup
+        class MyTransform(Transform):
+            lookup_name = "my_transform"
+
+        field = models.JSONField()
+        transform = field.get_transform("my_transform")
+        self.assertIs(transform, MyTransform)
+        models.JSONField._unregister_lookup(MyTransform)
+        models.JSONField._clear_cached_lookups()
+        transform = field.get_transform("my_transform")
+        self.assertIsInstance(transform, KeyTransformFactory)
+
+    def test_key_transform_text_lookup_mixin_non_key_transform(self):
+        transform = Transform("test")
+        msg = (
+            "Transform should be an instance of KeyTransform in order to use "
+            "this lookup."
+        )
+        with self.assertRaisesMessage(TypeError, msg):
+            KeyTransformTextLookupMixin(transform)
+
+
+class TestValidation(SimpleTestCase):
+    def test_invalid_encoder(self):
+        msg = "The encoder parameter must be a callable object."
+        with self.assertRaisesMessage(ValueError, msg):
+            models.JSONField(encoder=DjangoJSONEncoder())
+
+    def test_invalid_decoder(self):
+        msg = "The decoder parameter must be a callable object."
+        with self.assertRaisesMessage(ValueError, msg):
+            models.JSONField(decoder=CustomJSONDecoder())
+
+    def test_validation_error(self):
+        field = models.JSONField()
+        msg = "Value must be valid JSON."
+        value = uuid.UUID("{d85e2076-b67c-4ee7-8c3a-2bf5a2cc2475}")
+        with self.assertRaisesMessage(ValidationError, msg):
+            field.clean({"uuid": value}, None)
+
+    def test_custom_encoder(self):
+        field = models.JSONField(encoder=DjangoJSONEncoder)
+        value = uuid.UUID("{d85e2076-b67c-4ee7-8c3a-2bf5a2cc2475}")
+        field.clean({"uuid": value}, None)
+
+
+class TestFormField(SimpleTestCase):
+    def test_formfield(self):
+        model_field = models.JSONField()
+        form_field = model_field.formfield()
+        self.assertIsInstance(form_field, forms.JSONField)
+
+    def test_formfield_custom_encoder_decoder(self):
+        model_field = models.JSONField(
+            encoder=DjangoJSONEncoder, decoder=CustomJSONDecoder
+        )
+        form_field = model_field.formfield()
+        self.assertIs(form_field.encoder, DjangoJSONEncoder)
+        self.assertIs(form_field.decoder, CustomJSONDecoder)
+
+
+class TestSerialization(SimpleTestCase):
+    test_data = (
+        '[{"fields": {"value": %s}, "model": "model_fields.jsonmodel", "pk": null}]'
+    )
+    test_values = (
+        # (Python value, serialized value),
+        ({"a": "b", "c": None}, '''{"a": "b", "c": null}'''),
+        ("abc", '"abc"'),
+        ('''{"a": "a"}''', '"{\"a\": \"a\"}"'),
+    )
+
+    def test_dumping(self):
+        for value, serialized in self.test_values:
+            with self.subTest(value=value):
+                instance = JSONModel(value=value)
+                data = serializers.serialize("json", [instance])
+                self.assertJSONEqual(data, self.test_data % serialized)
+
+    def test_loading(self):
+        for value, serialized in self.test_values:
+            with self.subTest(value=value):
+                instance = list(
+                    serializers.deserialize("json", self.test_data % serialized)
+                )[0].object
+                self.assertEqual(instance.value, value)
+
+    def test_xml_serialization(self):
+        test_xml_data = (
+            '''<django-objects version="1.0">'''
+            '''<object model="model_fields.nullablejsonmodel">'''
+            '''<field name="value" type="JSONField">%s'''
+            '''</field></object></django-objects>'''
+        )
+        for value, serialized in self.test_values:
+            with self.subTest(value=value):
+                instance = NullableJSONModel(value=value)
+                data = serializers.serialize("xml", [instance], fields=["value"])
+                self.assertXMLEqual(data, test_xml_data % serialized)
+                new_instance = list(serializers.deserialize("xml", data))[0].object
+                self.assertEqual(new_instance.value, instance.value)
+
+
+@skipUnlessDBFeature("supports_json_field")
+class TestSaveLoad(TestCase):
+    def test_null(self):
+        obj = NullableJSONModel(value=None)
+        obj.save()
+        obj.refresh_from_db()
+        self.assertIsNone(obj.value)
+
+    @skipUnlessDBFeature("supports_primitives_in_json_field")
+    def test_json_null_different_from_sql_null(self):
+        json_null = NullableJSONModel.objects.create(value=Value("null"))
+        json_null.refresh_from_db()
+        sql_null = NullableJSONModel.objects.create(value=None)
+        sql_null.refresh_from_db()
+        # '''null''' is not equal to NULL in the database.
+        self.assertSequenceEqual(
+            NullableJSONModel.objects.filter(value=Value("null")),
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
+        # '''null''' is equal to NULL in Python (None).
+        self.assertEqual(json_null.value, sql_null.value)
+
+    @skipUnlessDBFeature("supports_primitives_in_json_field")
+    def test_primitives(self):
+        values = [
+            True,
+            1,
+            1.45,
+            "String",
+            "",
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
+            {"name": "John", "age": 20, "height": 180.3},
+            {"a": True, "b": {"b1": False, "b2": None}},
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
+            ["John", 20, 180.3],
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
+            "name": "John",
+            "age": 20,
+            "pets": [
+                {"name": "Kit", "type": "cat", "age": 2},
+                {"name": "Max", "type": "dog", "age": 1},
+            ],
+            "courses": [
+                ["A1", "A2", "A3"],
+                ["B1", "B2"],
+                ["C1"],
+            ],
+        }
+        obj = JSONModel.objects.create(value=value)
+        obj.refresh_from_db()
+        self.assertEqual(obj.value, value)
+
+
+@skipUnlessDBFeature("supports_json_field")
+class TestQuerying(TestCase):
+    @classmethod
+    def setUpTestData(cls):
+        cls.primitives = [True, False, "yes", 7, 9.6]
+        values = [
+            None,
+            [],
+            {},
+            {"a": "b", "c": 14},
+            {
+                "a": "b",
+                "c": 14,
+                "d": ["e", {"f": "g"}],
+                "h": True,
+                "i": False,
+                "j": None,
+                "k": {"l": "m"},
+                "n": [None, True, False],
+                "o": '"quoted"',
+                "p": 4.2,
+                "r": {"s": True, "t": False},
+            },
+            [1, [2]],
+            {"k": True, "l": False, "foo": "bax"},
+            {
+                "foo": "bar",
+                "baz": {"a": "b", "c": "d"},
+                "bar": ["foo", "bar"],
+                "bax": {"foo": "bar"},
+            },
+        ]
+        cls.objs = [NullableJSONModel.objects.create(value=value) for value in values]
+        if connection.features.supports_primitives_in_json_field:
+            cls.objs.extend(
+                [
+                    NullableJSONModel.objects.create(value=value)
+                    for value in cls.primitives
+                ]
+            )
+        cls.raw_sql = "%s::jsonb" if connection.vendor == "postgresql" else "%s"
+
+    def test_exact(self):
+        self.assertSequenceEqual(
+            NullableJSONModel.objects.filter(value__exact={}),
+            [self.objs[2]],
+        )
+
+    def test_exact_complex(self):
+        self.assertSequenceEqual(
+            NullableJSONModel.objects.filter(value__exact={"a": "b", "c": 14}),
+            [self.objs[3]],
+        )
+
+    def test_icontains(self):
+        self.assertSequenceEqual(
+            NullableJSONModel.objects.filter(value__icontains="BaX"),
+            self.objs[6:8],
+        )
+
+    def test_isnull(self):
+        self.assertSequenceEqual(
+            NullableJSONModel.objects.filter(value__isnull=True),
+            [self.objs[0]],
+        )
+
+    def test_ordering_by_transform(self):
+        mariadb = connection.vendor == "mysql" and connection.mysql_is_mariadb
+        values = [
+            {"ord": 93, "name": "bar"},
+            {"ord": 22.1, "name": "foo"},
+            {"ord": -1, "name": "baz"},
+            {"ord": 21.931902, "name": "spam"},
+            {"ord": -100291029, "name": "eggs"},
+        ]
+        for field_name in ["value", "value_custom"]:
+            with self.subTest(field=field_name):
+                objs = [
+                    NullableJSONModel.objects.create(**{field_name: value})
+                    for value in values
+                ]
+                query = NullableJSONModel.objects.filter(
+                    **{"%s__name__isnull" % field_name: False},
+                ).order_by("%s__ord" % field_name)
+                expected = [objs[4], objs[2], objs[3], objs[1], objs[0]]
+                if mariadb or connection.vendor == "oracle":
+                    # MariaDB and Oracle return JSON values as strings.
+                    expected = [objs[2], objs[4], objs[3], objs[1], objs[0]]
+                self.assertSequenceEqual(query, expected)
+
+    def test_ordering_grouping_by_key_transform(self):
+        base_qs = NullableJSONModel.objects.filter(value__d__0__isnull=False)
+        for qs in (
+            base_qs.order_by("value__d__0"),
+            base_qs.annotate(
+                key=KeyTransform("0", KeyTransform("d", "value"))
+            ).order_by("key"),
+        ):
+            self.assertSequenceEqual(qs, [self.objs[4]])
+        qs = NullableJSONModel.objects.filter(value__isnull=False)
+        self.assertQuerysetEqual(
+            qs.filter(value__isnull=False)
+            .annotate(
+                key=KeyTextTransform(
+                    "f", KeyTransform("1", KeyTransform("d", "value"))
+                ),
+            )
+            .values("key")
+            .annotate(count=Count("key"))
+            .order_by("count"),
+            [(None, 0), ("g", 1)],
+            operator.itemgetter("key", "count"),
+        )
+
+    def test_ordering_grouping_by_count(self):
+        qs = (
+            NullableJSONModel.objects.filter(
+                value__isnull=False,
+            )
+            .values("value__d__0")
+            .annotate(count=Count("value__d__0"))
+            .order_by("count")
+        )
+        self.assertQuerysetEqual(qs, [0, 1], operator.itemgetter("count"))
+
+    def test_order_grouping_custom_decoder(self):
+        NullableJSONModel.objects.create(value_custom={"a": "b"})
+        qs = NullableJSONModel.objects.filter(value_custom__isnull=False)
+        self.assertSequenceEqual(
+            qs.values(
+                "value_custom__a",
+            )
+            .annotate(
+                count=Count("id"),
+            )
+            .order_by("value_custom__a"),
+            [{"value_custom__a": "b", "count": 1}],
+        )
+
+    def test_key_transform_raw_expression(self):
+        expr = RawSQL(self.raw_sql, ['''{"x": "bar"}'''])
+        self.assertSequenceEqual(
+            NullableJSONModel.objects.filter(value__foo=KeyTransform("x", expr)),
+            [self.objs[7]],
+        )
+
+    def test_nested_key_transform_raw_expression(self):
+        expr = RawSQL(self.raw_sql, ['''{"x": {"y": "bar"}}'''])
+        self.assertSequenceEqual(
+            NullableJSONModel.objects.filter(
+                value__foo=KeyTransform("y", KeyTransform("x", expr))
+            ),
+            [self.objs[7]],
+        )
+
+    def test_key_transform_expression(self):
+        self.assertSequenceEqual(
+            NullableJSONModel.objects.filter(value__d__0__isnull=False)
+            .annotate(
+                key=KeyTransform("d", "value"),
+                chain=KeyTransform("0", "key"),
+                expr=KeyTransform("0", Cast("key", models.JSONField())),
+            )
+            .filter(chain=F("expr")),
+            [self.objs[4]],
+        )
+
+    def test_key_transform_annotation_expression(self):
+        obj = NullableJSONModel.objects.create(value={"d": ["e", "e"]})
+        self.assertSequenceEqual(
+            NullableJSONModel.objects.filter(value__d__0__isnull=False)
+            .annotate(
+                key=F("value__d"),
+                chain=F("key__0"),
+                expr=Cast("key", models.JSONField()),
+            )
+            .filter(chain=F("expr__1")),
+            [obj],
+        )
+
+    def test_nested_key_transform_expression(self):
+        self.assertSequenceEqual(
+            NullableJSONModel.objects.filter(value__d__0__isnull=False)
+            .annotate(
+                key=KeyTransform("d", "value"),
+                chain=KeyTransform("f", KeyTransform("1", "key")),
+                expr=KeyTransform(
+                    "f", KeyTransform("1", Cast("key", models.JSONField()))
+                ),
+            )
+            .filter(chain=F("expr")),
+            [self.objs[4]],
+        )
+
+    def test_nested_key_transform_annotation_expression(self):
+        obj = NullableJSONModel.objects.create(
+            value={"d": ["e", {"f": "g"}, {"f": "g"}]},
+        )
+        self.assertSequenceEqual(
+            NullableJSONModel.objects.filter(value__d__0__isnull=False)
+            .annotate(
+                key=F("value__d"),
+                chain=F("key__1__f"),
+                expr=Cast("key", models.JSONField()),
+            )
+            .filter(chain=F("expr__2__f")),
+            [obj],
+        )
+
+    def test_nested_key_transform_on_subquery(self):
+        self.assertSequenceEqual(
+            NullableJSONModel.objects.filter(value__d__0__isnull=False)
+            .annotate(
+                subquery_value=Subquery(
+                    NullableJSONModel.objects.filter(pk=OuterRef("pk")).values("value")
+                ),
+                key=KeyTransform("d", "subquery_value"),
+                chain=KeyTransform("f", KeyTransform("1", "key")),
+            )
+            .filter(chain="g"),
+            [self.objs[4]],
+        )
+
+    def test_expression_wrapper_key_transform(self):
+        self.assertSequenceEqual(
+            NullableJSONModel.objects.annotate(
+                wrapped=ExpressionWrapper(
+                    Value({"wrapper": "content"}), output_field=models.JSONField()
+                ),
+            )
+            .filter(wrapped__wrapper="content")
+            .order_by("pk"),
+            self.objs,
+        )
+
+    def test_has_key(self):
+        self.assertSequenceEqual(
+            NullableJSONModel.objects.filter(value__has_key="a"),
+            [self.objs[3], self.objs[4]],
+        )
+
+    def test_has_key_deep(self):
+        tests = [
+            (Q(value__baz__has_key="a"), self.objs[7]),
+            (
+                Q(value__has_key=KeyTransform("a", KeyTransform("baz", "value"))),
+                self.objs[7],
+            ),
+            (Q(value__has_key=F("value__baz__a")), self.objs[7]),
+            (
+                Q(value__has_key=KeyTransform("c", KeyTransform("baz", "value"))),
+                self.objs[7],
+            ),
+            (Q(value__has_key=F("value__baz__c")), self.objs[7]),
+            (Q(value__d__1__has_key="f"), self.objs[4]),
+            (
+                Q(
+                    value__has_key=KeyTransform(
+                        "f", KeyTransform("1", KeyTransform("d", "value"))
+                    )
+                ),
+                self.objs[4],
+            ),
+            (Q(value__has_key=F("value__d__1__f")), self.objs[4]),
+        ]
+        for condition, expected in tests:
+            with self.subTest(condition=condition):
+                self.assertSequenceEqual(
+                    NullableJSONModel.objects.filter(condition),
+                    [expected],
+                )
+
+    def test_has_key_list(self):
+        obj = NullableJSONModel.objects.create(value=[{"a": 1}, {"b": "x"}])
+        tests = [
+            Q(value__1__has_key="b"),
+            Q(value__has_key=KeyTransform("b", KeyTransform(1, "value"))),
+            Q(value__has_key=KeyTransform("b", KeyTransform("1", "value"))),
+            Q(value__has_key=F("value__1__b")),
+        ]
+        for condition in tests:
+            with self.subTest(condition=condition):
+                self.assertSequenceEqual(
+                    NullableJSONModel.objects.filter(condition),
+                    [obj],
+                )
+
+    def test_has_key_numeric_lookup(self):
+        """
+        Test has_key, has_keys, and has_any_keys lookups with numeric keys.
+        """
+        obj = NullableJSONModel.objects.create(value={"1111": "bar"})
+        queries = [
+            Q(value__has_key="1111"),
+            Q(value__has_keys=["1111"]),
+            Q(value__has_any_keys=["1111", "2222"]),
+        ]
+        for query in queries:
+            with self.subTest(query=query):
+                self.assertSequenceEqual(
+                    NullableJSONModel.objects.filter(query),
+                    [obj],
+                )
+
+    def test_has_keys(self):
+        self.assertSequenceEqual(
+            NullableJSONModel.objects.filter(value__has_keys=["a", "c", "h"]),
+            [self.objs[4]],
+        )
+
+    def test_has_any_keys(self):
+        self.assertSequenceEqual(
+            NullableJSONModel.objects.filter(value__has_any_keys=["c", "l"]),
+            [self.objs[3], self.objs[4], self.objs[6]],
+        )

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/db/models/fields/json\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 model_fields.test_jsonfield_repro
cat coverage.cover
git checkout 859a87d873ce7152af73ab851653b4e1c3ffea4c
git apply /root/pre_state.patch
