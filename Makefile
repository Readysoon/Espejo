run:
	flutter run --dart-define-from-file=.env

build-ios:
	flutter build ios --dart-define-from-file=.env

build-android:
	flutter build apk --dart-define-from-file=.env
