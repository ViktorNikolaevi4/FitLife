import Foundation
import FirebaseAuth
import FirebaseFirestore

enum AppErrorPresenter {
    static func message(for error: Error) -> String {
        let nsError = error as NSError

        if nsError.domain == NSURLErrorDomain {
            switch nsError.code {
            case NSURLErrorNotConnectedToInternet, NSURLErrorNetworkConnectionLost:
                return AppLocalizer.string("common.error.network")
            case NSURLErrorTimedOut:
                return AppLocalizer.string("common.error.timeout")
            default:
                break
            }
        }

        if nsError.domain == AuthErrorDomain,
           let authCode = AuthErrorCode(rawValue: nsError.code) {
            switch authCode {
            case .wrongPassword, .invalidCredential, .userNotFound:
                return AppLocalizer.string("auth.error.invalid_credentials")
            case .invalidEmail:
                return AppLocalizer.string("auth.error.invalid_email")
            case .emailAlreadyInUse:
                return AppLocalizer.string("auth.error.email_in_use")
            case .weakPassword:
                return AppLocalizer.string("auth.error.weak_password")
            case .tooManyRequests:
                return AppLocalizer.string("auth.error.too_many_requests")
            case .networkError:
                return AppLocalizer.string("common.error.network")
            case .operationNotAllowed:
                return AppLocalizer.string("auth.error.operation_not_allowed")
            default:
                return AppLocalizer.string("common.error.try_again")
            }
        }

        if nsError.domain == FirestoreErrorDomain,
           let firestoreCode = FirestoreErrorCode.Code(rawValue: nsError.code) {
            switch firestoreCode {
            case .permissionDenied:
                return AppLocalizer.string("common.error.permission")
            case .unavailable:
                return AppLocalizer.string("common.error.unavailable")
            case .deadlineExceeded:
                return AppLocalizer.string("common.error.timeout")
            default:
                return AppLocalizer.string("common.error.try_again")
            }
        }

        return AppLocalizer.string("common.error.try_again")
    }
}
