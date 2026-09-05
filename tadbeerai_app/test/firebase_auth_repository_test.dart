import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter_test/flutter_test.dart';
import 'package:tadbeerai/data/repositories/firebase_auth_repository.dart';
import 'package:tadbeerai/domain/exceptions/auth_exception.dart';

class _FakeUser implements fb.User {
  _FakeUser({
    required this.uid,
    required this.email,
    this.displayName,
  });

  @override
  final String uid;

  @override
  final String? email;

  @override
  String? displayName;

  @override
  Future<void> updateDisplayName(String? name) async {
    displayName = name;
  }

  @override
  Future<void> reload() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeUserCredential implements fb.UserCredential {
  _FakeUserCredential(this._user);

  final fb.User? _user;

  @override
  fb.User? get user => _user;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeFirebaseAuth implements fb.FirebaseAuth {
  _FakeFirebaseAuth({
    this.currentUserMock,
    this.signInError,
    this.signUpError,
  });

  fb.User? currentUserMock;
  Object? signInError;
  Object? signUpError;
  bool didSignOut = false;

  @override
  fb.User? get currentUser => currentUserMock;

  @override
  Future<fb.UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    if (signInError != null) throw signInError!;
    final user = _FakeUser(
      uid: 'uid-12345',
      email: email,
      displayName: 'Tadbeer Tester',
    );
    currentUserMock = user;
    return _FakeUserCredential(user);
  }

  @override
  Future<fb.UserCredential> createUserWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    if (signUpError != null) throw signUpError!;
    final user = _FakeUser(
      uid: 'uid-new-67890',
      email: email,
      displayName: null,
    );
    currentUserMock = user;
    return _FakeUserCredential(user);
  }

  @override
  Future<fb.UserCredential> signInAnonymously() async {
    final user = _FakeUser(
      uid: 'uid-guest-999',
      email: null,
      displayName: 'Guest User',
    );
    currentUserMock = user;
    return _FakeUserCredential(user);
  }

  @override
  Future<void> sendPasswordResetEmail({
    required String email,
    fb.ActionCodeSettings? actionCodeSettings,
  }) async {}

  @override
  Future<void> confirmPasswordReset({
    required String code,
    required String newPassword,
  }) async {
    if (code != '842196') {
      throw fb.FirebaseAuthException(code: 'invalid-action-code');
    }
  }

  @override
  Future<void> signOut() async {
    didSignOut = true;
    currentUserMock = null;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FirebaseAuthRepository', () {
    test('currentUser returns null when signed out', () async {
      final fakeAuth = _FakeFirebaseAuth(currentUserMock: null);
      final repo = FirebaseAuthRepository(firebaseAuth: fakeAuth);

      expect(await repo.currentUser(), isNull);
    });

    test('currentUser maps Firebase User to domain AppUser', () async {
      final fakeUser = _FakeUser(
        uid: 'user-abc',
        email: 'investor@tadbeer.ai',
        displayName: 'Investor One',
      );
      final fakeAuth = _FakeFirebaseAuth(currentUserMock: fakeUser);
      final repo = FirebaseAuthRepository(firebaseAuth: fakeAuth);

      final user = await repo.currentUser();
      expect(user, isNotNull);
      expect(user!.id, 'user-abc');
      expect(user.email, 'investor@tadbeer.ai');
      expect(user.name, 'Investor One');
    });

    test('currentUser falls back to formatted handle when displayName is null',
        () async {
      final fakeUser = _FakeUser(
        uid: 'user-xyz',
        email: 'bilal.ahmed@tadbeer.ai',
        displayName: null,
      );
      final fakeAuth = _FakeFirebaseAuth(currentUserMock: fakeUser);
      final repo = FirebaseAuthRepository(firebaseAuth: fakeAuth);

      final user = await repo.currentUser();
      expect(user, isNotNull);
      expect(user!.name, 'Bilal Ahmed');
    });

    test('signIn returns AppUser on valid credentials', () async {
      final fakeAuth = _FakeFirebaseAuth();
      final repo = FirebaseAuthRepository(firebaseAuth: fakeAuth);

      final user = await repo.signIn(
        email: 'user@tadbeer.ai',
        password: 'validPassword123',
      );

      expect(user.id, 'uid-12345');
      expect(user.email, 'user@tadbeer.ai');
      expect(user.name, 'Tadbeer Tester');
    });

    test('signIn maps invalid-credential to friendly message', () async {
      final fakeAuth = _FakeFirebaseAuth(
        signInError: fb.FirebaseAuthException(code: 'invalid-credential'),
      );
      final repo = FirebaseAuthRepository(firebaseAuth: fakeAuth);

      expect(
        () => repo.signIn(email: 'user@tadbeer.ai', password: 'wrongPassword'),
        throwsA(isA<AuthException>().having(
          (e) => e.message,
          'message',
          'Email or password is incorrect.',
        )),
      );
    });

    test('signIn maps network-request-failed to friendly message', () async {
      final fakeAuth = _FakeFirebaseAuth(
        signInError: fb.FirebaseAuthException(code: 'network-request-failed'),
      );
      final repo = FirebaseAuthRepository(firebaseAuth: fakeAuth);

      expect(
        () => repo.signIn(email: 'user@tadbeer.ai', password: 'password123'),
        throwsA(isA<AuthException>().having(
          (e) => e.message,
          'message',
          'Unable to connect. Please check your internet connection.',
        )),
      );
    });

    test('signIn maps user-disabled to friendly message', () async {
      final fakeAuth = _FakeFirebaseAuth(
        signInError: fb.FirebaseAuthException(code: 'user-disabled'),
      );
      final repo = FirebaseAuthRepository(firebaseAuth: fakeAuth);

      expect(
        () => repo.signIn(email: 'disabled@tadbeer.ai', password: 'password'),
        throwsA(isA<AuthException>().having(
          (e) => e.message,
          'message',
          'Your account is currently unavailable.',
        )),
      );
    });

    test('signUp creates account, sets displayName, and returns AppUser',
        () async {
      final fakeAuth = _FakeFirebaseAuth();
      final repo = FirebaseAuthRepository(firebaseAuth: fakeAuth);

      final user = await repo.signUp(
        name: 'Saad Malik',
        email: 'saad@tadbeer.ai',
        password: 'securePassword123',
      );

      expect(user.id, 'uid-new-67890');
      expect(user.email, 'saad@tadbeer.ai');
      expect(user.name, 'Saad Malik');
    });

    test('signUp maps email-already-in-use to friendly message', () async {
      final fakeAuth = _FakeFirebaseAuth(
        signUpError: fb.FirebaseAuthException(code: 'email-already-in-use'),
      );
      final repo = FirebaseAuthRepository(firebaseAuth: fakeAuth);

      expect(
        () => repo.signUp(
          name: 'Existing User',
          email: 'existing@tadbeer.ai',
          password: 'securePassword123',
        ),
        throwsA(isA<AuthException>().having(
          (e) => e.message,
          'message',
          'An account already exists with this email address.',
        )),
      );
    });

    test('signUp maps weak-password to friendly message', () async {
      final fakeAuth = _FakeFirebaseAuth(
        signUpError: fb.FirebaseAuthException(code: 'weak-password'),
      );
      final repo = FirebaseAuthRepository(firebaseAuth: fakeAuth);

      expect(
        () => repo.signUp(
          name: 'New User',
          email: 'new@tadbeer.ai',
          password: '123',
        ),
        throwsA(isA<AuthException>().having(
          (e) => e.message,
          'message',
          'Password is too weak. Please choose a stronger password.',
        )),
      );
    });

    test('signInAsGuest creates anonymous session with guest properties',
        () async {
      final fakeAuth = _FakeFirebaseAuth();
      final repo = FirebaseAuthRepository(firebaseAuth: fakeAuth);

      final guestUser = await repo.signInAsGuest();
      expect(guestUser.id, 'uid-guest-999');
      expect(guestUser.name, 'Guest User');
      expect(guestUser.email, 'guest@tadbeer.ai');
      expect(guestUser.isGuest, isTrue);
    });

    test('signOut clears session', () async {
      final fakeAuth = _FakeFirebaseAuth(
        currentUserMock: _FakeUser(
          uid: 'uid-active',
          email: 'active@tadbeer.ai',
          displayName: 'Active',
        ),
      );
      final repo = FirebaseAuthRepository(firebaseAuth: fakeAuth);

      expect(await repo.currentUser(), isNotNull);
      await repo.signOut();
      expect(fakeAuth.didSignOut, isTrue);
      expect(await repo.currentUser(), isNull);
    });

    test(
        'sendPasswordResetCode and resetPasswordWithCode succeed with valid code',
        () async {
      final fakeAuth = _FakeFirebaseAuth();
      final repo = FirebaseAuthRepository(firebaseAuth: fakeAuth);

      await repo.sendPasswordResetCode(email: 'user@tadbeer.ai');

      final success = await repo.resetPasswordWithCode(
        email: 'user@tadbeer.ai',
        code: '842196',
        newPassword: 'newSecretPass123',
      );
      expect(success, isTrue);

      final fail = await repo.resetPasswordWithCode(
        email: 'user@tadbeer.ai',
        code: '000000',
        newPassword: 'newSecretPass123',
      );
      expect(fail, isFalse);
    });
  });

  group('AuthException.fromFirebaseCode', () {
    test('maps all specified Firebase error codes without technical leak', () {
      expect(AuthException.fromFirebaseCode('invalid-credential').message,
          'Email or password is incorrect.');
      expect(AuthException.fromFirebaseCode('user-not-found').message,
          'Email or password is incorrect.');
      expect(AuthException.fromFirebaseCode('wrong-password').message,
          'Email or password is incorrect.');
      expect(AuthException.fromFirebaseCode('invalid-email').message,
          'Please enter a valid email address.');
      expect(AuthException.fromFirebaseCode('email-already-in-use').message,
          'An account already exists with this email address.');
      expect(AuthException.fromFirebaseCode('weak-password').message,
          'Password is too weak. Please choose a stronger password.');
      expect(AuthException.fromFirebaseCode('user-disabled').message,
          'Your account is currently unavailable.');
      expect(AuthException.fromFirebaseCode('network-request-failed').message,
          'Unable to connect. Please check your internet connection.');
      expect(AuthException.fromFirebaseCode('too-many-requests').message,
          'Too many attempts. Please try again later.');
      expect(AuthException.fromFirebaseCode('unexpected-error').message,
          'Something went wrong. Please try again.');
    });
  });
}
