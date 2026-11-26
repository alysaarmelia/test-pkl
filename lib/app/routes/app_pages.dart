import 'package:cipta_vera_mandiri_digital/app/modules/home/bindings/home_binding.dart';
import 'package:cipta_vera_mandiri_digital/app/modules/home/bindings/login_binding.dart';
import 'package:cipta_vera_mandiri_digital/app/modules/home/views/auth_view.dart';
import 'package:cipta_vera_mandiri_digital/app/modules/home/views/forgot_password_view.dart';
import 'package:cipta_vera_mandiri_digital/app/modules/home/views/splash_view.dart';
import 'package:cipta_vera_mandiri_digital/app/modules/home/views/welcome_view.dart';
import 'package:cipta_vera_mandiri_digital/app/modules/pages/homepage.dart';
import 'package:cipta_vera_mandiri_digital/app/modules/profile/complete_profile_page.dart';
import 'package:cipta_vera_mandiri_digital/app/modules/onboarding/bindings/onboarding_binding.dart';
import 'package:cipta_vera_mandiri_digital/app/modules/onboarding/views/onboarding_view.dart';
import 'package:get/get.dart';

import 'app_routes.dart';

class AppPages {
  static List<GetPage<dynamic>> get routes => [
        GetPage(
          name: Routes.SPLASH,
          page: () => const SplashView(),
        ),
        GetPage(
          name: Routes.WELCOME,
          page: () => const WelcomeView(),
        ),
        GetPage(
          name: Routes.LOGIN,
          page: () => const AuthView(),
          binding: LoginBinding(),
        ),
        GetPage(
          name: Routes.HOME,
          page: () => HomePage(),
          binding: HomeBinding(),
        ),
        GetPage(
          name: Routes.FORGOT_PASSWORD,
          page: () => const ForgotPasswordView(),
        ),
        GetPage(
          name: Routes.COMPLETE_PROFILE,
          page: () => const CompleteProfilePage(),
        ),
        GetPage(
          name: Routes.ONBOARDING,
          page: () => const OnboardingView(),
          binding: OnboardingBinding(),
        ),
      ];
}
