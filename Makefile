run:
	@echo "App läuft auf \033[4;34mhttp://localhost:8080\033[0m"
	flutter run --dart-define-from-file=.env -d chrome --web-port=8080

build-ios:
	flutter build ios --dart-define-from-file=.env

build-android:
	flutter build apk --dart-define-from-file=.env
