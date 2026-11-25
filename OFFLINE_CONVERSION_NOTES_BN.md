# BMS Offline Conversion — নোট

## এই সংস্করণে যা বদলানো হয়েছে

- আগের screen-গুলো যে `ApiService` method ব্যবহার করে, সেসব method signature অপরিবর্তিত রেখে implementation SQLite-তে নেওয়া হয়েছে। তাই বিদ্যমান screen-গুলোকে নতুন API interface-এ migrate করতে হয়নি।
- Railway URL, HTTP request/response parsing, bearer-token storage ও `SharedPreferences` API logic সরানো হয়েছে।
- কোম্পানি create/update/deactivate/soft-delete, product ও road/address সংরক্ষণ local SQLite-তে হয়।
- মাসভিত্তিক sales/stock sheet এবং row fetch/save/update/delete স্থানীয় database-এ হয়।
- কোনো দিনের sheet save/update করলে শুধু ওই নির্বাচিত দিনের row replace হয়; একই মাসের অন্য দিনের row সংরক্ষিত থাকে।
- কোম্পানির প্রাথমিক ঠিকানাও sales screen-এ road/address হিসেবে selectable থাকে।
- local auth ও SQLite schema-এর existing implementation রাখা হয়েছে।
- SQLite database schema এখনও version `1`; এই source conversion-এ নতুন column/table দরকার হয়নি।
- Automated offline service tests যোগ করা হয়েছে। এগুলো এই environment-এ চালানো যায়নি কারণ এখানে Flutter/Dart SDK নেই।

## APK বানানোর নিয়ম

VS Code-এর terminal-এ project folder খুলে চালাও:

```powershell
.\build_apk.ps1
```

অথবা আলাদা করে:

```powershell
flutter pub get
flutter analyze
flutter test
flutter build apk --release
```

APK path:

```text
build\app\outputs\flutter-apk\app-release.apk
```

## সীমা ও গুরুত্বপূর্ণ কথা

এই workspace-এ Flutter SDK এবং Android SDK অনুপস্থিত; network access-ও নেই। তাই এখানে release APK তৈরি/চালিয়ে যাচাই করা হয়নি। Source conversion সম্পন্ন করা হয়েছে, কিন্তু `flutter analyze`, automated tests, release build এবং Android ফোনে functional test সফল না হওয়া পর্যন্ত build-কে verified release বলা যাবে না।

ব্যবহারকারীর আসল MySQL/Railway project বা backups এই working package-এর বাইরে থাকে; এই conversion তাদের পরিবর্তন করে না।
