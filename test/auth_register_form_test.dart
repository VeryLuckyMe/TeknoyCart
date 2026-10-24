import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teknoycart/features/auth/views/widgets/auth_register_form.dart';

void main() {
  testWidgets('registration submit stays disabled until the consent box is checked',
      (tester) async {
    final firstName = TextEditingController();
    final lastName = TextEditingController();
    final studentId = TextEditingController();
    final department = TextEditingController();
    final storeName = TextEditingController();
    final orgContact = TextEditingController();
    final email = TextEditingController();
    final password = TextEditingController();
    final confirmPassword = TextEditingController();

    addTearDown(firstName.dispose);
    addTearDown(lastName.dispose);
    addTearDown(studentId.dispose);
    addTearDown(department.dispose);
    addTearDown(storeName.dispose);
    addTearDown(orgContact.dispose);
    addTearDown(email.dispose);
    addTearDown(password.dispose);
    addTearDown(confirmPassword.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
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
    );

    final submitFinder = find.byKey(const Key('auth-submit-btn'));
    expect(submitFinder, findsOneWidget);
    expect(tester.widget<ElevatedButton>(submitFinder).onPressed, isNull);

    await tester.tap(find.byKey(const Key('auth-terms-checkbox')));
    await tester.pump();

    expect(tester.widget<ElevatedButton>(submitFinder).onPressed, isNotNull);

    final termsLink = find.text('Terms of Student Commerce & Privacy Notice');
    await tester.ensureVisible(termsLink);
    await tester.tap(termsLink);
    await tester.pumpAndSettle();

    expect(find.text('Academic Honor Code Compliance'), findsOneWidget);
  });
}
