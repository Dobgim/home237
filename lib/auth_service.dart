import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'main.dart';
import 'home_page.dart';

enum UserRole { tenant, landlord, admin, none }

class AuthService extends ChangeNotifier {
  StreamSubscription<DocumentSnapshot>? _userDocSubscription;
  bool _isLoggedIn = false;
  String? _userId;
  String? _userEmail;
  String? _userName;
  UserRole _userRole = UserRole.none;
  bool _isNewUser = false;
  bool _hasSeenWelcome = true; // Default to true so we don't flash popup on slow loads
  String? _profileImage;
  String _subscriptionStatus = 'free'; // 'free' or 'premium'
  DateTime? _subscriptionExpiry;
  bool _isEmailVerified = false;
  String? _lastError;
  bool get isEmailVerified => _isEmailVerified;
  
  bool get isLoggedIn => _isLoggedIn;
  String? get userId => _userId;
  String? get userEmail => _userEmail;
  String? get userName => _userName;
  UserRole get userRole => _userRole;
  bool get isNewUser => _isNewUser;
  String? get profileImage => _profileImage;
  bool get hasSeenWelcome => _hasSeenWelcome;
  String get subscriptionStatus => _subscriptionStatus;
  DateTime? get subscriptionExpiry => _subscriptionExpiry;
  bool get isPremium => _subscriptionStatus == 'premium';
  bool get hasSelectedRole => _userRole != UserRole.none;
  String? get lastError => _lastError;

  bool checkAuth() {
    return _isLoggedIn;
  }

  /// Checks if the email is in the global banned_users list
  Future<bool> _isEmailBanned(String email) async {
    try {
      final query = await FirebaseFirestore.instance
          .collection('banned_users')
          .where('email', isEqualTo: email.toLowerCase().trim())
          .limit(1)
          .get();
      return query.docs.isNotEmpty;
    } catch (e) {
      print('Error checking banned status: $e');
      return false; // Fail open if Firestore is temporarily down, or handle differently
    }
  }

  /// Starts listening to the current user's document.
  /// If the document is deleted (e.g., by an admin), forces an immediate sign-out.
  void _startUserListener(String uid) {
    _userDocSubscription?.cancel();
    _userDocSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .snapshots()
        .listen((snapshot) {
      if (!snapshot.exists && _isLoggedIn) {
        print('🚨 User document was deleted! Forcing immediate sign-out.');
        signOut(forceNavigateHome: true);
      }
    });
  }

  Future<bool> signIn(String email, String password) async {
    try {
      if (await _isEmailBanned(email)) {
        _lastError = 'This account has been permanently suspended.';
        return false;
      }

      UserCredential userCredential = await FirebaseAuth.instance
          .signInWithEmailAndPassword(email: email, password: password);

      final uid = userCredential.user!.uid;

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();

      if (userDoc.exists) {
        final data = userDoc.data()!;
        _userId = uid;
        _userEmail = data['email'] ?? email;
        _userName = data['name'] ?? email.split('@')[0];
        _profileImage = data['profileImage'];
        _subscriptionStatus = data['subscriptionStatus'] ?? 'free';
        _subscriptionExpiry = data['subscriptionExpiry'] != null 
            ? (data['subscriptionExpiry'] as Timestamp).toDate() 
            : null;

        final roleStr = data['role'] ?? 'none';
        print('🔍 DEBUG: User role from Firestore: $roleStr');
        
        // Fresh re-verification check
        await refreshUserStatus();
        
        // SYNC: Update Firestore emailVerified if it's currently false but Auth says it is true
        final isAuthVerified = userCredential.user?.emailVerified ?? false;
        final isDocVerified = data['emailVerified'] ?? false;
        
        if (isAuthVerified && !isDocVerified) {
          try {
            await FirebaseFirestore.instance
                .collection('users')
                .doc(uid)
                .update({'emailVerified': true});
            print('✅ Sync: Firestore emailVerified updated to true');
          } catch (syncError) {
            print('❌ Sync error: $syncError');
          }
        }

        if (roleStr == 'tenant') {
          _userRole = UserRole.tenant;
        } else if (roleStr == 'landlord') {
          _userRole = UserRole.landlord;
        } else if (roleStr == 'admin') {
          _userRole = UserRole.admin;
        } else {
          _userRole = UserRole.none;
        }
        print('🔍 DEBUG: UserRole enum set to: $_userRole');

        _isLoggedIn = true;
        _isNewUser = false;
        _hasSeenWelcome = data['hasSeenWelcome'] ?? true;
        notifyListeners();
        
        _startUserListener(uid); // Start real-time deletion listener
        return true;
      } else {
        print('❌ User document not found in Firestore');
        return false;
      }
    } catch (e) {
      print('Signin error: $e');
      return false;
    }
  }

  Future<String?> signUp(String name, String email, String password) async {
    try {
      if (await _isEmailBanned(email)) {
        return 'This email address is restricted and cannot be used.';
      }

      UserCredential userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: password);

      await FirebaseFirestore.instance
          .collection('users')
          .doc(userCredential.user!.uid)
          .set({
        'name': name,
        'email': email,
        'createdAt': DateTime.now(),
        'role': 'none',
        'subscriptionStatus': 'free',
      });

      _isLoggedIn = true;
      _userEmail = email;
      _userName = name;
      _userId = userCredential.user!.uid;
      _isNewUser = true;
      _userRole = UserRole.none;
      notifyListeners();

      _startUserListener(userCredential.user!.uid); // Start real-time deletion listener
      return null; // Success
    } on FirebaseAuthException catch (e) {
      print('Signup error: ${e.message}');
      return e.message ?? 'An unknown error occurred';
    } catch (e) {
      print('Signup error: $e');
      return 'An unexpected error occurred: $e';
    }
  }

  Future<bool> signInWithGoogle({UserRole? defaultRole}) async {
    _lastError = null;
    try {
      // Force account selection by signing out first
      await GoogleSignIn().signOut();
      
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) {
        _lastError = 'Sign-in was canceled by the user.';
        return false;
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
      final User? user = userCredential.user;

      if (user != null) {
        if (await _isEmailBanned(user.email ?? '')) {
          _lastError = 'This account has been permanently suspended.';
          await FirebaseAuth.instance.signOut();
          await GoogleSignIn().signOut();
          return false;
        }

        final uid = user.uid;
        final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();

        if (userDoc.exists) {
          final data = userDoc.data()!;
          _userId = uid;
          _userEmail = data['email'] ?? user.email;
          _userName = data['name'] ?? user.displayName ?? user.email!.split('@')[0];
          _profileImage = data['profileImage'] ?? user.photoURL;
          _subscriptionStatus = data['subscriptionStatus'] ?? 'free';
          _subscriptionExpiry = data['subscriptionExpiry'] != null 
              ? (data['subscriptionExpiry'] as Timestamp).toDate() 
              : null;

          final roleStr = data['role'] ?? 'none';
          
          if (roleStr == 'tenant') {
            _userRole = UserRole.tenant;
          } else if (roleStr == 'landlord') {
            _userRole = UserRole.landlord;
          } else if (roleStr == 'admin') {
            _userRole = UserRole.admin;
          } else {
            _userRole = UserRole.none;
          }

          _isLoggedIn = true;
          _isNewUser = false;
          _hasSeenWelcome = data['hasSeenWelcome'] ?? true;
          notifyListeners();
          _startUserListener(uid);
          return true;
        } else {
          // NEW USER DETECTION
          final newRoleStr = defaultRole != null ? defaultRole.toString().split('.').last : 'tenant';
          
          // New user, create document
          // Google accounts are already email-verified by Google — no need to send a link.
          await FirebaseFirestore.instance.collection('users').doc(uid).set({
            'name': user.displayName ?? user.email!.split('@')[0],
            'email': user.email,
            'role': newRoleStr,
            'createdAt': DateTime.now(),
            'emailVerified': true, // Google already verified this email
            'hasSeenWelcome': false,
            'subscriptionStatus': 'free',
            'profileImage': user.photoURL,
          });

          _userId = uid;
          _userEmail = user.email;
          _userName = user.displayName ?? user.email!.split('@')[0];
          _profileImage = user.photoURL;
          _userRole = defaultRole ?? UserRole.tenant; // Default to tenant if not specified
          _subscriptionStatus = 'free';
          _isLoggedIn = true;
          _isNewUser = true; // IMPORTANT FOR REDIRECTION
          _hasSeenWelcome = false;
          notifyListeners();
          _startUserListener(uid);
          return true;
        }
      }
      _lastError = 'Sign-in failed. Please try again.';
      return false;
    } catch (e) {
      _lastError = e.toString();
      if (_lastError!.contains('EXCEPTION_ACCESS_DENIED')) {
        _lastError = 'App is not configured correctly. Please ensure SHA-1 keys are added to Firebase.';
      } else if (_lastError!.contains('idpiframe_initialization_failed')) {
        _lastError = 'Initialization failed. This usually happens if cookies are blocked.';
      }
      print('Google Sign-In error: $e');
      return false;
    }
  }

  void setUserRole(UserRole role) async {
    _userRole = role;
    _isNewUser = false;

    if (_userId != null) {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(_userId)
            .update({
          'role': role.toString().split('.').last,
        });
      } catch (e) {
        print('Error updating user role in Firestore: $e');
      }
    }

    notifyListeners();
  }

  void updateProfileImage(String url) {
    _profileImage = url;
    notifyListeners();
  }

  // NEW: Force refresh user status from server
  Future<void> refreshUserStatus() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        await user.reload();
        // Force refresh the ID token to get updated claims (including email_verified)
        await user.getIdToken(true);
        _isEmailVerified = user.emailVerified;
        notifyListeners();
        print('🛡️ Auth: User status refreshed. Verified: $_isEmailVerified');
      } catch (e) {
        print('❌ Auth: Error refreshing user status: $e');
      }
    }
  }

  Future<void> completeWelcome() async {
    _hasSeenWelcome = true;
    _isNewUser = false;
    if (_userId != null) {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(_userId)
            .update({'hasSeenWelcome': true});
      } catch (e) {
        print('Error updating hasSeenWelcome: $e');
      }
    }
    notifyListeners();
  }

  // FIXED SIGN OUT METHOD
  Future<void> signOut({bool forceNavigateHome = false}) async {
    // Clear local state
    _userDocSubscription?.cancel();
    _isLoggedIn = false;
    _userId = null;
    _userEmail = null;
    _userName = null;
    _userRole = UserRole.none;
    _isNewUser = false;
    _profileImage = null;

    // Sign out from Firebase and Google
    await FirebaseAuth.instance.signOut();
    await GoogleSignIn().signOut();

    // We intentionally DO NOT clear the SharedPreferences for remember_me 
    // here so that if the user chose to be remembered, their email/password
    // remains pre-filled on the sign-in screen when they come back.

    notifyListeners();

    if (forceNavigateHome && navigatorKey.currentState != null) {
      navigatorKey.currentState!.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomePage()),
        (route) => false,
      );
    }
  }

  Future<void> deleteAccount(String password) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.email == null) throw Exception('No user signed in');

    final uid = user.uid;

    try {
      // 1. Re-authenticate
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: password,
      );
      await user.reauthenticateWithCredential(credential);

      // 2. Data Cleanup in Firestore
      final batch = FirebaseFirestore.instance.batch();

      // Delete User document
      batch.delete(FirebaseFirestore.instance.collection('users').doc(uid));

      // Delete User's Properties
      final properties = await FirebaseFirestore.instance
          .collection('properties')
          .where('landlordId', isEqualTo: uid)
          .get();
      for (var doc in properties.docs) {
        batch.delete(doc.reference);
      }

      // Delete User's Support Chat
      final supportChatRef = FirebaseFirestore.instance.collection('support_chats').doc(uid);
      final supportMessages = await supportChatRef.collection('messages').get();
      for (var doc in supportMessages.docs) {
        batch.delete(doc.reference);
      }
      batch.delete(supportChatRef);

      // Delete User's Tour Requests (as tenant or landlord)
      final tenantTours = await FirebaseFirestore.instance
          .collection('tour_requests')
          .where('tenantId', isEqualTo: uid)
          .get();
      for (var doc in tenantTours.docs) {
        batch.delete(doc.reference);
      }
      final landlordTours = await FirebaseFirestore.instance
          .collection('tour_requests')
          .where('landlordId', isEqualTo: uid)
          .get();
      for (var doc in landlordTours.docs) {
        batch.delete(doc.reference);
      }

      // Commit the batch
      await batch.commit();

      // Delete Favorites (different structure)
      final favoritesRef = FirebaseFirestore.instance.collection('favorites').doc(uid);
      await favoritesRef.collection('properties').get().then((snapshot) {
        for (var doc in snapshot.docs) {
          doc.reference.delete();
        }
      });
      await favoritesRef.delete();

      // Delete Notifications
      final notificationsRef = FirebaseFirestore.instance.collection('notifications').doc(uid);
      await notificationsRef.collection('items').get().then((snapshot) {
        for (var doc in snapshot.docs) {
          doc.reference.delete();
        }
      });
      await notificationsRef.delete();

      // 3. Delete Auth Account

      // 3. Delete Auth Account
      await user.delete();

      // 4. Clear Local State
      await signOut();
    } catch (e) {
      print('Error during account deletion: $e');
      rethrow;
    }
  }

  void restoreSession({
    required String userId,
    required String userEmail,
    required String userName,
    required UserRole userRole,
    String? profileImage,
    String? subscriptionStatus,
    DateTime? subscriptionExpiry,
    bool hasSeenWelcome = true,
    bool? emailVerified,
  }) {
    _userId = userId;
    _userEmail = userEmail;
    _userName = userName;
    _userRole = userRole;
    _profileImage = profileImage;
    _subscriptionStatus = subscriptionStatus ?? 'free';
    _subscriptionExpiry = subscriptionExpiry;
    _isLoggedIn = true;
    _isNewUser = !hasSeenWelcome;
    _hasSeenWelcome = hasSeenWelcome;
    _isEmailVerified = emailVerified ?? (FirebaseAuth.instance.currentUser?.emailVerified ?? false);
    notifyListeners();
  }
}

final authService = AuthService();