#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 76e37513e22f4d9a01c7f15eee36fe44388e6670 >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 76e37513e22f4d9a01c7f15eee36fe44388e6670
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/get_or_create/tests.py b/get_or_create/tests.py
new file mode 100644
index 0000000000..ab81fee044
--- /dev/null
+++ b/get_or_create/tests.py
@@ -0,0 +1,716 @@
+import time
+import traceback
+from datetime import date, datetime, timedelta
+from threading import Thread
+
+from django.core.exceptions import FieldError
+from django.db import DatabaseError, IntegrityError, connection
+from django.test import TestCase, TransactionTestCase, skipUnlessDBFeature
+from django.test.utils import CaptureQueriesContext
+from django.utils.functional import lazy
+
+from .models import (
+    Author,
+    Book,
+    DefaultPerson,
+    Journalist,
+    ManualPrimaryKeyTest,
+    Person,
+    Profile,
+    Publisher,
+    Tag,
+    Thing,
+)
+
+
+class GetOrCreateTests(TestCase):
+    @classmethod
+    def setUpTestData(cls):
+        Person.objects.create(
+            first_name="John", last_name="Lennon", birthday=date(1940, 10, 9)
+        )
+
+    def test_get_or_create_method_with_get(self):
+        created = Person.objects.get_or_create(
+            first_name="John",
+            last_name="Lennon",
+            defaults={"birthday": date(1940, 10, 9)},
+        )[1]
+        self.assertFalse(created)
+        self.assertEqual(Person.objects.count(), 1)
+
+    def test_get_or_create_method_with_create(self):
+        created = Person.objects.get_or_create(
+            first_name="George",
+            last_name="Harrison",
+            defaults={"birthday": date(1943, 2, 25)},
+        )[1]
+        self.assertTrue(created)
+        self.assertEqual(Person.objects.count(), 2)
+
+    def test_get_or_create_redundant_instance(self):
+        """
+        If we execute the exact same statement twice, the second time,
+        it won't create a Person.
+        """
+        Person.objects.get_or_create(
+            first_name="George",
+            last_name="Harrison",
+            defaults={"birthday": date(1943, 2, 25)},
+        )
+        created = Person.objects.get_or_create(
+            first_name="George",
+            last_name="Harrison",
+            defaults={"birthday": date(1943, 2, 25)},
+        )[1]
+
+        self.assertFalse(created)
+        self.assertEqual(Person.objects.count(), 2)
+
+    def test_get_or_create_invalid_params(self):
+        """
+        If you don't specify a value or default value for all required
+        fields, you will get an error.
+        """
+        with self.assertRaises(IntegrityError):
+            Person.objects.get_or_create(first_name="Tom", last_name="Smith")
+
+    def test_get_or_create_with_pk_property(self):
+        """
+        Using the pk property of a model is allowed.
+        """
+        Thing.objects.get_or_create(pk=1)
+
+    def test_get_or_create_with_model_property_defaults(self):
+        """Using a property with a setter implemented is allowed."""
+        t, _ = Thing.objects.get_or_create(
+            defaults={"capitalized_name_property": "annie"}, pk=1
+        )
+        self.assertEqual(t.name, "Annie")
+
+    def test_get_or_create_on_related_manager(self):
+        p = Publisher.objects.create(name="Acme Publishing", num_awards=1)
+        # Create a book through the publisher.
+        book, created = p.books.get_or_create(name="The Book of Ed & Fred")
+        self.assertTrue(created)
+        # The publisher should have one book.
+        self.assertEqual(p.books.count(), 1)
+
+        # Try get_or_create again, this time nothing should be created.
+        book, created = p.books.get_or_create(name="The Book of Ed & Fred")
+        self.assertFalse(created)
+        # And the publisher should still have one book.
+        self.assertEqual(p.books.count(), 1)
+
+        # Add an author to the book.
+        ed, created = book.authors.get_or_create(name="Ed")
+        self.assertTrue(created)
+        # The book should have one author.
+        self.assertEqual(book.authors.count(), 1)
+
+        # Try get_or_create again, this time nothing should be created.
+        ed, created = book.authors.get_or_create(name="Ed")
+        self.assertFalse(created)
+        # And the book should still have one author.
+        self.assertEqual(book.authors.count(), 1)
+
+        # Add a second author to the book.
+        fred, created = book.authors.get_or_create(name="Fred")
+        self.assertTrue(created)
+
+        # The book should have two authors now.
+        self.assertEqual(book.authors.count(), 2)
+
+        # Create an Author not tied to any books.
+        Author.objects.create(name="Ted")
+
+        # There should be three Authors in total. The book object should have two.
+        self.assertEqual(Author.objects.count(), 3)
+        self.assertEqual(book.authors.count(), 2)
+
+        # Try creating a book through an author.
+        _, created = ed.books.get_or_create(name="Ed's Recipes", publisher=p)
+        self.assertTrue(created)
+
+        # Now Ed has two Books, Fred just one.
+        self.assertEqual(ed.books.count(), 2)
+        self.assertEqual(fred.books.count(), 1)
+
+        # Use the publisher's primary key value instead of a model instance.
+        _, created = ed.books.get_or_create(
+            name="The Great Book of Ed", publisher_id=p.id
+        )
+        self.assertTrue(created)
+
+        # Try get_or_create again, this time nothing should be created.
+        _, created = ed.books.get_or_create(
+            name="The Great Book of Ed", publisher_id=p.id
+        )
+        self.assertFalse(created)
+
+        # The publisher should have three books.
+        self.assertEqual(p.books.count(), 3)
+
+    def test_defaults_exact(self):
+        """
+        If you have a field named defaults and want to use it as an exact
+        lookup, you need to use 'defaults__exact'.
+        """
+        obj, created = Person.objects.get_or_create(
+            first_name="George",
+            last_name="Harrison",
+            defaults__exact="testing",
+            defaults={
+                "birthday": date(1943, 2, 25),
+                "defaults": "testing",
+            },
+        )
+        self.assertTrue(created)
+        self.assertEqual(obj.defaults, "testing")
+        obj2, created = Person.objects.get_or_create(
+            first_name="George",
+            last_name="Harrison",
+            defaults__exact="testing",
+            defaults={
+                "birthday": date(1943, 2, 25),
+                "defaults": "testing",
+            },
+        )
+        self.assertFalse(created)
+        self.assertEqual(obj, obj2)
+
+    def test_callable_defaults(self):
+        """
+        Callables in `defaults` are evaluated if the instance is created.
+        """
+        obj, created = Person.objects.get_or_create(
+            first_name="George",
+            defaults={"last_name": "Harrison", "birthday": lambda: date(1943, 2, 25)},
+        )
+        self.assertTrue(created)
+        self.assertEqual(date(1943, 2, 25), obj.birthday)
+
+    def test_callable_defaults_not_called(self):
+        def raise_exception():
+            raise AssertionError
+
+        obj, created = Person.objects.get_or_create(
+            first_name="John",
+            last_name="Lennon",
+            defaults={"birthday": lambda: raise_exception()},
+        )
+
+    def test_defaults_not_evaluated_unless_needed(self):
+        """`defaults` aren't evaluated if the instance isn't created."""
+
+        def raise_exception():
+            raise AssertionError
+
+        obj, created = Person.objects.get_or_create(
+            first_name="John",
+            defaults=lazy(raise_exception, object)(),
+        )
+        self.assertFalse(created)
+
+
+class GetOrCreateTestsWithManualPKs(TestCase):
+    @classmethod
+    def setUpTestData(cls):
+        ManualPrimaryKeyTest.objects.create(id=1, data="Original")
+
+    def test_create_with_duplicate_primary_key(self):
+        """
+        If you specify an existing primary key, but different other fields,
+        then you will get an error and data will not be updated.
+        """
+        with self.assertRaises(IntegrityError):
+            ManualPrimaryKeyTest.objects.get_or_create(id=1, data="Different")
+        self.assertEqual(ManualPrimaryKeyTest.objects.get(id=1).data, "Original")
+
+    def test_get_or_create_raises_IntegrityError_plus_traceback(self):
+        """
+        get_or_create should raise IntegrityErrors with the full traceback.
+        This is tested by checking that a known method call is in the traceback.
+        We cannot use assertRaises here because we need to inspect
+        the actual traceback. Refs #16340.
+        """
+        try:
+            ManualPrimaryKeyTest.objects.get_or_create(id=1, data="Different")
+        except IntegrityError:
+            formatted_traceback = traceback.format_exc()
+            self.assertIn("obj.save", formatted_traceback)
+
+    def test_savepoint_rollback(self):
+        """
+        The database connection is still usable after a DatabaseError in
+        get_or_create() (#20463).
+        """
+        Tag.objects.create(text="foo")
+        with self.assertRaises(DatabaseError):
+            # pk 123456789 doesn't exist, so the tag object will be created.
+            # Saving triggers a unique constraint violation on 'text'.
+            Tag.objects.get_or_create(pk=123456789, defaults={"text": "foo"})
+        # Tag objects can be created after the error.
+        Tag.objects.create(text="bar")
+
+    def test_get_or_create_empty(self):
+        """
+        If all the attributes on a model have defaults, get_or_create() doesn't
+        require any arguments.
+        """
+        DefaultPerson.objects.get_or_create()
+
+
+class GetOrCreateTransactionTests(TransactionTestCase):
+
+    available_apps = ["get_or_create"]
+
+    def test_get_or_create_integrityerror(self):
+        """
+        Regression test for #15117. Requires a TransactionTestCase on
+        databases that delay integrity checks until the end of transactions,
+        otherwise the exception is never raised.
+        """
+        try:
+            Profile.objects.get_or_create(person=Person(id=1))
+        except IntegrityError:
+            pass
+        else:
+            self.skipTest("This backend does not support integrity checks.")
+
+
+class GetOrCreateThroughManyToMany(TestCase):
+    def test_get_get_or_create(self):
+        tag = Tag.objects.create(text="foo")
+        a_thing = Thing.objects.create(name="a")
+        a_thing.tags.add(tag)
+        obj, created = a_thing.tags.get_or_create(text="foo")
+
+        self.assertFalse(created)
+        self.assertEqual(obj.pk, tag.pk)
+
+    def test_create_get_or_create(self):
+        a_thing = Thing.objects.create(name="a")
+        obj, created = a_thing.tags.get_or_create(text="foo")
+
+        self.assertTrue(created)
+        self.assertEqual(obj.text, "foo")
+        self.assertIn(obj, a_thing.tags.all())
+
+    def test_something(self):
+        Tag.objects.create(text="foo")
+        a_thing = Thing.objects.create(name="a")
+        with self.assertRaises(IntegrityError):
+            a_thing.tags.get_or_create(text="foo")
+
+
+class UpdateOrCreateTests(TestCase):
+    def test_update(self):
+        Person.objects.create(
+            first_name="John", last_name="Lennon", birthday=date(1940, 10, 9)
+        )
+        p, created = Person.objects.update_or_create(
+            first_name="John",
+            last_name="Lennon",
+            defaults={"birthday": date(1940, 10, 10)},
+        )
+        self.assertFalse(created)
+        self.assertEqual(p.first_name, "John")
+        self.assertEqual(p.last_name, "Lennon")
+        self.assertEqual(p.birthday, date(1940, 10, 10))
+
+    def test_create(self):
+        p, created = Person.objects.update_or_create(
+            first_name="John",
+            last_name="Lennon",
+            defaults={"birthday": date(1940, 10, 10)},
+        )
+        self.assertTrue(created)
+        self.assertEqual(p.first_name, "John")
+        self.assertEqual(p.last_name, "Lennon")
+        self.assertEqual(p.birthday, date(1940, 10, 10))
+
+    def test_create_twice(self):
+        params = {
+            "first_name": "John",
+            "last_name": "Lennon",
+            "birthday": date(1940, 10, 10),
+        }
+        Person.objects.update_or_create(**params)
+        # If we execute the exact same statement, it won't create a Person.
+        p, created = Person.objects.update_or_create(**params)
+        self.assertFalse(created)
+
+    def test_integrity(self):
+        """
+        If you don't specify a value or default value for all required
+        fields, you will get an error.
+        """
+        with self.assertRaises(IntegrityError):
+            Person.objects.update_or_create(first_name="Tom", last_name="Smith")
+
+    def test_manual_primary_key_test(self):
+        """
+        If you specify an existing primary key, but different other fields,
+        then you will get an error and data will not be updated.
+        """
+        ManualPrimaryKeyTest.objects.create(id=1, data="Original")
+        with self.assertRaises(IntegrityError):
+            ManualPrimaryKeyTest.objects.update_or_create(id=1, data="Different")
+        self.assertEqual(ManualPrimaryKeyTest.objects.get(id=1).data, "Original")
+
+    def test_with_pk_property(self):
+        """
+        Using the pk property of a model is allowed.
+        """
+        Thing.objects.update_or_create(pk=1)
+
+    def test_update_or_create_with_model_property_defaults(self):
+        """Using a property with a setter implemented is allowed."""
+        t, _ = Thing.objects.update_or_create(
+            defaults={"capitalized_name_property": "annie"}, pk=1
+        )
+        self.assertEqual(t.name, "Annie")
+
+    def test_error_contains_full_traceback(self):
+        """
+        update_or_create should raise IntegrityErrors with the full traceback.
+        This is tested by checking that a known method call is in the traceback.
+        We cannot use assertRaises/assertRaises here because we need to inspect
+        the actual traceback. Refs #16340.
+        """
+        try:
+            ManualPrimaryKeyTest.objects.update_or_create(id=1, data="Different")
+        except IntegrityError:
+            formatted_traceback = traceback.format_exc()
+            self.assertIn("obj.save", formatted_traceback)
+
+    def test_create_with_related_manager(self):
+        """
+        Should be able to use update_or_create from the related manager to
+        create a book. Refs #23611.
+        """
+        p = Publisher.objects.create(name="Acme Publishing", num_awards=1)
+        book, created = p.books.update_or_create(name="The Book of Ed & Fred")
+        self.assertTrue(created)
+        self.assertEqual(p.books.count(), 1)
+
+    def test_update_with_related_manager(self):
+        """
+        Should be able to use update_or_create from the related manager to
+        update a book. Refs #23611.
+        """
+        p = Publisher.objects.create(name="Acme Publishing", num_awards=1)
+        book = Book.objects.create(name="The Book of Ed & Fred", publisher=p)
+        self.assertEqual(p.books.count(), 1)
+        name = "The Book of Django"
+        book, created = p.books.update_or_create(defaults={"name": name}, id=book.id)
+        self.assertFalse(created)
+        self.assertEqual(book.name, name)
+        self.assertEqual(p.books.count(), 1)
+
+    def test_create_with_many(self):
+        """
+        Should be able to use update_or_create from the m2m related manager to
+        create a book. Refs #23611.
+        """
+        p = Publisher.objects.create(name="Acme Publishing", num_awards=1)
+        author = Author.objects.create(name="Ted")
+        book, created = author.books.update_or_create(
+            name="The Book of Ed & Fred", publisher=p
+        )
+        self.assertTrue(created)
+        self.assertEqual(author.books.count(), 1)
+
+    def test_update_with_many(self):
+        """
+        Should be able to use update_or_create from the m2m related manager to
+        update a book. Refs #23611.
+        """
+        p = Publisher.objects.create(name="Acme Publishing", num_awards=1)
+        author = Author.objects.create(name="Ted")
+        book = Book.objects.create(name="The Book of Ed & Fred", publisher=p)
+        book.authors.add(author)
+        self.assertEqual(author.books.count(), 1)
+        name = "The Book of Django"
+        book, created = author.books.update_or_create(
+            defaults={"name": name}, id=book.id
+        )
+        self.assertFalse(created)
+        self.assertEqual(book.name, name)
+        self.assertEqual(author.books.count(), 1)
+
+    def test_defaults_exact(self):
+        """
+        If you have a field named defaults and want to use it as an exact
+        lookup, you need to use 'defaults__exact'.
+        """
+        obj, created = Person.objects.update_or_create(
+            first_name="George",
+            last_name="Harrison",
+            defaults__exact="testing",
+            defaults={
+                "birthday": date(1943, 2, 25),
+                "defaults": "testing",
+            },
+        )
+        self.assertTrue(created)
+        self.assertEqual(obj.defaults, "testing")
+        obj, created = Person.objects.update_or_create(
+            first_name="George",
+            last_name="Harrison",
+            defaults__exact="testing",
+            defaults={
+                "birthday": date(1943, 2, 25),
+                "defaults": "another testing",
+            },
+        )
+        self.assertFalse(created)
+        self.assertEqual(obj.defaults, "another testing")
+
+    def test_create_callable_default(self):
+        obj, created = Person.objects.update_or_create(
+            first_name="George",
+            last_name="Harrison",
+            defaults={"birthday": lambda: date(1943, 2, 25)},
+        )
+        self.assertIs(created, True)
+        self.assertEqual(obj.birthday, date(1943, 2, 25))
+
+    def test_update_callable_default(self):
+        Person.objects.update_or_create(
+            first_name="George",
+            last_name="Harrison",
+            birthday=date(1942, 2, 25),
+        )
+        obj, created = Person.objects.update_or_create(
+            first_name="George",
+            defaults={"last_name": lambda: "NotHarrison"},
+        )
+        self.assertIs(created, False)
+        self.assertEqual(obj.last_name, "NotHarrison")
+
+    def test_defaults_not_evaluated_unless_needed(self):
+        """`defaults` aren't evaluated if the instance isn't created."""
+        Person.objects.create(
+            first_name="John", last_name="Lennon", birthday=date(1940, 10, 9)
+        )
+
+        def raise_exception():
+            raise AssertionError
+
+        obj, created = Person.objects.update_or_create(
+            first_name="John",
+            last_name="Lennon",
+            defaults=lazy(raise_exception, object)(),
+        )
+        self.assertFalse(created)
+
+    def test_update_fields_and_pre_save(self):
+        p, _ = Journalist.objects.update_or_create(
+            name="John", defaults={"sex": "M", "company": "The Times"}
+        )
+        self.assertEqual(p.company, "The Times")
+
+        p, _ = Journalist.objects.update_or_create(
+            name="John", defaults={"company": "The Sun"}
+        )
+        self.assertEqual(p.company, "The Sun")
+
+    def test_update_fields_and_pre_save_inheritance(self):
+        class ChildJournalist(Journalist):
+            class Meta:
+                proxy = True
+
+        p, _ = ChildJournalist.objects.update_or_create(
+            name="John", defaults={"sex": "M", "company": "The Times"}
+        )
+        self.assertEqual(p.company, "The Times")
+
+        p, _ = ChildJournalist.objects.update_or_create(
+            name="John", defaults={"company": "The Sun"}
+        )
+        self.assertEqual(p.company, "The Sun")
+
+    def test_update_or_create_on_related_manager_with_through_defaults(self):
+        p = Publisher.objects.create(name="Acme Publishing", num_awards=1)
+        author = Author.objects.create(name="Ted")
+        msg = (
+            "update_or_create() got an unexpected keyword argument "
+            "'through_defaults'"
+        )
+        with self.assertRaisesMessage(TypeError, msg):
+            author.books.update_or_create(
+                name="The Book of Ed & Fred",
+                publisher=p,
+                through_defaults={"is_bestseller": True},
+            )
+
+
+class ConcurrencyTests(TransactionTestCase):
+
+    available_apps = ["get_or_create"]
+
+    def test_concurrent_get_or_create(self):
+        """
+        Concurrent get_or_create() calls don't result in a race condition.
+        """
+        # This is a sad state of affairs. The test is not really testing
+        # anything other than the fact that the DB is in a consistent
+        # state after the transaction. The test is not concurrent in any
+        # way. The DB state is checked only after both threads have finished.
+        threads = []
+        for i in range(2):
+            thread = Thread(
+                target=Person.objects.get_or_create,
+                kwargs={
+                    "first_name": "Concurrent",
+                    "last_name": "Person",
+                    "defaults": {"birthday": date(1943, 2, 25)},
+                },
+            )
+            threads.append(thread)
+            thread.start()
+        for thread in threads:
+            thread.join()
+        self.assertEqual(
+            Person.objects.filter(
+                first_name="Concurrent", last_name="Person"
+            ).count(),
+            1,
+        )
+
+    def test_get_or_create_duplicate_custom_pk(self):
+        """
+        IntegrityError is raised when get_or_create fails to create a
+        record due to a duplicate custom primary key.
+        """
+
+
+        class ThreadWithExc(Thread):
+            def run(self):
+                self.exc = None
+                try:
+                    super().run()
+                except Exception as e:
+                    self.exc = e
+
+        threads = []
+        for i in range(2):
+            thread = ThreadWithExc(
+                target=ManualPrimaryKeyTest.objects.get_or_create,
+                kwargs={"id": i, "data": "thread-data"},
+            )
+            threads.append(thread)
+            thread.start()
+        for thread in threads:
+            thread.join()
+            if thread.exc:
+                raise thread.exc
+
+    @skipUnlessDBFeature("has_select_for_update")
+    def test_concurrent_update_or_create(self):
+        """
+        Concurrent update_or_create() calls don't result in a race
+        condition.
+        """
+        person, _ = Person.objects.update_or_create(
+            first_name="Concurrent",
+            last_name="Person",
+            defaults={"birthday": date(1943, 2, 25)},
+        )
+        threads = []
+        for i in range(5):
+            thread = Thread(
+                target=Person.objects.update_or_create,
+                kwargs={
+                    "pk": person.pk,
+                    "defaults": {"birthday": date(1943, 2, 25) + timedelta(days=i)},
+                },
+            )
+            threads.append(thread)
+        for thread in threads:
+            # Stagger the threads to increase the chance of a race condition.
+            thread.start()
+            time.sleep(0.01)
+        for thread in threads:
+            thread.join()
+        self.assertEqual(
+            Person.objects.filter(
+                first_name="Concurrent", last_name="Person"
+            ).count(),
+            1,
+        )
+
+
+class FieldErrorTests(TestCase):
+    def test_field_error(self):
+        """
+        FieldError is raised if a keyword argument isn't a field in the model.
+        """
+        with self.assertRaisesMessage(
+            FieldError, "Invalid field name(s) for model Person: 'firstname'."
+        ):
+            Person.objects.get_or_create(firstname="John")
+        with self.assertRaisesMessage(
+            FieldError, "Invalid field name(s) for model Person: 'firstname'."
+        ):
+            Person.objects.update_or_create(firstname="John")
+
+
+class SelectRelatedTests(TestCase):
+    @classmethod
+    def setUpTestData(cls):
+        cls.person = Person.objects.create(
+            first_name="John", last_name="Lennon", birthday=date(1940, 10, 9)
+        )
+        cls.profile = Profile.objects.create(person=cls.person)
+
+    def test_get_or_create(self):
+        with CaptureQueriesContext(connection) as queries:
+            profile, created = Profile.objects.select_related("person").get_or_create(
+                person=self.person
+            )
+        self.assertFalse(created)
+        self.assertEqual(len(queries), 1)
+        self.assertEqual(profile, self.profile)
+        with self.assertNumQueries(0):
+            self.assertEqual(profile.person, self.person)
+
+    def test_update_or_create(self):
+        with CaptureQueriesContext(connection) as queries:
+            (
+                profile,
+                created,
+            ) = Profile.objects.select_related("person").update_or_create(
+                person=self.person
+            )
+        self.assertFalse(created)
+        # One query for select_for_update(), and one for the update.
+        self.assertEqual(len(queries), 2)
+        self.assertEqual(profile, self.profile)
+        with self.assertNumQueries(0):
+            self.assertEqual(profile.person, self.person)
+
+class AsyncRelatedManagerTests(TestCase):
+    async def test_acreate_on_many_to_many_manager(self):
+        """
+        acreate() on a ManyToMany related manager should create the object
+        and the relationship.
+        """
+        # Use unique names to avoid collisions with other tests.
+        publisher = await Publisher.objects.acreate(
+            name="Async M2M Test Publisher", num_awards=5
+        )
+        book = await Book.objects.acreate(
+            name="Async M2M Test Book", publisher=publisher
+        )
+
+        # Before the fix, this calls QuerySet.acreate(), which creates an
+        # Author object but does not create the M2M relationship with the book.
+        author = await book.authors.acreate(name="Async M2M Test Author")
+
+        # This assertion will fail before the fix, because the author has not
+        # been added to the book's authors set. After the patch, the
+        # relationship will be correctly created, and the assertion will pass.
+        self.assertTrue(await book.authors.filter(pk=author.pk).aexists())
\ No newline at end of file

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/contrib/contenttypes/fields\.py|django/db/models/fields/related_descriptors\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 get_or_create.tests
cat coverage.cover
git checkout 76e37513e22f4d9a01c7f15eee36fe44388e6670
git apply /root/pre_state.patch
