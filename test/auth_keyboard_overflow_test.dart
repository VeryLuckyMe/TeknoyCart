import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teknoycart/features/auth/views/widgets/auth_register_form.dart';

/// Regression tests for "Confirm Password cannot be typed/edited".
///
/// Cause: the password requirement hint was not reactive and changed height, and
/// text fields used the default 20 px `scrollPadding`, so after a failed submit
/// the Confirm Password field sat 34 px under the keyboard.
Finder _fieldByLabel(String label) => find.byWidgetPredicate(
      (widget) =>
          widget is TextField && widget.decoration?.labelText == label,
      description: 'TextField labelled "$label"',
    );

void main() {
  late TextEditingController firstName;
  late TextEditingController lastName;
  late TextEditingController studentId;
  late TextEditingController department;
  late TextEditingController storeName;
  late TextEditingController orgContact;
  late TextEditingController email;
  late TextEditingController password;
  late TextEditingController confirmPassword;

  setUp(() {
    firstName = TextEditingController();
    lastName = TextEditingController();
    studentId = TextEditingController();
    department = TextEditingController();
    storeName = TextEditingController();
    orgContact = TextEditingController();
    email = TextEditingController();
    password = TextEditingController();
    confirmPassword = TextEditingController();
  });

  tearDown(() {
    for (final controller in [
      firstName,
      lastName,
      studentId,
      department,
      storeName,
      orgContact,
      email,
      password,
      confirmPassword,
    ]) {
      controller.dispose();
    }
  });

  Future<GlobalKey<FormState>> pumpForm(
    WidgetTester tester, {
    double keyboardInset = 336,
  }) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    tester.view.viewInsets = FakeViewPadding(bottom: keyboardInset);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.view.resetViewInsets();
    });

    final formKey = GlobalKey<FormState>();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: AuthRegisterForm(
                firstNameController: firstName,
                lastNameController: lastName,
                studentIdController: studentId,
                departmentController: department,
                storeNameController: storeName,
                orgContactController: orgContact,
                emailController: email,
                passwordController: password,
                confirmPasswordController: confirmPassword,
                selectedRole: 'BUYER',
                selectedSellerType: 'STUDENT',
                onRoleChanged: (_) {},
                onSellerTypeChanged: (_) {},
                registerStep: 2,
                onStepChanged: (_) {},
                onValidateStep: (_) => true,
                onSubmit: () {},
                isLoading: false,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return formKey;
  }

  testWidgets('password hint updates live while typing', (tester) async {
    await pumpForm(tester);

    expect(find.text('Must be at least 12 characters'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_rounded), findsNothing);

    // No submit, no tab switch, no obscure toggle — only typing.
    await tester.enterText(_fieldByLabel('Password'), 'abcdefghijk'); // 11
    await tester.pump();
    expect(find.byIcon(Icons.check_circle_rounded), findsNothing);

    await tester.enterText(_fieldByLabel('Password'), 'abcdefghijkl'); // 12
    await tester.pump();
    expect(find.text('At least 12 characters'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
  });

  testWidgets('hint state never reflows the Confirm Password field', (tester) async {
    await pumpForm(tester);

    final before = tester.getTopLeft(_fieldByLabel('Confirm Password')).dy;

    await tester.enterText(_fieldByLabel('Password'), 'abcdefghijkl');
    await tester.pump();

    final after = tester.getTopLeft(_fieldByLabel('Confirm Password')).dy;
    expect(after, before, reason: 'the hint row must keep a fixed height');
  });

  testWidgets('text fields reserve room above the keyboard', (tester) async {
    await pumpForm(tester);

    final fields = tester.widgetList<TextField>(find.byType(TextField));
    expect(fields, isNotEmpty);
    for (final field in fields) {
      expect(
        field.scrollPadding.bottom,
        greaterThanOrEqualTo(100),
        reason: 'Confirm Password must scroll above the IME after an error line',
      );
    }
  });

  testWidgets(
      'after a failed submit the Confirm Password field can still be focused and edited',
      (tester) async {
    final formKey = await pumpForm(tester);

    await tester.enterText(_fieldByLabel('Password'), 'abc');
    await tester.enterText(_fieldByLabel('Confirm Password'), 'abc');
    await tester.pump();

    // Exactly what the "Continue" button does when the password is too short.
    expect(formKey.currentState!.validate(), isFalse);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    final confirm = _fieldByLabel('Confirm Password');
    await tester.ensureVisible(confirm);
    await tester.pumpAndSettle();

    await tester.tap(confirm);
    await tester.pumpAndSettle();
    await tester.enterText(confirm, 'abcdefghijkl');
    await tester.pumpAndSettle();

    expect(confirmPassword.text, 'abcdefghijkl');
    expect(tester.takeException(), isNull);
  });
}
