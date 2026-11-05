import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../utils/app_constants.dart';

class AuthService extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  UserModel? _currentUser;
  bool _isLoading = false;
  String? _errorMessage;

  UserModel? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _auth.currentUser != null;

  AuthService() {
    _initUser();
  }

  Future<void> _initUser() async {
    final firebaseUser = _auth.currentUser;
    if (firebaseUser != null) {
      await fetchUserData(firebaseUser.uid);
    }
  }

  Future<void> fetchUserData(String uid) async {
    try {
      final doc = await _firestore.collection(AppConstants.colUsers).doc(uid).get();
      if (doc.exists && doc.data() != null) {
        _currentUser = UserModel.fromMap(doc.data()!, uid);
        notifyListeners();
      }
    } catch (e) {
      _errorMessage = 'Failed to load user profile: $e';
      notifyListeners();
    }
  }

  Future<bool> register({
    required String name,
    required String email,
    required String password,
    required String role,
    String? phone,
  }) async {
    _setLoading(true);
    _errorMessage = null;

    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final uid = credential.user!.uid;
      final newUser = UserModel(
        uid: uid,
        name: name.trim(),
        email: email.trim(),
        phone: phone?.trim(),
        role: role,
        assignedBusId: null,
        createdAt: DateTime.now(),
      );

      // Save user profile with role in Firestore
      await _firestore
          .collection(AppConstants.colUsers)
          .doc(uid)
          .set(newUser.toMap());

      _currentUser = newUser;
      _setLoading(false);
      return true;
    } on FirebaseAuthException catch (e) {
      _errorMessage = _getFriendlyAuthError(e);
      _setLoading(false);
      return false;
    } catch (e) {
      _errorMessage = 'Registration error: $e';
      _setLoading(false);
      return false;
    }
  }

  Future<bool> login({required String email, required String password}) async {
    _setLoading(true);
    _errorMessage = null;

    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      await fetchUserData(credential.user!.uid);
      _setLoading(false);
      return true;
    } on FirebaseAuthException catch (e) {
      _errorMessage = _getFriendlyAuthError(e);
      _setLoading(false);
      return false;
    } catch (e) {
      _errorMessage = 'Login error: $e';
      _setLoading(false);
      return false;
    }
  }

  Future<void> logout() async {
    await _auth.signOut();
    _currentUser = null;
    notifyListeners();
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  String _getFriendlyAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No account registered with this email.';
      case 'wrong-password':
      case 'invalid-credential':
        return 'Incorrect email or password. Please try again.';
      case 'email-already-in-use':
        return 'An account already exists for this email address.';
      case 'weak-password':
        return 'The password is too weak. Please use at least 6 characters.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      default:
        return e.message ?? 'Authentication failed. Please try again.';
    }
  }
}

