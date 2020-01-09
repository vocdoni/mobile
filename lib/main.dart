import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:vocdoni/constants/colors.dart';
import 'package:vocdoni/lib/singletons.dart';
import 'package:vocdoni/data-models/app-state.dart';
import 'package:vocdoni/data-models/account.dart';
import 'package:vocdoni/data-models/entity.dart';
import 'package:vocdoni/data-models/process.dart';
import 'package:vocdoni/data-models/feed.dart';
import 'package:vocdoni/views/dev/dev-analytics-tests.dart';
import 'package:vocdoni/views/dev/dev-pager.dart';
import 'package:vocdoni/views/dev/dev-ui-avatar-color.dart';
import 'package:vocdoni/views/dev/dev-ui-card.dart';
import 'package:vocdoni/views/dev/dev-ui-listItem.dart';
import 'package:vocdoni/views/entity-feed-page.dart';
import 'package:vocdoni/views/entity-participation-page.dart';
import 'package:vocdoni/views/feed-post-page.dart';
import 'package:vocdoni/views/poll-page.dart';
import 'package:vocdoni/views/startup-page.dart';
import 'lang/index.dart';
import 'package:vocdoni/views/identity-select-page.dart';
import "package:vocdoni/views/identity-create-page.dart";
import 'package:vocdoni/views/identity-backup-page.dart';
import 'package:vocdoni/views/entity-info-page.dart';
import 'package:vocdoni/views/dev/dev-menu.dart';
import 'package:vocdoni/view-modals/sign-modal.dart';
import "views/home.dart";

void main() async {
  await SystemChrome.setPreferredOrientations(
      [DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]);

  // RUN THE APP
  runApp(MultiProvider(
      providers: [
        Provider<AppStateModel>(create: (_) => globalAppState), // single object

        Provider<AccountPoolModel>(
            create: (_) => globalAccountPool), // object pool
        Provider<EntityPoolModel>(create: (_) => globalEntityPool),
        Provider<ProcessPoolModel>(create: (_) => globalProcessPool),
        Provider<FeedPoolModel>(create: (_) => globalFeedPool),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Vocdoni',
        localizationsDelegates: [
          LangDelegate(),
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate
        ],
        supportedLocales: [
          Locale("en"),
          Locale("fr"),
          Locale("ca"),
          Locale("es")
        ],
        onGenerateTitle: (BuildContext context) =>
            Lang.of(context).get("Vocdoni"),
        home: StartupPage(),
        onGenerateRoute: generateRoute,
        routes: {
          // NO IDENTITIES YET
          "/identity/create": (context) => IdentityCreatePage(),
          "/identity/select": (context) => IdentitySelectPage(),

          // WHEN THERE IS AN IDENTITY
          "/home": (context) => HomeScreen(),
          "/entity/feed": (context) => EntityFeedPage(),
          "/entity/feed/post": (context) => FeedPostPage(),
          "/entity/participation": (context) => EntityParticipationPage(),
          "/entity/participation/poll": (context) => PollPage(),
          "/identity/backup": (context) => IdentityBackupPage(),

          // GLOBAL
          // "/web/viewer": (context) => WebViewer(),
          "/signature": (context) => SignModal(),

          // DEV
          "/dev": (context) => DevMenu(),
          "/dev/ui-listItem": (context) => DevUiListItem(),
          "/dev/ui-card": (context) => DevUiCard(),
          "/dev/ui-avatar-colors": (context) => DevUiAvatarColor(),
          "/dev/analytics-tests": (context) => AnalyticsTests(),
          "/dev/pager": (context) => DevPager(),
        },
        theme: ThemeData(
          primarySwatch: Colors.blue,
          fontFamily: "Open Sans",
          scaffoldBackgroundColor: colorBaseBackground,
        ),
      )));
}

// generateRoute is called when nothing is found on `routes`
Route<dynamic> generateRoute(RouteSettings settings) {
  return MaterialPageRoute(builder: (_) {
    switch (settings.name) {
      case '/entity':
        return EntityInfoPage(settings.arguments);
      default:
        return null;
    }
  });
}
