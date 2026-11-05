Copy-Item "pubspec.yaml" "mobile_app/pubspec.yaml"
Copy-Item "lib/models/*" "mobile_app/lib/models/" -Recurse -Force
Copy-Item "lib/widgets/*" "mobile_app/lib/shared/widgets/" -Recurse -Force
Copy-Item "lib/utils/app_theme.dart" "mobile_app/lib/core/theme/" -Force
Copy-Item "lib/utils/app_constants.dart" "mobile_app/lib/core/constants/" -Force
Copy-Item "lib/services/auth_service.dart" "mobile_app/lib/features/authentication/" -Force
Copy-Item "lib/screens/auth/*" "mobile_app/lib/features/authentication/" -Force
Copy-Item "lib/services/bus_service.dart" "mobile_app/lib/features/buses/" -Force
Copy-Item "lib/services/ticket_service.dart" "mobile_app/lib/features/tickets/" -Force
Copy-Item "lib/services/location_service.dart" "mobile_app/lib/features/gps/" -Force
Copy-Item "lib/services/number_plate_ocr_service.dart" "mobile_app/lib/features/buses/" -Force
Copy-Item "lib/screens/passenger/*" "mobile_app/lib/features/passenger/" -Force
Copy-Item "lib/screens/conductor/*" "mobile_app/lib/features/conductor/" -Force
Copy-Item "lib/screens/common/*" "mobile_app/lib/features/tracking/" -Force
Copy-Item "test/unit_test.dart" "mobile_app/test/" -Force
Write-Output "Copied mobile app modules successfully."

