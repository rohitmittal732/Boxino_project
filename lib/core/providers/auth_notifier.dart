import 'package:firebase_auth/firebase_auth.dart' as fb;
import '../../../data/services/firebase_service.dart';
import 'app_providers.dart';

// ─── Auth State Model ─────────────────────────────────────────────────────────
enum AuthStatus {
  idle,
  loading,
  authenticated,
  unauthenticated,
  error,
}

class AuthStateModel {
  final AuthStatus status;
  final String? errorMessage;
  final fb.User? user;
  final String? verificationId;
  final int? resendToken;

  const AuthStateModel({
    this.status = AuthStatus.idle,
    this.errorMessage,
    this.user,
    this.verificationId,
    this.resendToken,
  });

  bool get isLoading      => status == AuthStatus.loading;
  bool get isAuthenticated => status == AuthStatus.authenticated;
  bool get hasError       => status == AuthStatus.error;

  AuthStateModel copyWith({
    AuthStatus? status,
    String? errorMessage,
    fb.User? user,
    String? verificationId,
    int? resendToken,
  }) {
    return AuthStateModel(
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
      user: user ?? this.user,
      verificationId: verificationId ?? this.verificationId,
      resendToken: resendToken ?? this.resendToken,
    );
  }
}

// ─── AuthNotifier ────────────────────────────────────────────────────────────
class AuthNotifier extends StateNotifier<AuthStateModel> {
  final FirebaseService _service;

  AuthNotifier(this._service) : super(const AuthStateModel()) {
    _init();
  }

  void _init() {
    final user = _service.currentUser;
    if (user != null) {
      state = AuthStateModel(status: AuthStatus.authenticated, user: user);
    } else {
      state = const AuthStateModel(status: AuthStatus.unauthenticated);
    }
  }

  // ─── Firebase Phone OTP ───────────────────────────────────────────────────
  Future<void> sendFirebaseOtp({
    required String phone,
    required Function(String) onCodeSent,
    required Function(String) onError,
  }) async {
    state = state.copyWith(status: AuthStatus.loading, errorMessage: null);
    
    try {
      await _service.verifyPhoneNumber(
        phoneNumber: phone,
        verificationCompleted: (credential) async {
          // Auto-resolution (Android only)
          final result = await fb.FirebaseAuth.instance.signInWithCredential(credential);
          if (result.user != null) {
            state = AuthStateModel(status: AuthStatus.authenticated, user: result.user);
          }
        },
        verificationFailed: (e) {
          state = state.copyWith(status: AuthStatus.error, errorMessage: e.message);
          onError(e.message ?? 'Verification failed');
        },
        codeSent: (verificationId, resendToken) {
          state = state.copyWith(
            status: AuthStatus.idle,
            verificationId: verificationId,
            resendToken: resendToken,
          );
          onCodeSent(verificationId);
        },
        codeAutoRetrievalTimeout: (verificationId) {
          state = state.copyWith(verificationId: verificationId);
        },
        forceResendingToken: state.resendToken,
      );
    } catch (e) {
      state = state.copyWith(status: AuthStatus.error, errorMessage: e.toString());
      onError(e.toString());
    }
  }

  Future<bool> verifyFirebaseOtp(String otp) async {
    if (state.verificationId == null) return false;
    
    state = state.copyWith(status: AuthStatus.loading, errorMessage: null);
    try {
      final result = await _service.signInWithOtp(state.verificationId!, otp);
      if (result.user != null) {
        state = AuthStateModel(status: AuthStatus.authenticated, user: result.user);
        return true;
      }
      return false;
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: 'Invalid OTP. Please try again.',
      );
      return false;
    }
  }

  // ─── Sign Out ──────────────────────────────────────────────────────────────
  Future<void> signOut() async {
    await _service.signOut();
    state = const AuthStateModel(status: AuthStatus.unauthenticated);
    // Explicitly reset the state model
  }

  void clearError() {
    state = state.copyWith(status: AuthStatus.idle, errorMessage: null);
  }

}

// ─── Provider ──────────────────────────────────────────────────────────────
final authNotifierProvider = StateNotifierProvider<AuthNotifier, AuthStateModel>((ref) {
  final service = ref.read(firebaseServiceProvider);
  return AuthNotifier(service);
});
